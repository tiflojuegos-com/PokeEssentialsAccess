# Standalone Essential regressions use the reference's own harness and language
# cache. Avoid optional mocking gems; restore every temporary singleton method.
Dir.chdir(ENV.fetch('ESSENTIAL_PEA_SOURCE')) do
  require File.join(Dir.pwd, 'test/test_helper')
end

module PeaStandaloneMethods
  def with_singleton(object, name, body)
    previous = object.singleton_methods.include?(name) ? object.method(name) : nil
    object.define_singleton_method(name, &body)
    yield
  ensure
    previous ? object.define_singleton_method(name, previous) : object.singleton_class.send(:remove_method, name)
  end
end
