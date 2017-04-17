class LogStash::Filters::Script::RubyScript
  include ::LogStash::Util::Loggable
  require "logstash/filters/script/ruby_script_context"
  
  attr_reader :script, :script_path, :dlq_writer
  
  def initialize(script, script_path, parameters, dlq_writer)
    @script = script
    @script_path = script_path
    @context = Context.new(self, script_path, parameters, @dlq_writer)
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
    
    if !@context.filter_block.is_a?(Proc)
      raise "Script does not define a filter! Please ensure that you have defined a filter block!"
    end
  end
  
  def execute(event)
    @context.execute_filter(event)
  end
  
  def flush()
    @context.execute_flush()
  end
  
  def test
    results = @context.execute_tests
    logger.info("Test run complete", :script_path => script_path, :results => results)
    if results[:failed] > 0
      raise ::LogStash::Filters::Script::ScriptError.new(script_path), "Script '#{script_path}' had #{results[:failed]} failing tests! Check the error log for details"
    end
  end
end
