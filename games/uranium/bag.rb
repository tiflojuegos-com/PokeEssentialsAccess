module PokeAccess
  # Uranium's Black/White bag list (Window_PokemonBag over Window_DrawableCommandBag, not a Window_DrawableCommand):
  # the focused row as the list and its side panel paint it, headed by the pocket's name when the pocket changes, and
  # said again each time the list takes the focus back (after an item's menu).
  module UraniumBag
    # Says the focused row once per change of pocket, row or row contents while the list has the focus; an empty
    # pocket says the panel's message.
    def self.update(win)
      PokeAccess.dedicate(win)
      return unless win.active
      idx = win.index
      entry = ((PokeAccess.ivar(win, :@bag).pockets[win.pocket] || [])[idx] rescue nil)
      PokeAccess::Cursor.announce(win, :ura_bag_list, [win.pocket, idx, witness(win, entry, idx)], true, false) do
        text = entry ? row(win, entry, idx) : empty_text
        prefix = PokeAccess::Menus.bag_prefix(win)
        PokeAccess::Menus.mark_bag_pocket(win)
        "#{prefix}#{text}"
      end
    end

    # What a row says that can change under a still cursor: the item, its count, its mark and whether it is moving.
    def self.witness(win, entry, idx)
      return nil unless entry.is_a?(Array)
      [entry[0], entry[1], mark(win, entry[0]), win.sortIndex == idx]
    end

    # A pocket row at the bag reading's level: the name as the panel paints it (a machine with its move), the count
    # where the panel shows one, the key-item icon's mark and the moving mark while sorting.
    def self.row(win, entry, idx)
      item = entry[0]
      ad = PokeAccess.ivar(win, :@adapter)
      name = (ad.getDisplayName(item) rescue nil) || PokeAccess::Data.item_name(item) || item.to_s
      (PokeAccess::Info.note_item_desc(item, ad.getDescription(item)) rescue nil)
      parts = [[PokeAccess::Menus.bag_hides_qty?(item) ? name.to_s : "#{name}: #{entry[1]}", :brief]]
      m = mark(win, item)
      parts.push([PokeAccess::I18n.t(m), :medium]) if m
      parts.push([PokeAccess::I18n.t(:bag_moving), :brief]) if win.sortIndex == idx
      PokeAccess::Info.set_info(:item, item, PokeAccess::Verbosity.full_line(parts))
      PokeAccess::Verbosity.line(:bag_item, parts)
    end

    # The key-item icon a row shows: registered when in the bag's keyItemsSelected, registrable for another key
    # item with a key-item handler, else none.
    def self.mark(win, item)
      return nil unless (pbIsKeyItem?(item) && ItemHandlers.hasKeyItemHandler(item) rescue false)
      chosen = (PokeAccess.ivar(win, :@bag).keyItemsSelected rescue nil) || []
      chosen.include?(item) ? :bag_registered : :bag_registrable
    end

    # The message the panel paints over an empty pocket, in the game's words.
    def self.empty_text
      (_INTL("It's empty.") rescue nil) || PokeAccess::I18n.t(:row_empty)
    end
  end
end

PokeAccess::Game.define("uranium") do
  after("Window_DrawableCommandBag", :update) { |win, _r, _a| PokeAccess::UraniumBag.update(win) }
  before("PokemonBag_Scene", :pbChooseItem) do |scene, _a|
    PokeAccess::Cursor.reset(PokeAccess.sprite(scene, "itemwindow"), :ura_bag_list)
  end
end

# The registered key items list keeps item ids and paints their names; the core's command-window hook reads it.
PokeAccess::Menus.def_extractor("Window_CommandKeyItems") do |win, i|
  id = (PokeAccess.ivar(win, :@commands) || [])[i]
  id ? (PBItems.getName(id) rescue nil) : nil
end
