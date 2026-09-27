module PokeAccess
  # RPG Maker direction code => [dx, dy], the one-tile step that way.
  DIR_DELTA = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }

  # The constant named "A::B::C", or nil if any segment is undefined; resolved segment by segment because 1.8.7's
  # const_defined? rejects "::". An empty name is nil, not Object (era_scene answers "" for an inactive era).
  def self.const_at(name)
    return nil if name.nil? || name.to_s.empty?
    name.to_s.split("::").inject(Object) do |mod, seg|
      return nil unless mod.const_defined?(seg)
      mod.const_get(seg)
    end
  rescue StandardError
    nil
  end

  # An instance variable (e.g. :@index) of any object, nil when unset; fallback only when the read raises.
  def self.ivar(obj, sym, fallback = nil)
    obj.instance_variable_get(sym)
  rescue StandardError
    fallback
  end

  # ivar as an Integer; fallback when it is unset or cannot be read or converted.
  def self.ivar_i(obj, sym, fallback = 0)
    v = ivar(obj, sym)
    v.nil? ? fallback : v.to_i
  rescue StandardError
    fallback
  end

  # The first non-nil answer among these accessors, tried in order, or nil; for names Essentials renamed between
  # eras (e.g. :totalpp, :total_pp).
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

  # A named sprite from a scene's @sprites hash (e.g. "commandwindow"), or nil when the hash or the key is absent.
  def self.sprite(scene, key)
    h = ivar(scene, :@sprites)
    h.is_a?(Hash) ? h[key] : nil
  rescue StandardError
    nil
  end

  # Claims a window (nil allowed) for a dedicated reader, so the generic command-window reader leaves it alone.
  # The flag is the mod's own, not the engine's @ignore_input, which would freeze the cursor.
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
