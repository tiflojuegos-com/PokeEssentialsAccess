# Infinite Fusion's multi-select list (MultiSelectOptionsScene, the randomizer's choice of reference sprites): its full
# list (Window_MultiSelectFilterList) paints a chosen entry blue, which only the colour shows, so each entry says
# whether it is chosen; its confirm, select-all and cancel rows, and the read-only list of the chosen, say their text.
# A toggle repaints the same text on the same row (refreshList), so the row's read is reset there and its new state said.
module PokeAccess
  module IFMultiSelect
    # The row at index i of the full list: its text and, for an entry, whether it is chosen; nil off the list.
    def self.row(win, i)
      cmds = PokeAccess.ivar(win, :@commands)
      text = cmds.is_a?(Array) ? cmds[i] : nil
      return nil if text.nil?
      text = PokeAccess.clean(text.to_s)
      return text if [:@confirm_index, :@selall_index, :@cancel_index].any? { |iv| PokeAccess.ivar(win, iv) == i }
      flags = PokeAccess.ivar(win, :@selected_flags)
      chosen = flags.is_a?(Array) && flags[i]
      "#{text}, #{PokeAccess::I18n.t(chosen ? :if_ms_chosen : :if_ms_not_chosen)}"
    end
  end
end

PokeAccess::Menus.def_extractor("Window_MultiSelectFilterList") { |win, i| PokeAccess::IFMultiSelect.row(win, i) }

PokeAccess::Game.define("infinitefusion_common") do
  after("MultiSelectOptionsScene", :refreshList) do |scene, _r, _a|
    win = PokeAccess.sprite(scene, "option")
    PokeAccess::Cursor.reset(win, :cmd_focus) if win
  end
end
