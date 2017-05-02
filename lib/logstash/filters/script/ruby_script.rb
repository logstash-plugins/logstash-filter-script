class LogStash::Filters::Script::RubyScript
  # Current API Version
  API_VERSION=1
  # List of Supported API versions
  SUPPORTED_API_VERSIONS=[API_VERSION]

  include ::LogStash::Util::Loggable
  require "logstash/filters/script/ruby_script/context"
  
  attr_reader :script, :script_path, :dlq_writer
  
  def initialize(script, script_path, parameters, dlq_writer)
    @script = script
    @script_path = script_path
    @context = Context.new(self, script_path, parameters, @dlq_writer)
  end
  
  def setup
    begin
      @context.load_script
    rescue => e
      raise ::LogStash::Filters::Script::ScriptError.new(script_path, e), "Error during load"
    end
    
    begin
      @context.execute_setup
    rescue => e
      raise ::LogStash::Filters::Script::ScriptError.new(script_path, e), "Error during setup"
    end
    
    if !@context.on_event_method
      raise "Script does not define `on_event`! Please ensure that you have defined the `on_event` method!"
    end
  end
  
  def execute(event)
    @context.execute_on_event(event)
  end
  
  def flush
    @context.execute_flush()
  end

  def close
    @context.execute_close()
  end
  
  def test
    results = @context.execute_tests
    logger.info("Test run complete", :script_path => script_path, :results => results)
    if results[:failed] > 0
      raise ::LogStash::Filters::Script::ScriptError.new(script_path), "Script '#{script_path}' had #{results[:failed]} failing tests! Check the error log for details"
    end
  end
end
