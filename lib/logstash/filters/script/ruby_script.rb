class LogStash::Filters::Script::RubyScript
  # Current API Version
  API_VERSION=1
  # List of Supported API versions
  SUPPORTED_API_VERSIONS=[API_VERSION]

  include ::LogStash::Util::Loggable
  require "logstash/filters/script/ruby_script/context"
  
  attr_reader :script, :script_path, :dlq_writer
  
  def initialize(script_path, parameters, dlq_writer)
    @script = File.read(script_path)
    @script_path = script_path
    @context = Context.new(self, parameters, @dlq_writer)
  end
  
  def register
    begin
      @context.load_script
    rescue => e
      raise ::LogStash::Filters::Script::ScriptError.new(script_path, e), "Error during load"
    end
    
    begin
      @context.execute_register
    rescue => e
      raise ::LogStash::Filters::Script::ScriptError.new(script_path, e), "Error during register"
    end
    
    if !@context.execution_context.methods.include?(:filter)
      raise "Script does not define a filter! Please ensure that you have defined a filter method!"
    end
  end
  
  def execute(event)
    @context.execute_filter(event)
  end
  
  def test
    results = @context.execute_tests
    logger.info("Test run complete", :script_path => script_path, :results => results)
    if results[:failed] > 0
      raise ::LogStash::Filters::Script::ScriptError.new(script_path), "Script '#{script_path}' had #{results[:failed]} failing tests! Check the error log for details"
    end
  end
end
