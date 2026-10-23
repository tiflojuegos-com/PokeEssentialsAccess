# What the reference copies of plugins no surveyed game ships define (reference_census.txt, from
# build_reference_census.rb), for the static tests that let a generic-only reader name it.
module ReferenceNames
  PATH = File.join(File.dirname(__FILE__), "reference_census.txt")

  # { "class:Name" | "method:Class#method" | "ivar:name" => sources text }, empty when the census is absent.
  def self.table
    @table ||= begin
      out = {}
      PokeAccess::KVFile.each(PATH) { |k, v| out[k] = v } if File.file?(PATH)
      out
    end
  end

  # True when some reference copy defines the class (its last segment, as the census keys it).
  def self.class?(name)
    table.has_key?("class:#{name.to_s.split('::').last}")
  end

  # True when some reference copy defines the probe: a class, or "Class#method" with that method.
  def self.probe?(probe)
    cname, meth = probe.to_s.split("#", 2)
    meth ? table.has_key?("method:#{cname.split('::').last}##{meth}") : class?(cname)
  end

  # True when some reference copy uses the instance variable (named with or without its @).
  def self.ivar?(name)
    table.has_key?("ivar:#{name.to_s.sub(/\A@/, '')}")
  end
end
