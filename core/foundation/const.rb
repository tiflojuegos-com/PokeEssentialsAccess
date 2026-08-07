module PokeAccess
  # Resolves a "A::B::C" constant by name. Segment by segment, because 1.8.7's const_defined? rejects a name
  # containing "::", and gen-6 runs 1.8.7. The one low-level constant lookup the mod builds on: Hooks, Input
  # and Engine.has? all route through it. Use it when the constant ITSELF is wanted -- for the bare
  # existence boolean the gate is Engine.has?, so there is one obvious way to ask.
  # param name a constant name, possibly nested with "::"
  # return the constant, or nil if any segment is undefined
  #
  # An empty name is rejected up front: inject over an empty segment list returns the seed, so "" would
  # resolve to Object, and era_scene answers "" by design for a reader whose era is not running.
  def self.const_at(name)
    return nil if name.nil? || name.to_s.empty?
    name.to_s.split("::").inject(Object) do |mod, seg|
      return nil unless mod.const_defined?(seg)
      mod.const_get(seg)
    end
  rescue StandardError
    nil
  end

  # Reads an instance variable off any object, defensively: the engine exposes no accessors, so the mod
  # introspects by ivar constantly and an ivar's presence varies between game versions.
  # param sym the ivar symbol, e.g. :@index
  # param fallback the value when the ivar is absent or the read raises
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
  # Essentials renamed accessors between eras -- totalpp to total_pp, base_damage to power -- and each
  # fangame kept whichever spelling it forked from, so the catalogue splits about evenly on each. Asking for
  # one name does not raise, since these reads are guarded: it answers nil, and a move reads as missing data
  # rather than as a bug. Tried in order, so the commonest spelling goes first.
  # param names accessor symbols to try, e.g. :totalpp, :total_pp
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
  # param key the sprite key, e.g. "commandwindow"
  def self.sprite(scene, key)
    h = ivar(scene, :@sprites)
    h.is_a?(Hash) ? h[key] : nil
  rescue StandardError
    nil
  end

  # Claims a window for a dedicated reader, so the generic command-window reader leaves it alone: some
  # screens draw a list the generic reader half understands, and it names the bare row while the dedicated
  # one is speaking the full detail.
  #
  # The flag is the mod's own and deliberately not the engine's @ignore_input, which some Selectable windows
  # use to gate their own navigation -- setting that to mute us freezes the cursor. A pair, so the name is
  # written once instead of by each reader that claims a window.
  # param win the window, or nil, since a screen that has none is not an error
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
