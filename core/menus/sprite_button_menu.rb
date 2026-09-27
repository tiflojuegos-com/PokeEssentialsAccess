module PokeAccess
  # Sprite-button pause menus (a PokemonMenu_Scene with @buttons, [key, label] pairs, and no command window): the
  # focused label on each selectButton, opening included. A profile opts in with SpriteButtonMenu.define(game).
  module SpriteButtonMenu
    @depth = 0
    @last = nil

    # Speaks the focused button and keeps it for returned; sets the info key's trainer answer, since these loops
    # never update the map.
    def self.focus(scene, idx)
      PokeAccess::Info.set_info(:trainer, nil)
      buttons = PokeAccess.ivar(scene, :@buttons)
      return unless buttons.is_a?(Array) && idx && idx >= 0 && idx < buttons.length
      label = (buttons[idx][1] rescue nil)
      return if label.nil? || label.to_s.empty?
      @last = PokeAccess::Menus.button_label(label)
      PokeAccess.speak_clean(@last, true)
    rescue StandardError
      nil
    end

    # A depth, not a flag: pbStartScene and pbMenuLoop are both held, and one can nest in the other.
    def self.open!; @depth += 1; end

    # Lowers the depth but keeps the label: a menu can speak its first option before its loop starts, and the depth
    # alone gates returned.
    def self.close!
      @depth -= 1 if @depth > 0
    end

    # Back from a subscreen (MenuReturn's outermost exit): repeats the last focused button while the menu is open,
    # since selectButton does not run again; the gate keeps map fades silent.
    def self.returned
      return unless @depth > 0
      PokeAccess::Info.set_info(:trainer, nil)
      PokeAccess.speak_clean(@last, true) if @last
    rescue StandardError
      nil
    end

    # The menu ended its scene inside its loop (a key item or field move in use): its messages' returns stay silent.
    def self.gone!; @last = nil; end

    # Registers the reader for a game profile, holding the menu loop (pbStartScene or pbMenuLoop) so returned knows
    # the menu is up.
    # param bare [Class, method, opts] entries for subscreens that do not fade; opts (optional) go to MenuReturn.bare
    def self.define(game, bare = [])
      PokeAccess::Game.define(game) do
        after("PokemonMenu_Scene", :selectButton) do |scene, _r, args|
          PokeAccess::SpriteButtonMenu.focus(scene, args[0])
        end
        ["pbStartScene", "pbMenuLoop"].each do |meth|
          around("PokemonMenu_Scene", meth.to_sym, :optional => true) do |_s, nxt, _a|
            PokeAccess::SpriteButtonMenu.open!
            PokeAccess::MenuReturn.reset_nesting
            begin; nxt.call; ensure; PokeAccess::SpriteButtonMenu.close! end
          end
        end
        before("PokemonMenu_Scene", :pbEndScene, :optional => true) { |_s, _a| PokeAccess::SpriteButtonMenu.gone! }
      end
      bare.each do |cname, meth, extra|
        PokeAccess::MenuReturn.bare(cname, meth.to_sym, { :optional => true }.merge(extra || {}))
      end
    end
  end
end

PokeAccess::MenuReturn.on_return { PokeAccess::SpriteButtonMenu.returned }
