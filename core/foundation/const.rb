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
    # An empty name is not Object. inject over an empty segment list returns the seed, so "" resolved to
    # Object itself: a hook registered under a blank class name bound nothing and then recorded a permanent
    # entry in the typo list, because Object almost never has the method. era_scene answers "" by design for
    # a reader whose era is not running, so this is reached on every such reader, in every game.
    return nil if name.nil? || name.to_s.empty?
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

  # The first of these accessors the object answers with something, or nil.
  #
  # Essentials renamed a handful of accessors between eras -- totalpp became total_pp, base_damage became
  # power -- and every fangame kept whichever spelling it forked from, so the thirteen games we support
  # split roughly down the middle on each one. Asking for a single name is the worst kind of wrong here: it
  # does not raise anywhere it matters, because these reads are guarded already. It just answers nil, and a
  # move with no pp or zero power reads as missing data rather than as a bug. Names are tried in order, so
  # put the spelling most games use first.
  # @param names accessor symbols to try, e.g. :totalpp, :total_pp
  def self.attr_of(obj, *names)
    names.each do |n|
      next unless (obj.respond_to?(n) rescue false)
      v = (obj.send(n) rescue nil)
      return v unless v.nil?
    end
    nil
  rescue StandardError
    nil
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

  # Claims a window for a dedicated reader, so the generic command-window reader leaves it alone.
  #
  # Some screens draw a list the generic reader can see but only half understands: it announces the bare
  # row name while a dedicated reader is already speaking the full detail, and the player hears the move
  # twice. The flag is the mod's OWN (@access_dedicated) and deliberately not the engine's @ignore_input,
  # which some Selectable windows use to gate their own navigation -- setting that to mute us freezes the
  # cursor.
  #
  # It is a pair because it is a contract with two ends, and they used to sit far apart: four readers wrote
  # the ivar by hand and menus.rb read it. A typo in any one writer un-mutes that screen, and the only
  # symptom is the player hearing everything twice. Now the name is written once.
  # @param win the window, or nil (a screen that has none is not an error)
  def self.dedicate(win)
    win.instance_variable_set(:@access_dedicated, true) if win
    win
  rescue StandardError
    win
  end

  # True when a dedicated reader has claimed this window (see dedicate).
  def self.dedicated?(win)
    win ? (win.instance_variable_get(:@access_dedicated) ? true : false) : false
  rescue StandardError
    false
  end
end
