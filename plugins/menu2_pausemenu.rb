module PokeAccess
  # PokéLiberty's icon pause menus (Menu2, the grid and the circular one): entries are [icon, label, function] and the
  # screen draws only the icons, so the focused entry is named by its icon (the label field goes undrawn and is often
  # a copy of another's); said on each redraw of the cursor, and again when an entry returns to the menu.
  module Menu2Pause
    # The word for each icon the two scripts ship, by its file name; the words come from lang/.
    ICON_WORDS = { "bag" => :m2_bag, "bolsa" => :m2_bag, "pokeball" => :m2_party, "trainer" => :m2_trainer,
                   "save" => :m2_save, "options" => :m2_options, "debug" => :m2_debug, "exit" => :m2_exit }

    @menu = nil

    # The entry under the cursor: the circular menu (the one with @angle_per_item) turns its ring against
    # @selected_item and confirms the entry its own formula picks, which also holds before the index wraps; the grid
    # confirms @selected_item.
    def self.focused_index(menu, count, sel)
      return nil if count <= 0 || !sel.is_a?(Integer)
      PokeAccess.ivar(menu, :@angle_per_item) ? (sel - count).abs % count : sel % count
    end

    # The word an entry's icon carries, or its label field for an icon the table does not know.
    def self.label(item)
      key = ICON_WORDS[item[0].to_s.downcase]
      key ? PokeAccess::I18n.t(key) : PokeAccess.clean(item[1].to_s)
    end

    # Speaks the focused entry when it changes, deduped on the menu; the info key answers with the trainer, as in
    # any pause menu.
    def self.focus(menu)
      items = PokeAccess.ivar(menu, :@items)
      return unless items.is_a?(Array)
      idx = focused_index(menu, items.length, PokeAccess.ivar(menu, :@selected_item))
      return unless idx && items[idx].is_a?(Array)
      PokeAccess::Info.set_info(:trainer, nil)
      PokeAccess::Cursor.announce(menu, :menu2_entry, idx, true) { label(items[idx]) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    def self.watch(menu); @menu = menu; end
    def self.unwatch; @menu = nil; end

    # Back from an entry while the menu's loop is held: says the focused entry again, unless the entry closed the
    # menu (@exit, set by saving and by the exit entry).
    def self.returned
      return unless @menu
      return if PokeAccess.ivar(@menu, :@exit)
      PokeAccess::Cursor.reset(@menu, :menu2_entry)
      focus(@menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# The grid redraws its cursor every frame of its loop and on opening; the circular one on opening.
PokeAccess::Hooks.after_hook("Menu2", :redrawSelector, :optional => true) do |menu, _r, _a|
  PokeAccess::Menu2Pause.focus(menu)
end

# The circular menu turns its ring here after each move.
PokeAccess::Hooks.after_hook("Menu2", :drawIcons, :optional => true) do |menu, _r, _a|
  PokeAccess::Menu2Pause.focus(menu)
end

# pbUpdate is the menu's loop, held so a return knows the menu is still up.
PokeAccess::Hooks.around_hook("Menu2", :pbUpdate, :optional => true) do |menu, nxt, _a|
  PokeAccess::Menu2Pause.watch(menu)
  PokeAccess::MenuReturn.reset_nesting
  begin; nxt.call; ensure; PokeAccess::Menu2Pause.unwatch; end
end

PokeAccess::MenuReturn.on_return { PokeAccess::Menu2Pause.returned }
