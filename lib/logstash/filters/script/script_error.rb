class LogStash::Filters::Script::ScriptError < StandardError
  def initialize(script_path, error=nil)
    @script_path = script_path
    @error = error
  end
  
  def message
    if @error
      "Error evaluating script #{@error.class.name} #{@error.message}\n#{@error.backtrace.join('\n')}\nScript:\n#{@script_path}=n"
    else
      "Error evaluating script '#{super}':\n'#{@script_path}'\n"
    end
  end
  
  def log_hash
    h = {
      :script => @script_path,
      :message => self.message
    }
    if @error
      h.merge!({
        :message => @error.message,
        :class => @error.class.name,
        :backtrace => @error.backtrace
      })
    end
    h
  end
end
