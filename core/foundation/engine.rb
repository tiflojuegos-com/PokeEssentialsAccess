module PokeAccess
  # Tells the gen-6 era apart from the GameData era of Essentials so shared code reaches the right data API.
  # Named by the data API each era uses (gen-6 = PB* tables, later = the GameData layer), not by "old/new",
  # which would not age well.
  module Engine
    # True on the GameData era (Essentials v17+), detected by the GameData layer it introduced.
    def self.gamedata?
      (defined?(GameData) && defined?(GameData::Species)) ? true : false
    end

    # True on the gen-6 era (v16-17), which predates GameData.
    def self.gen6?
      !gamedata?
    end

    # The names to hook out of a list of candidate class names for one screen, dropping any that another
    # kept name already covers -- a name that INHERITS from another in the list, or a second name for the
    # very same class.
    #
    # Two shapes in the wild make this necessary, and both fail silently:
    #
    #   * A fork declares the OLD class names as empty SUBCLASSES of the new ones -- Awakening's BES-T
    #     compatibility file does it for 23 screens -- and then instantiates only the new name. A hook on
    #     the old name binds to a class the game never builds: the reader says nothing, raises nothing, and
    #     never reaches Hooks.missing either, because the class does exist.
    #   * The reverse, when a game builds the SUBCLASS and the mod registered the same body on both names:
    #     the hook fires twice and the screen is read double.
    #
    # Keeping only the ancestors answers both at once. Unrelated classes that merely appear in the same
    # list (a fork's own variant screen) are all kept -- they cover different scenes.
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

    # The single name to hook among ALIASES of one screen, or nil when the game has none of them.
    def self.scene_class(*names)
      scene_classes(*names)[0]
    end

    # The scene name for a reader written against ONE data API, or "" (which binds nothing, exactly as an
    # absent class already does). own is the alias this reader has always hooked, other is the alias the
    # reader for the other era hooks.
    #
    # The name USUALLY decides, and deliberately so: where a game ships only one of the aliases, this
    # answers exactly what the reader hooked before, so nothing changes anywhere that already worked. That
    # matters because era and class name are INDEPENDENT in the wild -- Reminiscencia has GameData and the
    # v16 class names with a gen-6 scene shape, so gating on the era alone would have left it with neither
    # reader bound and the summary silent.
    #
    # The era only breaks the tie when BOTH aliases exist, which is what a compatibility layer produces
    # (Awakening and Africanus declare the v16 names as empty subclasses of the v17 ones and instantiate
    # only the v17 name). There the name has stopped discriminating: both readers match, the wrong one wins
    # by load order, and it reads a gen-6 Pokemon through the GameData accessors -- or mutes the generic
    # reader and replaces it with nothing. So the era picks the reader, and scene_class picks the ancestral
    # name, the only one that sees every instance.
    # param era :gen6 or :gamedata
    def self.era_scene(era, own, other)
      mine = PokeAccess.const_at(own)
      twin = PokeAccess.const_at(other)
      return "" if mine.nil?
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

    # Running Essentials version as a comparable Float, for the diagnostic line only -- real fangames mix
    # eras (some fangames run v18 with backports, Sky is v21.1-plus-v22-UI), so code must gate on has?,
    # never on this number. Gen-6 v16 has no constant, so it floors to 16.0. The gen-6 branch's
    # `v < 1 ? 17.0 : v` is defensive with no documented originating game: some gen-6 forks write
    # ESSENTIALSVERSION as a free string, and a parse that lands below 1 would otherwise report a
    # nonsense "0.x era", so it snaps to 17.0 (the ESSENTIALSVERSION era).
    # A GameData engine with no version constant is told apart structurally, never by a runtime global
    # (the player object does not exist yet at the title screen, and the result is memoised): v19 renamed
    # the battle scene to Battle::Scene, so its absence means the v18 transitional era -- GameData already
    # in, but still PokeBattle_Scene and $Trainer (an era some fangames still ship).
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

    # Named capabilities: a symbol => a probe (a "A::B::C" constant name string, or a lambda returning a
    # bool). Readers should gate on a CAPABILITY (does the class/feature exist?), never on a version number,
    # so a fork that backports a feature (or a future version that keeps it) works without edits. A version
    # folder (v21/v22/...) only says WHERE a capability was introduced; activation is by has?. Register the
    # few transversal ones here; one-off screens can pass their class name to has? directly.
    CAPABILITIES = {
      :gamedata  => lambda { gamedata? },
      :gen6      => lambda { gen6? },
      :sky_fork  => lambda { fork == :sky },
      :ui_rework => "UI::BaseScreen",      # the v22 UI:: rework
      :battle_scene => "Battle::Scene"     # the v19+ battle scene
    }

    # True when a capability is present. Accepts a registered capability symbol (:ui_rework, :gamedata...),
    # a "A::B::C" constant name string, or "A::B::C#method" to also require an instance method on that class
    # (so a fork that backports the method activates, regardless of its version number). Constant lookup goes
    # through PokeAccess.const_at, which is 1.8.7-safe. The single, uniform gate for "can this engine do X?".
    def self.has?(cap)
      probe = cap.is_a?(Symbol) ? CAPABILITIES[cap] : cap
      # A TYPO'd symbol answers false, exactly like a capability the engine really lacks, and silences a
      # whole family of readers with no noise at all. Say so once; the answer stays false either way.
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
