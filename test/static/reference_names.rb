# What the reference copies of plugins no surveyed game ships define (reference_census.txt, from
# build_reference_census.rb), for the static tests that let a generic-only reader name it: only what the copies its own
# probe comes from define, so a copy as wide as a whole fork of Essentials vouches for no other plugin's names.
module ReferenceNames
  PATH = File.join(File.dirname(__FILE__), "reference_census.txt")
  MANIFEST = File.expand_path("../../plugins/manifest.rb", File.dirname(__FILE__))

  # { "class:Name" | "method:Class#method" | "ivar:name" => [source, ...] }, empty when the census is absent.
  def self.table
    @table ||= begin
      out = {}
      PokeAccess::KVFile.each(PATH) { |k, v| out[k] = v.split(", ") } if File.file?(PATH)
      out
    end
  end

  # The reference copies that define a probe: a class, or "Class#method" with that method.
  def self.probe_sources(probe)
    cname, meth = probe.to_s.split("#", 2)
    last = cname.to_s.split("::").last
    table[meth ? "method:#{last}##{meth}" : "class:#{last}"] || []
  end

  # True when some reference copy defines the probe.
  def self.probe?(probe)
    !probe_sources(probe).empty?
  end

  # The reference copies the reader at a path comes from: those that define its plugin's probe; none for any other file.
  def self.copies_of(path)
    return [] unless path =~ %r{\Aplugins/([^/]+)\.rb\z}
    @probes ||= eval(File.read(MANIFEST))
    probe_sources(@probes[$1.to_sym])
  end

  # True when a copy the reader at a path comes from defines the class (its last segment, as the census keys it).
  def self.class_of?(path, name)
    shared?("class:#{name.to_s.split('::').last}", path)
  end

  # True when a copy the reader at a path comes from uses the instance variable (named with or without its @).
  def self.ivar_of?(path, name)
    shared?("ivar:#{name.to_s.sub(/\A@/, '')}", path)
  end

  # Whether a census key's sources include a copy the reader at a path comes from.
  def self.shared?(key, path)
    !((table[key] || []) & copies_of(path)).empty?
  end
end
