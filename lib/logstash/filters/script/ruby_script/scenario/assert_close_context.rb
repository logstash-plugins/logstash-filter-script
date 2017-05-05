class LogStash::Filters::Script::RubyScript::ScenarioContext::AssertCloseContext < LogStash::Filters::Script::RubyScript::ScenarioContext::BaseAssertContext
  def context_name
    "assert_close"
  end

  def execute_block
    execution_context.instance_exec(&@block)
  end 
end