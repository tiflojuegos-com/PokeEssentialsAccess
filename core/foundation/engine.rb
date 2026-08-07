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

    # The names worth hooking out of a screen's candidate list: any name another kept one already covers --
    # by inheritance, or by being a second name for the same class -- is dropped.
    #
    # Two shapes make this necessary and both fail silently. A compatibility layer declares the OLD names as
    # empty SUBCLASSES of the new ones and instantiates only the new one, so a hook on the old name binds to
    # a class the game never builds and never reaches Hooks.missing either. The reverse, a game that builds
    # the subclass with the same body registered on both names, reads the screen twice.
    #
    # Unrelated classes in the same list are all kept: they cover different scenes.
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

    # The scene name for a reader written against ONE data API, or "", which binds nothing exactly as an
    # absent class does.
    #
    # The NAME decides where a game ships only one of the two aliases, because era and class name are
    # independent in the wild: both Infinite Fusions have GameData under the gen-6 class names, so gating on
    # the era alone would leave them with neither reader bound. The era only breaks the tie when BOTH
    # aliases exist, which is what a compatibility layer produces: there the name has stopped
    # discriminating, both readers match, and the wrong one would win by load order.
    # param era :gen6 or :gamedata
    # param own the alias this reader hooks; param other the alias the other era's reader hooks
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

    # Running Essentials version as a comparable Float, for the DIAGNOSTIC line only: real fangames mix eras,
    # so code gates on has? and never on this number. v16 has no constant and floors to 16.0, and a gen-6
    # fork that writes ESSENTIALSVERSION as free text can parse below 1, which snaps to 17.0 rather than
    # reporting a nonsense era.
    #
    # A GameData engine with no version constant is told apart structurally and never by a runtime global,
    # since the player object does not exist at the title screen and the result is memoised: v19 renamed the
    # battle scene, so its absence means the v18 transitional era.
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

    # Named capabilities: symbol => a probe, either a "A::B::C" constant name or a lambda returning a bool.
    # A reader gates on a CAPABILITY and never on a version number, so a fork that backports a feature works
    # without edits; a version folder only says where a capability was introduced. Register the transversal
    # ones here -- a one-off screen can pass its class name to has? directly.
    #
    # The last two are THIRD-PARTY plugins and are here for the DIAGNOSTIC, not for gating: their readers
    # bind per method with :optional, which keeps a partial install working. They are not in the plugins/
    # detection table because that lists plugins a PROFILE declares, and these reopen engine classes rather
    # than adding their own, so only a method identifies them -- which is what a capability probe is.
    CAPABILITIES = {
      :gamedata  => lambda { gamedata? },
      :gen6      => lambda { gen6? },
      :sky_fork  => lambda { fork == :sky },
      :ui_rework => "UI::BaseScreen",      # the v22 UI:: rework
      :battle_scene => "Battle::Scene",    # the v19+ battle scene
      :dbk => "Battle#pbToggleSpecialActions",  # Deluxe Battle Kit
      :mui => "UIHandlers"                      # Modular UI Scenes
    }

    # True when a capability is present: the single gate for "can this engine do X?". Takes a registered
    # capability symbol, a "A::B::C" constant name, or "A::B::C#method" to also require an instance method,
    # so a fork that backports it activates whatever its version says.
    #
    # An unregistered symbol is logged once. A typo answers false exactly like a real absence and would
    # otherwise silence a family of readers with no noise at all; the answer stays false either way.
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
