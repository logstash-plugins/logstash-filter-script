class LogStash::Filters::Script::RubyScript::ScenarioContext::AssertSetupContext
  include ::LogStash::Util::Loggable
  
  attr_reader :name
  
  def initialize(scenario_context, name, block)
    @scenario_context = scenario_context
    @name = name
    @block = block
  end
  
  def to_s 
    "[scenario(#{@scenario_context.name}).#{context_name}(#{self.name})]"
  end

  def context_name
    "assert_setup"
  end
  
  def execute(execution_context)
    if execution_context.instance_exec(&@block)
      true
    else
      script_path = @test_context.script_context.ruby_script.script_path
      message = "***TEST FAILURE FOR: '#{@test_context.name}' expected '#{@name}'***"
      # This actually can output some useful data about the events that failed
      # The bubbled exception truncates long messages unfortunately, so we can't
      # just include that map there
      logger.error(message, 
        :test_options => @test_context.test_options,
        :in_events => @test_context.in_events.map(&:to_hash_with_metadata),
        :results => events.map(&:to_hash_with_metadata)
      )
      false
    end
  end
end