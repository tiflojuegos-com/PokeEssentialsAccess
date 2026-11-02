# Vitro's Berry Blender (BerryBlenderScene, 0237_Contest_Berry blender): not Sevii's minigame, but three buttons over four slots that
# show the chosen berries as icons, and a grid of berries with their counts for adding or taking one. Each button with the grey
# of one it cannot use, what the slots hold, and each cell. The blend itself and the block go through the game's messages.
module PokeAccess
  module VitroBlender
    # Which buttons pbRefreshButtons leaves in colour for a count of berries.
    def self.enabled(count)
      [count < 4, count > 0, count >= 2]
    end

    def self.slots_text(scene)
      berries = PokeAccess.ivar(scene, :@access_bb_berries) || []
      return PokeAccess::I18n.t(:vitro_bb_empty) if berries.empty?
      PokeAccess::I18n.t(:vitro_bb_berries, :list => berries.map { |sym| PBItems.getName(getID(PBItems, sym)) }.join(", "))
    end

    # The button under the cursor, as painted, when it or its grey changed; the info key adds what the slots hold.
    def self.focus(scene)
      sel = PokeAccess.ivar_i(scene, :@selected_btn)
      on = enabled(PokeAccess.ivar_i(scene, :@current_berry_count))[sel]
      PokeAccess::Cursor.announce(scene, :vitro_bb_button, [sel, on], true, false) do
        row = PokeAccess::Verbosity.list_entry(PokeAccess.clean(BlenderConfig::BTN_LABELS[sel].to_s), sel + 1,
                                               BlenderConfig::BTN_LABELS.length)
        row = "#{row}, #{PokeAccess::I18n.t(:opt_unavailable)}" unless on
        PokeAccess::Info.set_info(:text, PokeAccess.sentences([row, slots_text(scene)]), row)
        row
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The slots as pbRefreshSlots repaints them, said when they changed, and the button under the cursor.
    def self.slots(scene, berries)
      list = berries.is_a?(Array) ? berries.dup : []
      scene.instance_variable_set(:@access_bb_berries, list)
      PokeAccess::Cursor.announce(scene, :vitro_bb_slots, list, false) { slots_text(scene) }
      focus(scene)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The grid as pbShowSelector paints it: its title, with its two buttons while hints are said.
    def self.grid_open(scene, pairs)
      rows = pairs.map { |r| PokeAccess.clean(r[0]) }
      hint = PokeAccess.sentences(rows[1, 2].map { |row| PokeAccess::KeyHints.localize(row) })
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(rows[0], hint, " "), false)
      PokeAccess::Cursor.reset(scene, :vitro_bb_cell)
      scene.instance_variable_set(:@access_bb_grid, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The cell under the cursor: the berry its icon shows and the count under it, its place, and the berry's data on the info key.
    def self.cell(scene, pos)
      return unless PokeAccess.ivar(scene, :@access_bb_grid)
      cells = PokeAccess.ivar(scene, :@sel_available)
      return unless cells.is_a?(Array) && cells[pos]
      PokeAccess::Cursor.announce(scene, :vitro_bb_cell, pos, true, false) do
        id = cells[pos][1]
        row = PokeAccess::Verbosity.list_entry("#{PBItems.getName(id)}: #{cells[pos][2]}", pos + 1, cells.length)
        PokeAccess::Info.set_info(:item, id, row)
        row
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The grid opens on the last cell chosen, which the list of berries to take out may not reach: the cursor stays painted on
    # the first cell and accepting breaks on a cell that is not there. Leaves it on the first, where it is painted.
    def self.grid_opening(scene, available)
      last = PokeAccess.ivar(scene, :@lastBerryIdx)
      scene.instance_variable_set(:@lastBerryIdx, 0) if last.is_a?(Integer) && last >= available.length
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The grid has closed: the button again when nothing was chosen, since a choice repaints the slots, which say it.
    def self.grid_closed(scene, chosen)
      scene.instance_variable_set(:@access_bb_grid, false)
      PokeAccess::Cursor.reset(scene, :vitro_bb_button)
      focus(scene) unless chosen
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  before("BerryBlenderScene", :pbStartScene, :optional => true) { |_s, _a| PokeAccess.speak(_INTL("Licuabayas"), false) }
  after("BerryBlenderScene", :pbRefreshSlots, :optional => true) { |s, _r, a| PokeAccess::VitroBlender.slots(s, a[0]) }
  after("BerryBlenderScene", :pbRefreshButtons, :optional => true) { |s, _r, _a| PokeAccess::VitroBlender.focus(s) }
  on_paint("BerryBlenderScene", :pbShowSelector, :optional => true) do |s, pairs, _a|
    PokeAccess::VitroBlender.grid_open(s, pairs)
  end
  after("BerryBlenderScene", :pbUpdateCursor, :optional => true) { |s, _r, a| PokeAccess::VitroBlender.cell(s, a[0]) }
  around("BerryBlenderScene", :pbGridSelect, :optional => true) do |s, nxt, a|
    PokeAccess::VitroBlender.grid_opening(s, a[0])
    ret = nxt.call
    PokeAccess::VitroBlender.grid_closed(s, ret)
    ret
  end
  clear_info_on("BerryBlenderScene", :pbEndScene)
end
