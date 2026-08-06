module PokeAccess
  # Sprite-button pause menus: a fangame addon that replaces PokemonMenu_Scene with a custom bezier/sprite
  # panel (no command window). selectButton(index) fires on open and on every cursor move over @buttons (an
  # array of [key, label] pairs), so reading the focused label there voices the whole menu, opening
  # included, with no duplication. A profile with this menu opts in with SpriteButtonMenu.define(game).
  module SpriteButtonMenu
    @depth = 0
    @last = nil

    # Speaks the focused button and remembers it, so the return below has something to repeat.
    def self.focus(scene, idx)
      buttons = PokeAccess.ivar(scene, :@buttons)
      return unless buttons.is_a?(Array) && idx && idx >= 0 && idx < buttons.length
      label = (buttons[idx][1] rescue nil)
      return if label.nil? || label.to_s.empty?
      @last = label.to_s
      PokeAccess.speak_clean(@last, true)
    rescue StandardError
      nil
    end

    # A depth and not a flag: the two games that ship this menu keep their loop in different methods
    # (pbStartScene in one, pbMenuLoop in the other), both are held, and in the first the second is nested
    # inside it. A flag would be cleared by the inner one while the menu was still up.
    def self.open!; @depth += 1; end

    # The label is NOT cleared on the way out. Armonia announces the opening option from inside pbStartScene
    # and only then enters its loop, so clearing here wiped the label between the two and the first return
    # from a subscreen came back silent -- the very case this exists for. Leaving it stale costs nothing: the
    # depth gate is what decides whether anything may be said.
    def self.close!
      @depth -= 1 if @depth > 0
    end

    # Coming back from a subscreen. These menus open the party, the bag and the rest from inside their own
    # loop and then simply carry on: selectButton never runs again, so the menu came back silent with the
    # cursor on an option the player could no longer hear. The fade is the signal -- every option that
    # returns here is wrapped in pbFadeOutIn, and the ones that do not return (save, quit) close the menu.
    #
    # Gated on the menu being OPEN, because pbFadeOutIn is the engine's fade for everything: without the
    # gate a map transition would announce the last pause-menu option out of nowhere.
    def self.returned
      PokeAccess.speak_clean(@last, true) if @depth > 0 && @last
    rescue StandardError
      nil
    end

    # Registers the selectButton reader for a game profile.
    def self.define(game)
      PokeAccess::Game.define(game) do
        after("PokemonMenu_Scene", :selectButton) do |scene, _r, args|
          PokeAccess::SpriteButtonMenu.focus(scene, args[0])
        end
        # The menu's blocking loop is held rather than hooked after, because holding is the only thing that
        # tells the fade below whether the menu is still on screen. Which method holds the loop differs by
        # game -- Africanvs runs it inside pbStartScene, Armonia in a pbMenuLoop of its own -- so both are
        # registered and each binds only where it exists.
        ["pbStartScene", "pbMenuLoop"].each do |meth|
          around("PokemonMenu_Scene", meth.to_sym, :optional => true) do |_s, nxt, _a|
            PokeAccess::SpriteButtonMenu.open!
            begin; nxt.call; ensure; PokeAccess::SpriteButtonMenu.close!; end
          end
        end
        kernel("pbFadeOutIn", :after) { |_args, _r| PokeAccess::SpriteButtonMenu.returned }
      end
    end
  end
end
