# Handle expect blocks inside of test blocks
class ExpectContext
  include ::LogStash::Util::Loggable
  
  attr_reader :name
  
  def initialize(scenario_context, name, block)
    @scenario_context = scenario_context
    @name = name
    @block = block
  end
  
  def to_s 
    "<Scenario #{@scenario_context.name}/#{self.name}>"
  end
  
  def execute(events, flushed)
    if @block.call(events, flushed)
      true
    else
      script_path = @scenario_context.script_context.ruby_script.script_path
      message = "***TEST FAILURE FOR: '#{@scenario_context.name}' expected '#{@name}'***"
      # This actually can output some useful data about the events that failed
      # The bubbled exception truncates long messages unfortunately, so we can't
      # just include that map there
      logger.error(message, 
        :parameters => @scenario_context.parameters,
        :in_events => @scenario_context.in_events.map(&:to_hash_with_metadata),
        :results => events.map(&:to_hash_with_metadata)
      )
      false
    end
  end
end