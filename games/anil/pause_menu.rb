# Anil's additions to Marin's pause menu (DP_PauseMenu), painted only as icons beside its shortcuts: the infinite
# repel's state, day or night, and the one-capture rule's used encounter. Each is noted as a line of the panel the
# menu paints while it is built, where the icon stands, so plugins/dp_pausemenu.rb says it with the rest.
module PokeAccess
  module AnilPauseMenu
    # One of the menu's layout constants, or the value it ships with.
    def self.layout(name, fallback)
      v = PokeAccess.const_at("DP_PauseMenu::#{name}")
      v.is_a?(Numeric) ? v : fallback
    end

    # Notes a line into the panel being painted, at (x, y); nothing once the panel has been said (a redraw).
    def self.note(text, x, y)
      return unless PokeAccess::PaintCapture.armed?(:dp_panel)
      PokeAccess::PaintCapture.note(text, :positions, x, y)
    end

    # The repel's state, just under its shortcut line ("[W] Rep. Inf."), whose icon alone shows it.
    def self.repel(menu)
      y = PokeAccess.ivar(menu, :@repel_y_pos)
      return unless y.is_a?(Numeric)
      key = ($PokemonGlobal.infRepel rescue false) ? :anil_repel_on : :anil_repel_off
      note(PokeAccess::I18n.t(key), layout(:TEXT_X, 64), y + layout(:TEXT_Y_OFFSET, 24) + 1)
    end

    # Where the menu puts its next icon of the right column (the sun or moon, the encounter), as it keeps it.
    def self.right_y(menu)
      y = PokeAccess.ivar(menu, :@current_right_icon_y)
      y.is_a?(Numeric) ? y : layout(:SHORTCUT_START_Y, 4)
    end

    # Day or night, as the sun or moon icon at y shows it.
    def self.sun_moon(y)
      key = (PBDayNight.isNight? rescue false) ? :anil_moon : :anil_sun
      note(PokeAccess::I18n.t(key), layout(:RIGHT_ICON_START_X, 245), y)
    end

    # The Poke Ball the one-capture rule draws at y when this map's encounter is used.
    def self.encounter_used(y)
      note(PokeAccess::I18n.t(:anil_map_encounter_used), layout(:RIGHT_ICON_START_X, 245), y)
    end
  end
end

PokeAccess::Game.define("anil") do
  around("DP_PauseMenu", :draw_repel_shortcut, :optional => true) do |menu, nxt, _a|
    ret = nxt.call
    PokeAccess::AnilPauseMenu.repel(menu)
    ret
  end

  around("DP_PauseMenu", :draw_sun_moon_icon, :optional => true) do |menu, nxt, _a|
    y = PokeAccess::AnilPauseMenu.right_y(menu)
    ret = nxt.call
    PokeAccess::AnilPauseMenu.sun_moon(y)
    ret
  end

  # The encounter icon is drawn only while the rule holds on this map, which moves the right column's next place.
  around("DP_PauseMenu", :draw_captured_icon, :optional => true) do |menu, nxt, _a|
    before = PokeAccess.ivar(menu, :@current_right_icon_y)
    y = PokeAccess::AnilPauseMenu.right_y(menu)
    ret = nxt.call
    PokeAccess::AnilPauseMenu.encounter_used(y) unless PokeAccess.ivar(menu, :@current_right_icon_y) == before
    ret
  end
end
