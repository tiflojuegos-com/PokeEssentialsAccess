# Vitro's Pokegear (PokegearBase, 0282_Pokegear, opened from the pause menu and by clFastKeys): a subclass of Menu2 with its own loop
# and redraw, so the pause menu's reader never reaches it. The word under each icon as painted, the clock on the panel, and its skin
# selector (PokegearSkinSelector), six pictures named only in the script, the one in use by variable 23.
module PokeAccess
  module VitroGear
    SKIN_VARIABLE = 23

    # The clock and the weekday pbRefresh paints.
    def self.clock
      now = pbGetTimeNow
      [now.strftime("%H:%M"), _INTL(::PokegearBase::DayOfWeek[now.wday].to_s)]
    end

    # The icon under the cursor as [key, line]; the info key adds the clock.
    def self.focus(scene)
      items = PokeAccess.ivar(scene, :@items)
      sel = PokeAccess.ivar(scene, :@selected_item)
      return nil unless items.is_a?(Array) && sel.is_a?(Integer) && items[sel].is_a?(Array)
      [sel, lambda { line(items, sel) }]
    end

    def self.line(items, sel)
      row = PokeAccess::Verbosity.list_entry(PokeAccess.clean(_INTL(items[sel][1].to_s)), sel + 1, items.length)
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([row] + clock), row)
      row
    end

    # The skin under the cursor as [key, line], with the mark of the one in use, which the choice moves.
    def self.skin_focus(scene)
      items = PokeAccess.ivar(scene, :@items)
      sel = PokeAccess.ivar(scene, :@selected_item)
      return nil unless items.is_a?(Array) && sel.is_a?(Integer) && items[sel].is_a?(Array)
      used = items[sel][2] - 1 == $game_variables[SKIN_VARIABLE]
      [[sel, used], lambda { skin_line(items, sel, used) }]
    end

    def self.skin_line(items, sel, used)
      row = PokeAccess::Verbosity.list_entry(PokeAccess.clean(_INTL(items[sel][1].to_s)), sel + 1, items.length)
      row = "#{row}, #{PokeAccess::I18n.t(:rv_pc_marked)}" if used
      PokeAccess::Info.set_info(:text, row, row)
      row
    end

    READER = PokeAccess::SceneWatcher.reader("PokegearBase", :pbUpdate, :vitro_gear, :optional => true) do |scene|
      PokeAccess::VitroGear.focus(scene)
    end
    SKINS = PokeAccess::SceneWatcher.reader("PokegearSkinSelector", :pbUpdate, :vitro_gear_skin, :optional => true) do |scene|
      PokeAccess::VitroGear.skin_focus(scene)
    end
  end
end

PokeAccess::Game.define("vitro") do
  read_on_open("PokegearBase", :pbStartScene, :optional => true, :hook_container => true) do |_scene|
    PokeAccess.sentences(PokeAccess::VitroGear.clock)
  end
  # pbRefresh runs as each entry returns: the icon under the cursor is said again.
  after("PokegearBase", :pbRefresh, :optional => true, :hook_container => true) do |_scene, _r, _a|
    PokeAccess::Cursor.reset(PokeAccess::VitroGear::READER, :vitro_gear)
  end
  clear_info_on("PokegearBase", :pbEndScene)
end
