# We need BasicObject here because we want method_missing to catch everything
# Including #test, which is a private method in Object
class LogStash::Filters::Script::RubyScript::VersionCheckContext < BasicObject
  def api_version(version=nil)
    return @__api_version__ unless version
    @__api_version__ = version
  end

  # This is (mostly) a null object. The only thing we care about is the API Version
  def method_missing(*args,&block)
  end
end