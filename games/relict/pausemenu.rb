# Relict's radial pause menu (PokemonPauseMenu_Scene as a ring of six image buttons): @index (0-5), redrawn by
# update_button on every move, is said by the word its image carries (RADIAL).
module PokeAccess
  module RelictMenu
    # The i18n keys of the six buttons' words, in @index order (the game loads its images per language).
    RADIAL = [:rel_radial_party, :rel_radial_bag, :rel_radial_encounters,
              :rel_radial_save, :rel_radial_options, :rel_radial_exit]

    # Speaks the focused button, once per change.
    def self.announce(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return unless idx && idx >= 0
      return unless PokeAccess::Cursor.changed?(scene, :radial, idx)
      key = RADIAL[idx]
      label = key ? PokeAccess::I18n.t(key) : nil
      PokeAccess.speak(label, true)
    rescue StandardError
      nil
    end

    # The corner plate (button_floor): the tower floor and level cap, said after the focused button as the ring
    # opens; outside the tower the floor is the 0 the screen draws.
    def self.panel
      floor = digits($PokemonGlobal.dungeonFloor)
      cap = digits(getLevelCap)
      return if floor.empty? || cap.empty?
      PokeAccess::PausePanel.say([PokeAccess::I18n.t(:rel_panel_floor, :n => floor),
                                  PokeAccess::I18n.t(:rel_panel_cap, :n => cap)])
    rescue StandardError
      nil
    end

    # A number as draw_number lays it out, one digit image per character.
    def self.digits(value)
      value.to_s.split("").map { |c| c.to_i }.join
    end

    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end
    def self.poll; announce(@scene) if @scene; end

    # Back from a subscreen or a dialogue (MenuReturn), the slot is reset so the next poll says the focused button
    # again; update_button does not run then.
    def self.returned
      PokeAccess::Cursor.reset(@scene, :radial) if @scene
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("relict") do
  after("PokemonPauseMenu_Scene", :update_button) do |scene, _ret, _args|
    PokeAccess::RelictMenu.announce(scene)
  end
  # A container: pbStartScene ends on update_button, whose hook says the focused button first.
  after("PokemonPauseMenu_Scene", :pbStartScene, :hook_container => true) do |_scene, _ret, _args|
    PokeAccess::RelictMenu.panel
  end
  # pickCommand is the menu's loop, held while it runs; the poll covers the opening read and the returns.
  around("PokemonPauseMenu_Scene", :pickCommand) do |scene, nxt, _a|
    PokeAccess::RelictMenu.watch(scene)
    PokeAccess::MenuReturn.reset_nesting
    begin; nxt.call; ensure; PokeAccess::RelictMenu.unwatch end
  end
  poll_each_frame { PokeAccess::RelictMenu.poll }
  # The ring slides away over several frames as it closes, still held: unwatched first, so nothing more is said.
  before("PokemonPauseMenu_Scene", :pbEndScene) { |_s, _a| PokeAccess::RelictMenu.unwatch }
end

PokeAccess::MenuReturn.on_return { PokeAccess::RelictMenu.returned }

# The save screen runs bare (no fade) and its boxes are messages: declared a nesting level, it makes one return.
PokeAccess::MenuReturn.bare("PokemonSaveScreen", :pbSaveScreen, :optional => true)
