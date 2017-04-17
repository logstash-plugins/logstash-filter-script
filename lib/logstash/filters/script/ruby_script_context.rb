class LogStash::Filters::Script::RubyScript::Context
  include ::LogStash::Util::Loggable

  # A blank area for our script to live in.
  # Everything is instance_e{val,exec}'d against this
  # to eliminate instance var and method def conflicts against other
  # objects
  class ExecutionContext
    def initialize(name, logger, dlq_writer)
      # Namespaced with underscore so as not to conflict with anything the user sets
      @__name__ = name
      @__logger__ = logger
      @__dlq_writer__ = dlq_writer
    end

    def logger
      @__logger__
    end

    def dead_letter(event, message)
      if @__dlq_writer__
        @__dlq_writer__.write(event, message)
      else
        logger.error("Script attempted to dead letter, but DLQ is not enabled: #{message}", :event => event.to_hash)
      end
    end
    
    def to_s
      "<ExecutionContext #{@__name__}>"
    end
  end
  
  attr_reader :register_block, 
              :filter_block, 
              :flush_block,
              :ruby_script,
              :execution_context
  
  def initialize(ruby_script, script_path, parameters, dlq_writer)
    @ruby_script = ruby_script
    @script_path = script_path
    @parameters = parameters
    @test_contexts = []
    @script_lock = Mutex.new
    @concurrency = :single
    @dlq_writer = dlq_writer
  end
  
  def make_execution_context(name, test_mode)
    execution_context = ExecutionContext.new(name, logger, @dlq_writer)
    
    # Proxy all the methods from this instance needed to be run from the execution context
    this = self # We need to use a clojure to retain access to this object
    execution_context.define_singleton_method(:concurrency) {|type| this.concurrency(type) }
    execution_context.define_singleton_method(:register) {|&block| this.register(&block) }
    execution_context.define_singleton_method(:filter) {|&block| this.filter(&block) }
    execution_context.define_singleton_method(:flush) {|&block| this.flush(&block) }
    if test_mode
      execution_context.define_singleton_method(:test) {|name,&block| nil }
    else
      execution_context.define_singleton_method(:test) {|name,&block| this.test(name, &block) }
    end
    execution_context
  end
  
  def load_execution_context(ec)
    ec.instance_eval(@ruby_script.script, @script_path, 1)
  end
  
  def load_script
    @execution_context = self.make_execution_context(:main, false)
    load_execution_context(@execution_context)
  end
  
  # Extract the line number of the calling function via a regexp
  def caller_line(caller)
    @register_line = caller.first.match(/\:(?<line>\d+)\:in/)[:line].to_i
  end
  
  def register(&block)
    line = caller_line(caller)
    #@register_dblock = LogStash::Filters::Script::DebuggableProc.new(block, @script_path, line)
    #@register_dblock.instance_eval(self)
    @register_block = block
  end
  
  def execute_register()
    if @register_block
      @execution_context.instance_exec(@parameters, &@register_block)
    end
  end
  
  def concurrency(type)
    @concurrency = type
  end
  
  def filter(&block)
    @filter_block = block
  end
  
  def execute_filter(event)
    if @concurrency == :shared
      @script_lock.synchronize { @execution_context.instance_exec(event, &@filter_block) }
    else 
      @execution_context.instance_exec(event, &@filter_block)
    end
  end
  
  def flush(&block)
    @flush_block = block
  end
  
  def execute_flush()
    if @concurrency == :shared
      @script_lock.synchronize { @flush_block ? @flush_block.call() : [] }
    else
      @flush_block ? @flush_block.call() : []
    end
  end
  
  def execute_tests
    @test_contexts.
      map(&:execute).
      reduce({:passed => 0, :failed => 0}) do |acc,res|
        acc[:passed] += res[:passed]
        acc[:failed] += res[:failed]
        acc
      end
  end
  
  def test(name, &block)
    test_context = TestContext.new(self, name)
    test_context.instance_eval(&block)
    @test_contexts << test_context
  end
  
  class TestContext
    attr_reader :name, :script_context
    
    def initialize(script_context, name)
      @name = name
      @script_context = script_context
      @expect_contexts = []
      @parameters = {}
      @execution_context = script_context.make_execution_context("Test/#{name}", true)
      @script_context.load_execution_context(@execution_context)
    end
      
    def parameters(&block)
      # Can act as a reader if no block passed
      return @parameters unless block

      @parameters = block.call
      if !@parameters.is_a?(Hash)
        raise ArgumentError, "Test parameters must be a hash in #{@name}!"
      end
      
      @execution_context.instance_exec(@parameters, &@script_context.register_block)
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
        single_result = @execution_context.instance_exec(e, &@script_context.filter_block)
        ::LogStash::Filters::Script.check_result_events!(single_result)
        results += single_result
      end
      
      flush_results = @script_context.flush_block ? 
        @execution_context.instance_exec(&@script_context.flush_block) :
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
  end
end
