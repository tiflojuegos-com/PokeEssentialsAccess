module PokeAccess
  # Resolves a "A::B::C" constant by name, returning the constant or nil. Walks segment by segment so it is
  # safe on Ruby 1.8.7, whose const_defined? rejects a name containing "::" (gen-6 runs 1.8.7). This is the
  # one low-level constant lookup the whole mod builds on -- Hooks, Input and Engine.has? all route through
  # it instead of calling Object.const_defined? on a "::" string directly, so a nested class name never
  # crashes the gen-6 loader. Lives in foundation so it loads before anything that needs it. Use this when
  # the constant ITSELF is wanted; for the bare "does it exist?" boolean the gate is Engine.has?, which takes
  # a registered capability symbol, a "A::B::C" name or the "Class#method" form -- there is deliberately no
  # second existence predicate here, so the codebase has one obvious way to ask.
  # @param name a constant name string (may be nested with "::")
  # @return the constant, or nil if any segment is undefined
  def self.const_at(name)
    name.to_s.split("::").inject(Object) do |mod, seg|
      return nil unless mod.const_defined?(seg)
      mod.const_get(seg)
    end
  rescue StandardError
    nil
  end

  # Reads an instance variable off any object, returning fallback when it is unset or the read raises. The mod
  # introspects game-engine objects by ivar constantly (the engine exposes no accessors), and every such read
  # must be defensive because the ivar's presence varies across game versions. Centralises the (obj rescue
  # fallback) idiom that was open-coded at ~200 sites. Lives in foundation so every layer can use it. 1.8.7-safe.
  # @param sym the ivar symbol, e.g. :@index
  # @param fallback the value when the ivar is absent or the read raises (default nil)
  def self.ivar(obj, sym, fallback = nil)
    obj.instance_variable_get(sym)
  rescue StandardError
    fallback
  end

  # ivar coerced to an Integer, for the numeric ivars whose open-coded reads fell back to 0.
  def self.ivar_i(obj, sym, fallback = 0)
    v = ivar(obj, sym)
    v.nil? ? fallback : v.to_i
  rescue StandardError
    fallback
  end

  # A named sprite from a scene's @sprites hash, or nil when the hash or the key is absent. Essentials scenes
  # keep their windows in @sprites["name"], which the mod reads to introspect the focused window; this folds
  # the doubly-defensive ((ivar || {})["k"] rescue nil) idiom into one call. 1.8.7-safe.
  # @param key the sprite key, e.g. "commandwindow"
  def self.sprite(scene, key)
    h = ivar(scene, :@sprites)
    h.is_a?(Hash) ? h[key] : nil
  rescue StandardError
    nil
  end
end
