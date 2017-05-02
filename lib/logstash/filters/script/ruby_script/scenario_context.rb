# Handle top level test blocks
class LogStash::Filters::Script::RubyScript::ScenarioContext
  require "logstash/filters/script/ruby_script/expect_context"
  require "logstash/filters/script/ruby_script/scenario/base_assert_context"
  require "logstash/filters/script/ruby_script/scenario/assert_setup_context"
  attr_reader :name, :script_context, :execution_context
  
  def initialize(script_context, name)
    @name = name
    @script_context = script_context

    @setup_contexts = []
    @on_event_contexts = []

    @expect_contexts = []
    @test_options = {}
    @execution_context = script_context.make_execution_context("Test/#{name}", true)
    @results = {:passed => 0, :failed => 0}
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
  
  def test_event(&block)
    return @test_events unless block

    orig = block.call
    @test_events = orig.is_a?(Array) ? orig : [orig]
    @test_events.each do |e|
      if !e.is_a?(::LogStash::Event)
        raise ArgumentError, 
          "In event for #{self.name} must receive either an Event or an array of Events! got a '#{e.class}' in #{test_events.inspect}"
      end
    end
  end
  alias_method :test_events, :test_event

  def execute_setup_assertions!
    @setup_contexts.each do |sc|
      record_assert_result(sc.execute)
    end
  end

  def execute_on_event_assertions!(on_event_results)
    @on_event_contexts.each do |oec|
      record_assert_result(oec.execute(on_event_results))
    end
  end

  def record_assert_result(res)
    key = res == true ? :passed : :failed
    @results[key] += 1
  end

  def execute
    if !@test_events
      raise "You must declare a `test_event` to run tests!"
    end

    execute_setup_assertions!
    
    on_event_results = []
    @test_events.each do |e|
      single_result = @execution_context.on_event(e)
      ::LogStash::Filters::Script.check_result_events!(single_result)
      on_event_results += single_result
    end

    execute_on_event_assertions!(on_event_results)
    
    flush_results = @script_context.flush_defined? ? 
      @execution_context.flush(false) :
      []
    
    @expect_contexts.each do |ec| 
      res = ec.execute(on_event_results, flush_results) 
      if res != true && res != false
        raise "Expect context #{ec} returned a non true/false value: #{res.inspect}!"
      end
      key = res == true ? :passed : :failed
      @results[key] += 1
    end

    @results
  end

  def assert_setup(name, &block)
    @setup_contexts << AssertSetupContext.new(self, name, block)
  end

  def assert_on_even(name, &block)
    @on_event_contexts << AssertOnEventContext.new(self, name, block)
  end
  
  def expect(name, &block)
    @expect_contexts << ExpectContext.new(self, name, block)
  end
end