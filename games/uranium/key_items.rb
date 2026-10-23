module PokeAccess
  # Uranium's registered key items, the list F5 opens on the map (KeyItemList, a loop of its own over a
  # Window_CommandKeyItems of item ids): the core's command-window hook reads its focused row from here.
  module UraniumKeyItems
    # The focused item as the list paints it, with its place in the list; its sheet on the info key and the row on
    # Ctrl+T. nil while the name cannot be read.
    def self.row(win, i)
      ids = PokeAccess.ivar(win, :@commands) || []
      name = ids[i] ? (PBItems.getName(ids[i]) rescue nil) : nil
      return nil if name.to_s.empty?
      vb = PokeAccess::Verbosity
      PokeAccess::Info.set_info(:item, ids[i], vb.whole { vb.list_entry(name, i + 1, ids.length) })
      vb.list_entry(name, i + 1, ids.length)
    end
  end
end

PokeAccess::Game.define("uranium") do
  screen_reader("Window_CommandKeyItems") { |win, i| PokeAccess::UraniumKeyItems.row(win, i) }
end

# F5 lists the bag's registered key items, opening only with two or more (one is used at once): the list says how many
# before its first row, and with none, where the game shows nothing, that there are none. initialize runs the list's
# own loop, so the bag is read before it.
PokeAccess::Game.define("uranium") do
  before("KeyItemList", :showList) do |_list, _a|
    n = (($PokemonBag.keyItemsSelected || []).length rescue 0)
    PokeAccess.speak(PokeAccess::I18n.t(:ura_keylist_open, :n => n), true)
  end
  before("KeyItemList", :initialize) do |_list, _a|
    held = ($PokemonBag.keyItemsSelected rescue nil)
    PokeAccess.speak(PokeAccess::I18n.t(:ura_keylist_none), true) if held.is_a?(Array) && held.empty?
  end
end
