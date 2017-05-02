class LogStash::Filters::Script::RubyScript::ScenarioContext::AssertSetupContext < LogStash::Filters::Script::RubyScript::ScenarioContext::BaseAssertContext
  def context_name
    "assert_on_block"
  end

  def execute_block(result_events)
    execution_context.instance_exec(result_events, &@block)
  end 
end