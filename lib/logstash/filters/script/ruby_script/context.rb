class LogStash::Filters::Script::RubyScript::Context
  require "logstash/filters/script/ruby_script/version_check_context"
  require "logstash/filters/script/ruby_script/execution_context"
  require "logstash/filters/script/ruby_script/test_context"

  include ::LogStash::Util::Loggable
 
  attr_reader :register_block, 
              :filter_block, 
              :flush_block,
              :ruby_script,
              :execution_context
  
  def initialize(ruby_script, script_path, parameters, dlq_writer)
    @ruby_script = ruby_script
    @script_path = script_path
    @parameters = parameters
    @test_contexts = []
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
    execution_context.define_singleton_method(:register) {|&block| this.register(&block) }
    execution_context.define_singleton_method(:filter) {|&block| this.filter(&block) }
    execution_context.define_singleton_method(:flush) {|&block| this.flush(&block) }
    execution_context.define_singleton_method(:close) {|&block| this.close(&block) }
    # If we aren't in test mode we define the test. If we *are* then we don't define anything
    # since our tests are already defined 
    if test_mode
      execution_context.define_singleton_method(:test) {|name,&block| nil }
    else
      execution_context.define_singleton_method(:test) {|name,&block| this.test(name, &block) }
    end
    execution_context
  end
  
  def load_execution_context(ec)
    ec.instance_eval(@ruby_script.script, @script_path, 1)
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
    load_execution_context(@execution_context)
  end

  def api_version
    @execution_context.api_version
  end
  
  def register(&block)
    @register_block = block
  end

  def execute_register()
    if @register_block
      @execution_context.instance_exec(@parameters, &@register_block)
    end
  end
  
  def concurrency(type)
    @concurrency = type
  end
  
  def filter(&block)
    @filter_block = block
  end
  
  def execute_filter(event)
    if @concurrency == :shared
      @script_lock.synchronize { @execution_context.instance_exec(event, &@filter_block) }
    else 
      @execution_context.instance_exec(event, &@filter_block)
    end
  end
  
  def flush(&block)
    @flush_block = block
  end

  def close(&block)
    @close_block = block
  end
  
  def execute_flush
    return if !@flush_block

    if @concurrency == :shared
      #execution_context.instance_exec(&flush_block)
      @script_lock.synchronize { @execution_context.instance_exec(&flush_block) }
    else
      @script_lock.synchronize { @execution_context.instance_exec(&flush_block) }
    end
  rescue => e
    @logger.error("Error during flush!", :message => e.message, :class => e.class.name, :backtrace => e.backtrace)
  end

  def execute_close
    return if !@close_block

    @execution_context.instance_exec(&@close_block)
  end
  
  def execute_tests
    @test_contexts.
      map(&:execute).
      reduce({:passed => 0, :failed => 0}) do |acc,res|
        acc[:passed] += res[:passed]
        acc[:failed] += res[:failed]
        acc
      end
  end
  
  def test(name, &block)
    test_context = LogStash::Filters::Script::RubyScript::TestContext.new(self, name)
    test_context.instance_eval(&block)
    @test_contexts << test_context
  end
end