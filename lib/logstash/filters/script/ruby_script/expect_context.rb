# Handle expect blocks inside of test blocks
class ExpectContext
  include ::LogStash::Util::Loggable
  
  attr_reader :name
  
  def initialize(test_context, name, block)
    @test_context = test_context
    @name = name
    @block = block
  end
  
  def to_s 
    "<Expect #{@test_context.name}/#{self.name}>"
  end
  
  def execute(events, flushed)
    if @block.call(events, flushed)
      true
    else
      script_path = @test_context.script_context.ruby_script.script_path
      message = "***TEST FAILURE FOR: '#{@test_context.name}' expected '#{@name}'***"
      # This actually can output some useful data about the events that failed
      # The bubbled exception truncates long messages unfortunately, so we can't
      # just include that map there
      logger.error(message, 
        :parameters => @test_context.parameters,
        :in_events => @test_context.in_events.map(&:to_hash_with_metadata),
        :results => events.map(&:to_hash_with_metadata)
      )
      false
    end
  end
end