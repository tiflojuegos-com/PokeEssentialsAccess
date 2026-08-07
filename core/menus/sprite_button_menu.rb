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
      @last = PokeAccess::Menus.button_label(label)
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

    @fade = 0

    # Only the OUTERMOST fade puts this menu back in front. Its children fade too -- giving an item from
    # inside the bag, opening storage inside the PC -- and an inner fade ends with the CHILD on screen, so
    # announcing the menu's option there talks over a screen that is not this one.
    def self.fade_in!; @fade += 1; end

    def self.fade_out!
      @fade = [@fade - 1, 0].max
      returned if @fade == 0
    end

    # Forgets the nesting, for a map change or any other point where the menu is gone without its fades
    # having balanced (a screen that exits through a throw leaves the counter high, and then the next real
    # return is swallowed as if it were nested).
    def self.reset_nesting; @fade = 0; end

    # Registers the selectButton reader for a game profile.
    #
    # The menu's blocking loop is HELD rather than hooked after, because holding is the only thing that
    # tells the fade below whether the menu is still on screen. Which method holds the loop differs by game
    # -- Africanvs runs it inside pbStartScene, Armonia in a pbMenuLoop of its own -- so both are
    # registered and each binds only where it exists.
    #
    # The fade is wrapped AROUND and not hooked after, so a fade nested inside another does not announce
    # the parent menu over the child that is actually on screen.
    #
    # param bare a list of ["Class", :method] whose call is a subscreen that does NOT fade. Every option
    #   that fades is covered by that wrap; one called bare returns with nothing to signal it, and the menu
    #   comes back silent with the cursor on an option the player can no longer hear. They count as a
    #   nesting level like a fade does, so returning from one announces exactly once.
    def self.define(game, bare = [])
      PokeAccess::Game.define(game) do
        after("PokemonMenu_Scene", :selectButton) do |scene, _r, args|
          PokeAccess::SpriteButtonMenu.focus(scene, args[0])
        end
        ["pbStartScene", "pbMenuLoop"].each do |meth|
          around("PokemonMenu_Scene", meth.to_sym, :optional => true) do |_s, nxt, _a|
            PokeAccess::SpriteButtonMenu.open!
            PokeAccess::SpriteButtonMenu.reset_nesting
            begin; nxt.call; ensure; PokeAccess::SpriteButtonMenu.close! end
          end
        end
        bare.each do |cname, meth|
          around(cname, meth.to_sym, :optional => true) do |_s, nxt, _a|
            PokeAccess::SpriteButtonMenu.fade_in!
            begin; nxt.call; ensure; PokeAccess::SpriteButtonMenu.fade_out! end
          end
        end
        kernel("pbFadeOutIn", :around) do |_args, nxt|
          PokeAccess::SpriteButtonMenu.fade_in!
          begin; nxt.call; ensure; PokeAccess::SpriteButtonMenu.fade_out! end
        end
      end
    end
  end
end
