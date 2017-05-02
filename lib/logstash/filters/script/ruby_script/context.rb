class LogStash::Filters::Script::RubyScript::Context
  require "logstash/filters/script/ruby_script/version_check_context"
  require "logstash/filters/script/ruby_script/execution_context"
  require "logstash/filters/script/ruby_script/scenario_context"

  include ::LogStash::Util::Loggable
 
  attr_reader :ruby_script,
              :execution_context
  
  def initialize(ruby_script, script_path, options, dlq_writer)
    @ruby_script = ruby_script
    @script_path = script_path
    @options = options
    @scenario_contexts = []
    @script_lock = Mutex.new
    @concurrency = :single
    @dlq_writer = dlq_writer
    check_api_version!
  end
  
  def make_execution_context(name, test_mode)
    execution_context = LogStash::Filters::Script::RubyScript::ExecutionContext.new(name, logger, @dlq_writer)
    
    # Proxy all the methods from this instance needed to be run from the execution context
    this = self # We need to use a clojure to retain access to this object
    execution_context.define_singleton_method(:concurrency) {|type| this.concurrency(type) }
    # If we aren't in test mode we define the test. If we *are* then we don't define anything
    # since our tests are already defined 
    if test_mode
      execution_context.define_singleton_method(:scenario) {|name,&block| nil }
    else
      execution_context.define_singleton_method(:scenario) {|name,&block| this.test(name, &block) }
    end

    execution_context.instance_eval(@ruby_script.script, @script_path, 1)

    execution_context
  end

  def check_api_version!
    version_check_context = LogStash::Filters::Script::RubyScript::VersionCheckContext.new
    version_check_context.instance_eval(@ruby_script.script, @script_path, 1)
    @api_version = version_check_context.api_version
    supported_versions = ::LogStash::Filters::Script::RubyScript::SUPPORTED_API_VERSIONS
    if !@api_version
      message=<<-EOM
        Script '#{@script_path}' did not declare an API version! You must include the line:
        `api_version #{::LogStash::Filters::Script::RubyScript::API_VERSION}` in your file!
      EOM
      raise ::LogStash::ConfigurationError.new(message)
    elsif !supported_versions.include?(@api_version)
      message=<<-EOM
        Script '#{@script_path}' was developed against API version #{@api_version}, 
        but only API versions '#{supported_versions.inspect}' are allowed!
        Please upgrade the script to support the current version!
      EOM
      raise ::LogStash::ConfigurationError.new(message)
    end
  end
  
  def load_script
    @execution_context = self.make_execution_context(:main, false)
  end

  def api_version
    @execution_context.api_version
  end
  
  def concurrency(type)
    @concurrency = type
  end

  def setup_defined?
    execution_context_defined?(:setup)
  end

  def on_event_defined?
    execution_context_defined?(:on_event)
  end

  def flush_defined?
    execution_context_defined?(:flush)
  end

  def close_defined?
    execution_context_defined(:close)
  end

  def execution_context_defined?(name)
    @execution_context.methods.include?(name)
  end
  
  def execute_on_event(event)
    if @concurrency == :shared
      @script_lock.synchronize { self.execute_on_event_unsafe(event) }
    else 
      self.execute_on_event_unsafe(event)
    end
  end

  def execute_setup()
    if setup_defined?
      @execution_context.setup(@options)
    end
  end

  def execute_on_event_unsafe(event)
    @execution_context.on_event(event)
  end
  
  def execute_close
    if close_defined?
      @execution_context.close()
    end
  end
  
  def execute_flush(final)
    return [] if !flush_defined?

    if @concurrency == :shared
      @script_lock.synchronize {  execute_flush_unsafe(final) }
    else
      execute_flush_unsafe(final)
    end
  rescue => e
    @logger.error("Error during flush!", :message => e.message, :class => e.class.name, :backtrace => e.backtrace)
  end

  def execute_flush_unsafe(final)
    @execution_context.flush(final)
  end

  def execute_close
    return if !@close_block

    @execution_context.instance_exec(&@close_block)
  end
  
  def execute_tests
    @scenario_contexts.
      map(&:execute).
      reduce({:passed => 0, :failed => 0}) do |acc,res|
        acc[:passed] += res[:passed]
        acc[:failed] += res[:failed]
        acc
      end
  end
  
  def test(name, &block)
    scenario_context = LogStash::Filters::Script::RubyScript::ScenarioContext.new(self, name)
    scenario_context.instance_eval(&block)
    @scenario_contexts << scenario_context
  end
end