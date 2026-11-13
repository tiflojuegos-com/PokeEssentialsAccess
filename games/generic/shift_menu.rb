module PokeAccess
  # Native Essentials can bind its menu to both Shift and Z. A Shift navigation gesture must finish before the
  # keyboard's menu request is dispatched; a bare Shift still opens it on release, and Z remains immediate.
  module GenericShiftMenu
    @scene = nil
    @used = false
    DEFAULT_ACTION_SCANCODES = [225, 29].freeze

    # The effective action keys: Access's explicit binding, F1's file, or mkxp-z's native RGSS1 defaults.
    def self.action_keys
      bound = PokeAccess::Remap.bound_code(:a)
      return [bound] if bound
      path = PokeAccess::NativeKeys.path
      return [] unless path
      return PokeAccess::NativeKeys.table[:a] || [] if File.exist?(path)
      DEFAULT_ACTION_SCANCODES.map { |scan| PokeAccess::NativeKeys.vk_of(scan) }.compact
    end

    # The configured modifier as a key code; an unbound modifier never delays the game's menu.
    def self.modifier
      PokeAccess::Config.keys[:shift]
    end

    # Whether the physical key code is held with its required Alt modifier, using the normal keyboard snapshot.
    def self.down?(code)
      return false unless code
      kb = PokeAccess::Keyboard
      kb.raw_down?(kb.key_of(code)) && (!kb.alt_code?(code) || kb.alt_held?)
    end

    # A held alternative to the configured modifier, from the same effective action binding.
    def self.alternate_down?(keys = action_keys, code = modifier)
      keys.any? { |key| key != code && down?(key) }
    end

    # A native action-menu keyboard press whose only held action key is the Access modifier.
    def self.request?(scene)
      return false unless $scene.equal?(scene)
      return false unless PokeAccess::Keys.enabled && PokeAccess::Keys.focused? && !PokeAccess::Keys.typing?
      return false unless PokeAccess::NativeKeys.native_input? && PokeAccess::Control.flag($game_temp, :menu_calling)
      return false unless $game_temp.respond_to?(:menu_calling=)
      return false unless ::Input.const_defined?(:ACTION) && ::Input.const_defined?(:A)
      action = ::Input.const_get(:ACTION)
      return false unless action == ::Input.const_get(:A) && ::Input.trigger?(action)
      code = modifier
      return false unless down?(code)
      keys = action_keys
      keys.include?(code) && !alternate_down?(keys, code)
    end

    # Records a chord even inside a blocking reader/menu loop, which can finish after the modifier was released.
    def self.observe
      return unless @scene
      unless $scene.equal?(@scene) && PokeAccess::Keys.enabled && PokeAccess::Keys.focused?
        cancel
        return
      end
      codes = PokeAccess::Config.keys.reject { |name, _code| name == :shift || name == :ctrl }.values
      @used = true if PokeAccess::ConfigMenu.active? || (down?(modifier) && codes.any? { |code| down?(code) })
    end

    # Cancels only the menu request this guard deferred; it changes no event, movement or story flag.
    def self.cancel
      $game_temp.menu_calling = false if @scene && $game_temp && $game_temp.respond_to?(:menu_calling=)
      reset
      nil
    end

    # Drops the transient owner before the original menu opens or after its chord was handled.
    def self.reset
      @scene = nil
      @used = false
    end

    # Keeps the original menu and its arguments/result; only a modifier-owned keyboard request is postponed.
    def self.intercept(scene, original, args)
      if @scene && !@scene.equal?(scene)
        cancel
        return original.call(*args)
      end
      if @scene
        observe
        return nil unless @scene
        return cancel if @used
        return nil if down?(modifier) && !alternate_down?
        reset
        return original.call(*args)
      end
      return original.call(*args) unless request?(scene)
      @scene = scene
      @used = false
      observe
      @used ? cancel : nil
    end
  end
end

PokeAccess::Frame.each_pulse { PokeAccess::GenericShiftMenu.observe }
PokeAccess::Hooks.around_hook("Scene_Map", :call_menu, :optional => true) do |scene, original, args|
  PokeAccess::GenericShiftMenu.intercept(scene, original, args)
end
