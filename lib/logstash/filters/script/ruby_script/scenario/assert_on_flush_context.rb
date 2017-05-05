class LogStash::Filters::Script::RubyScript::ScenarioContext::AssertOnFlushContext < LogStash::Filters::Script::RubyScript::ScenarioContext::BaseAssertContext
  def context_name
    "assert_on_flush"
  end

  def execute_block(result_events)
    execution_context.instance_exec(result_events, &@block)
  end 
end