# A blank area for our script to live in.
# Everything is instance_e{val,exec}'d against this
# to eliminate instance var and method def conflicts against other
# objects
class LogStash::Filters::Script::RubyScript::ExecutionContext
  # Alias `Event` so that users can just type `Event.new` in a script
  Event = ::LogStash::Event

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

  def api_version(version)
    # noop here, all the real work here is done by the version check context
  end
  
  def to_s
    "<ExecutionContext #{@__name__}>"
  end
end
 