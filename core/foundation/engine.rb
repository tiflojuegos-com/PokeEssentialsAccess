module PokeAccess
  # Tells the gen-6 era (PB* tables) apart from the GameData era, and probes what the running engine has.
  module Engine
    # True on the GameData era, detected by GameData::Species.
    def self.gamedata?
      (defined?(GameData) && defined?(GameData::Species)) ? true : false
    end

    # True on the gen-6 era, which predates GameData.
    def self.gen6?
      !gamedata?
    end

    # The existing names worth hooking among a screen's candidates: drops a subclass of another listed class (a
    # hook on the parent covers it) and a second name for the same class; unrelated classes are all kept.
    def self.scene_classes(*names)
      found = []
      names.each do |n|
        k = PokeAccess.const_at(n)
        found.push([n, k]) if k
      end
      keep = []
      found.each do |cand|
        covered = found.any? do |other|
          other[1] != cand[1] ? cand[1].ancestors.include?(other[1]) : (found.index(other) < found.index(cand))
        end
        keep.push(cand[0]) unless covered
      end
      keep
    end

    # The single name to hook among aliases of one screen, or nil when the game has none of them.
    def self.scene_class(*names)
      scene_classes(*names)[0]
    end

    # The scene name to hook for the era's reader (era :gen6 or :gamedata), or "", which binds nothing: own when the
    # other era's alias is absent, the running era's pick when both exist. A GameData reader never binds on the gen-6
    # engine, whose screen named only the v17 way (no v16 alias, as in Soulstones) goes to the gen-6 reader.
    def self.era_scene(era, own, other)
      mine = PokeAccess.const_at(own)
      twin = PokeAccess.const_at(other)
      return "" if era == :gamedata && gen6?
      return ((era == :gen6 && gen6? && twin) ? other : "") if mine.nil?
      return own if twin.nil?
      ((era == :gen6) ? gen6? : gamedata?) ? scene_class(own, other).to_s : ""
    end

    # The running engine as a symbol, :gamedata or :gen6.
    def self.kind
      gamedata? ? :gamedata : :gen6
    end

    # The player object whatever the engine calls it ($player on GameData era, $Trainer on gen-6).
    def self.player
      (defined?($player) && $player) ? $player : (defined?($Trainer) ? $Trainer : nil)
    end

    # How many of an item the bag holds ($bag, $PokemonBag or the player's own bag; quantity or pbQuantity), or
    # nil when no bag answers.
    def self.bag_quantity(item)
      bag = (defined?($bag) && $bag) || (defined?($PokemonBag) && $PokemonBag) || (player.bag rescue nil)
      return nil unless bag
      n = bag.respond_to?(:quantity) ? bag.quantity(item) : bag.pbQuantity(item)
      n.nil? ? nil : n.to_i
    rescue StandardError
      nil
    end

    # The running Essentials version as a Float, for diagnostics and fork (readers gate on has?). Without a
    # constant: GameData is 19.0 or 18.0 by Battle::Scene, gen-6 16.0; an ESSENTIALSVERSION below 1 reads 17.0.
    def self.version
      return @version if defined?(@version) && @version
      ev = (defined?(Essentials) && (Essentials::VERSION rescue nil)) ||
           (defined?(ESSENTIALS_VERSION) && (ESSENTIALS_VERSION rescue nil))
      @version = if ev then ev.to_s[/\d+(\.\d+)?/].to_f
                 elsif gamedata? then (PokeAccess.const_at("Battle::Scene") ? 19.0 : 18.0)
                 elsif defined?(ESSENTIALSVERSION) then (v = ESSENTIALSVERSION.to_s[/\d+(\.\d+)?/].to_f; v < 1 ? 17.0 : v)
                 else 16.0
                 end
    rescue StandardError
      gamedata? ? 19.0 : 16.0
    end

    # The Essentials fork, or nil for vanilla. Sky backports the v22 UI onto a v21.1 base.
    def self.fork
      return @fork if defined?(@fork)
      @fork = (gamedata? && version < 21.9 && defined?(UI) && defined?(UI::BaseScreen)) ? :sky : nil
    end

    # Named capabilities: symbol => a probe (a has? string or a lambda). Readers gate on these, never on a version
    # number; :ui_rework is the v22 UI:: rework and :battle_scene the v19+ battle scene; :dbk (Deluxe Battle Kit) and
    # :mui (Modular UI Scenes) are third-party plugins listed for the diagnostic, not for gating.
    CAPABILITIES = {
      :gamedata  => lambda { gamedata? },
      :gen6      => lambda { gen6? },
      :sky_fork  => lambda { fork == :sky },
      :ui_rework => "UI::BaseScreen",
      :battle_scene => "Battle::Scene",
      :dbk => "Battle#pbToggleSpecialActions",
      :mui => "UIHandlers"
    }

    # True when a capability is present: a registered symbol, a "A::B::C" constant name, or "A::B::C#method" to
    # also require an instance method. An unregistered symbol answers false and is logged once.
    def self.has?(cap)
      probe = cap.is_a?(Symbol) ? CAPABILITIES[cap] : cap
      PokeAccess.log_once("cap_#{cap}", "capacidad no registrada") if probe.nil? && cap.is_a?(Symbol)
      return false if probe.nil?
      return (probe.call ? true : false) if probe.respond_to?(:call)
      name, meth = probe.to_s.split("#", 2)
      const = PokeAccess.const_at(name)
      return false if const.nil?
      return true if meth.nil? || meth.empty?
      (const.method_defined?(meth) || const.private_method_defined?(meth)) ? true : false
    rescue StandardError
      false
    end
  end
end
