class LogStash::Filters::Script::RubyScript::ScenarioContext::BaseAssertContext
  include ::LogStash::Util::Loggable
  
  attr_reader :name, :error_extras
  
  def initialize(scenario_context, name, block)
    @scenario_context = scenario_context
    @name = name
    @block = block
    @error_extras = {}
  end
  
  def to_s 
    "[scenario(#{@scenario_context.name}).#{context_name}(#{self.name})]"
  end

  def execution_context
    @scenario_context.execution_context
  end

  def script_path
    @scenario_context.script_context.ruby_script.script_path
  end

  # Run the assertion. Takes a hash of extra data to
  # be logged in the event of an error
  def execute(*block_extras)
    block_result = execute_block(*block_extras)

    if block_result != true && block_result != false
      raise LogStash::Filters::Script::ScriptError.new(script_path), "Test #{self.to_s} returned a non-boolean value!"
    end

    if block_result
      true
    else
      message = "***TEST FAILURE FOR: '#{@scenario_context.name}' expected '#{@name}'***"
      # This actually can output some useful data about the events that failed
      # The bubbled exception truncates long messages unfortunately, so we can't
      # just include that map there
      logger_hash = {
        :test_options => @scenario_context.test_options,
        :test_events => @scenario_context.test_events.map(&:to_hash_with_metadata)
      }.merge(error_extras)

      logger.error(message, logger_hash)
      false
    end
  end
end