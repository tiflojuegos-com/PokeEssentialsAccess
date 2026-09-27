# Stand-ins for a game's own top-level functions (getTypeName, getMoveName...), put in place for a block and taken away
# after, since the specs that each need their own share one process.
module GameFunctions
  # Runs the block with each name defined as its lambda, then puts back whatever was there before, or nothing.
  def self.with(map)
    saved = map.keys.map do |n|
      had = Object.private_method_defined?(n) || Object.method_defined?(n)
      [n, had ? Object.instance_method(n) : nil]
    end
    begin
      map.each do |n, f|
        Object.send(:define_method, n, &f)
        Object.send(:private, n)
      end
      yield
    ensure
      saved.each do |n, um|
        if um
          Object.send(:define_method, n, um)
          Object.send(:private, n)
        else
          Object.send(:remove_method, n)
        end
      end
    end
  end
end
