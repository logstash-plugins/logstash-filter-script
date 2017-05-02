# Handle top level test blocks
class LogStash::Filters::Script::RubyScript::ScenarioContext
  require "logstash/filters/script/ruby_script/expect_context"
  require "logstash/filters/script/ruby_script/scenario/assert_setup_context"
  attr_reader :name, :script_context
  
  def initialize(script_context, name)
    @name = name
    @script_context = script_context
    @expect_contexts = []
    @test_options = {}
    @execution_context = script_context.make_execution_context("Test/#{name}", true)
  end
    
  def test_options(&block)
    # Can act as a reader if no block passed
    return @test_options unless block

    @test_options = block.call
    if !@test_options.is_a?(Hash)
      raise ArgumentError, "Test test_options must be a hash in #{@name}!"
    end
    
    @execution_context.setup(@test_options)
  end
  
  def in_event(&block)
    return @in_events unless block

    orig = block.call
    event_hashes = orig.is_a?(Hash) ? [orig] : orig
    event_hashes.each do |e|
      if !e.is_a?(Hash)
        raise ArgumentError, 
          "In event for #{self.name} must receive either a hash or an array of hashes! got a '#{e.class}' in #{event_hashes.inspect}"
      end
    end
    @in_events = Array(event_hashes).map {|h| ::LogStash::Event.new(h) }
  end
  alias_method :in_events, :in_event
  
  def execute
    if !@in_events
      raise "You must declare an `in_event` to run tests!"
    end
    
    results = []
    @in_events.each do |e|
      single_result = @execution_context.on_event(e)
      ::LogStash::Filters::Script.check_result_events!(single_result)
      results += single_result
    end
    
    flush_results = @script_context.flush_defined? ? 
      @execution_context.flush(false) :
      []
    
    @expect_contexts.map do |ec| 
      res = ec.execute(results, flush_results) 
      if res != true && res != false
        raise "Expect context #{ec} returned a non true/false value: #{res.inspect}!"
      end
      res
    end.reduce({:passed => 0, :failed => 0}) do |acc,res| 
      key = res == true ? :passed : :failed
      acc[key] += 1
      acc
    end
  end
  
  def expect(name, &block)
    @expect_contexts << ExpectContext.new(self, name, block)
  end
end