# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "thread"

class LogStash::Filters::Script < LogStash::Filters::Base
  require "logstash/filters/script/script_error"
  require "logstash/filters/script/ruby_script"

  config_name "script"
  
  # Path to the script
  config :path, :validate => :path, :required => true
  
  # Parameters for this specific script
  config :script_params, :type => :hash, :default => {}

  # Tag to add to events that cause an exception in the script filter
  config :tag_on_exception, :type => :string, :default => "_script_filter_exception"
  
  def register
    @script = RubyScript.new(@path, script_params, @dlq_writer)
    @script.register
    @script.test
    @dlq_writer = respond_to?(:execution_context) ? execution_context.dlq_writer : nil
  end
  
  def self.check_result_events!(results)
    if !results.is_a?(Array)
      raise "Custom script did not return an array from 'filter'. Only arrays may be returned!"
    end
    
    results.each do |r_event|
      if !r_event.is_a?(::LogStash::Event)
        raise "Custom script returned a non event object '#{r_event.inspect}'!" +
              " You must an array of events from this function! To drop an event simply return nil."
      end
    end
  end

  def filter(event)
    begin
      results = @script.execute(event)
      
      self.class.check_result_events!(results)
    rescue => e
      event.tag(@tag_on_exception)
      message = "Could not process event: " + e.message
      @logger.error(message, :script_path => @path,
                             :class => e.class.name,
                             :backtrace => e.backtrace)
      return event
    end
    
    returned_original = false
    results.each do |r_event|
      # If the user has generated a new event we yield that for them here
      if event == r_event
        returned_original = true
      else
        yield r_event
      end
      
      r_event
    end

    event.cancel unless returned_original
  end 

  def periodic_flush
    false
  end
end
