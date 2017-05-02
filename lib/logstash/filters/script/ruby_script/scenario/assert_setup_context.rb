class LogStash::Filters::Script::RubyScript::ScenarioContext::AssertSetupContext < LogStash::Filters::Script::RubyScript::ScenarioContext::BaseAssertContext
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

  def execution_context
    @scenario_context.execution_context
  end

  def execute_block
    execution_context.instance_exec(&@block)
  end 
end