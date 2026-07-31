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

    # The running engine as a symbol, :gamedata or :gen6.
    def self.kind
      gamedata? ? :gamedata : :gen6
    end

    # Picks the entry for the running engine from a hash keyed by :gamedata/:gen6, else :default.
    def self.pick(map)
      map.fetch(kind) { map[:default] }
    end

    # The player object whatever the engine calls it ($player on GameData era, $Trainer on gen-6).
    def self.player
      (defined?($player) && $player) ? $player : (defined?($Trainer) ? $Trainer : nil)
    end

    # Running Essentials version as a comparable Float; gen-6 v16 has no constant, so it floors to 16.0.
    # A GameData engine with no version constant is told apart structurally, never by a runtime global
    # (the player object does not exist yet at the title screen, and the result is memoised): v19 renamed
    # the battle scene to Battle::Scene, so its absence means the v18 transitional era -- GameData already
    # in, but still PokeBattle_Scene and $Trainer (Infinite Fusion).
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

    # True when the running version is at least v.
    def self.at_least?(v); version >= v; end

    # True when the running version is within [lo, hi] inclusive.
    def self.between?(lo, hi); version >= lo && version <= hi; end

    # Whether the active engine satisfies an option hash; keys (all optional, ANDed): :min/:max version
    # bounds, :only a family (:gen6/:gamedata) or exact version, :fork a fork id.
    def self.matches?(opts = {})
      return false if opts[:min] && version < opts[:min]
      return false if opts[:max] && version > opts[:max]
      return false if opts[:fork] && fork != opts[:fork]
      case opts[:only]
      when :gen6     then return gen6?
      when :gamedata then return gamedata?
      when Numeric   then return version == opts[:only]
      end
      true
    end

    # Runs the block only when the active engine matches the spec (see matches?).
    def self.for_engine(opts = {})
      yield if block_given? && matches?(opts)
    end
  end
end
