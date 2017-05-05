class LogStash::Filters::Script::RubyScript::ScenarioContext::AssertSetupContext < LogStash::Filters::Script::RubyScript::ScenarioContext::BaseAssertContext
  def context_name
    "assert_setup"
  end

  def execute_block
    execution_context.instance_exec(&@block)
  end 
end