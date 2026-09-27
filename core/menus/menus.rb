module PokeAccess
  # Command windows: per-class extractor dispatch over Window_DrawableCommand.
  module Menus
    EXTRACTORS = []

    # Registers an extractor for a window class. yields (window, index) -> the focused option text
    def self.def_extractor(cname, &blk)
      EXTRACTORS.push([cname, blk])
    end

    # Speaks a sprite-driven menu's focused entry when @index changes (entries in items_ivar); the block maps the
    # entry to its spoken name, deduped on the scene under dedup_slot.
    def self.poll_sprite_menu(scene, items_ivar, dedup_slot)
      items = PokeAccess.ivar(scene, items_ivar)
      idx = PokeAccess.ivar(scene, :@index)
      return unless items.is_a?(Array) && idx && idx >= 0 && idx < items.length
      PokeAccess::Cursor.announce(scene, dedup_slot, idx) { yield(items[idx]) }
    rescue StandardError => e
      PokeAccess.log_once("poll_sprite_#{scene.class}", e)
    end

    # The focused option's text for a command window: the most derived matching extractor wins (the first registered
    # on a tie); one that raises is logged once and falls back to the generic read.
    def self.focused_text(win)
      i = win.index
      return nil if i.nil? || i < 0
      matches = EXTRACTORS.map do |cname, blk|
        k = PokeAccess.const_at(cname)
        d = (k && win.is_a?(k)) ? win.class.ancestors.index(k) : nil
        d ? [d, cname, blk] : nil
      end
      best_d, best_name, best_blk = matches.compact.min_by { |m| m[0] }
      return generic_focus(win, i) unless best_blk
      begin
        best_blk.call(win, i)
      rescue StandardError => e
        log = (@ext_logged ||= [])
        unless log.include?(best_name)
          log << best_name
          PokeAccess.write_marker("extractor #{best_name}: #{e.class}: #{e.message}\n")
        end
        generic_focus(win, i)
      end
    end

    # True for a row of nothing but dashes, dots, underscores and spaces: a placeholder such as an empty save slot.
    def self.placeholder?(t)
      s = t.to_s
      !s.empty? && !(s =~ /\A[\s\-_.]+\z/).nil?
    end

    # A row of nothing but question marks (an entry not found yet, as quest logs and field lists paint it) as the word
    # for unknown, since a screen reader leaves the marks unsaid; any other row untouched.
    def self.unknown_row(t)
      (t.is_a?(String) && t =~ /\A\s*\?{2,}\s*\z/) ? PokeAccess::DexEntry.unknown_marks(t.strip) : t
    end

    # A toggle row as Essentials writes one: "[X] Option" or "[  ] Option" ("[Y]" in the debug badge and dex lists).
    CHECKBOX = /\A\[\s*([XxY]?)\s*\]\s*(\S.*)\z/m

    # A toggle row as its option and its state in words; any other row untouched.
    def self.checkbox_row(t)
      return t unless t.is_a?(String) && t =~ CHECKBOX
      "#{$2}, #{PokeAccess::I18n.t($1.empty? ? :val_off : :val_on)}"
    end

    # A shop row that is an action (a Symbol, as Infinite Fusion's "Remove hat"), by its painted caption; else nil.
    def self.mart_special(ad, item)
      return nil unless item.is_a?(Symbol)
      cap = (ad.getSpecialItemCaption(item) rescue nil)
      (cap && !cap.to_s.empty?) ? cap.to_s : nil
    end

    # Stores the shop adapter's description for the info key as the shop shows it, its "???" said as unknown.
    def self.mart_note_desc(ad, item)
      return unless ad.respond_to?(:getDescription)
      d = (ad.getDescription(item) rescue nil)
      PokeAccess::Info.note_item_desc(item, PokeAccess::DexEntry.unknown_marks(d.to_s)) if d
    rescue StandardError
      nil
    end

    # The i18n keys a shop row tells only by colour; none here, overridden by a game whose shop colours its rows.
    def self.mart_marks(_ad, _item)
      []
    end

    # Whether a clothes shop paints this row in its "worn" colour (asked of the adapter, then of the one it wraps).
    def self.mart_worn?(ad, item)
      v = (ad.isWornItem?(item) rescue nil)
      v = (ad.getAdapter.isWornItem?(item) rescue nil) if v.nil?
      v ? true : false
    end

    # A Pokedex list row: number and name, plus caught or seen from the Pokedex reading's medium level; an unseen
    # species is its number and "unknown". The info key keeps the whole row.
    # param seen, owned what the row paints, where the game decides it otherwise; nil asks the player's Pokedex
    def self.dex_row(num, species, name, seen = nil, owned = nil)
      seen = PokeAccess::Util.dex_seen?(species) if seen.nil?
      unless seen
        row = "#{num}, #{PokeAccess::I18n.t(:dex_unknown)}"
        PokeAccess::Info.set_info(:text, row)
        return row
      end
      owned = PokeAccess::Util.dex_owned?(species) if owned.nil?
      state = PokeAccess::I18n.t(owned ? :dex_caught : :dex_seen)
      PokeAccess::Verbosity.info_line(:dex_entry, [[num.to_s, :brief], [name.to_s, :brief], [state, :medium]])
    end

    # The ivars a selectable window commonly keeps its option list in, tried in order.
    LIST_IVARS = [:@commands, :@items, :@list, :@data, :@choices, :@names, :@entries, :@stock]

    # A field-menu button label; one that is the player's own name (the trainer card button) also names the card.
    def self.button_label(label)
      s = label.to_s
      name = (PokeAccess::Engine.player.name rescue nil)
      return s if name.nil? || s.empty? || s != name.to_s
      "#{s}, #{PokeAccess::I18n.t(:tc_title)}"
    rescue StandardError
      label.to_s
    end

    # The focused entry's text by introspecting the window's own option list, or nil; the fallback for
    # command windows and the reader for the generic SpriteWindow_Selectable hook.
    def self.generic_focus(win, i)
      LIST_IVARS.each do |iv|
        lst = PokeAccess.ivar(win, iv)
        next unless lst.is_a?(Array) && i >= 0 && i < lst.length
        t = entry_text(lst[i])
        return t if t && !t.empty?
      end
      nil
    end

    # One list entry as text: a String or Symbol, else its non-empty String .name or .text; else nil.
    def self.entry_text(e)
      return nil if e.nil?
      return e if e.is_a?(String)
      return e.to_s if e.is_a?(Symbol)
      nm = (e.name rescue nil); return nm if nm.is_a?(String) && !nm.empty?
      tx = (e.text rescue nil); return tx if tx.is_a?(String) && !tx.empty?
      nil
    end

    # Base extractors, shared across Essentials fangames.

    # The party menu's rows: a field move (@colorKey 1, painted blue) is said as such; other keys are plugin colours
    # with no word.
    def_extractor("Window_CommandPokemonColor") do |win, i|
      cmds = win.instance_variable_get(:@commands)
      name = (cmds[i] rescue nil)
      next nil if name.nil?
      key = (win.instance_variable_get(:@colorKey)[i] rescue nil)
      (key == 1) ? "#{name}, #{PokeAccess::I18n.t(:mn_field_move)}" : name.to_s
    end

    def_extractor("Window_PokemonOption") do |win, i|
      opts = win.instance_variable_get(:@options)
      next PokeAccess::Options.exit_label(win) if i >= opts.length
      PokeAccess::Options.row(opts[i], win[i], PokeAccess::Options.painted_value(win, i, win[i]))
    end

    # The bag's focused row without the pocket prefix, at the bag reading's level: name, count and moving always,
    # marks from medium; no count where the bag paints none. The count is the pocket entry's [item, count], or the
    # bag's contents table where pockets hold bare ids (the Reborn engine). Moves no reader state: the diag polls it.
    def self.bag_row(win, i)
      bag = win.instance_variable_get(:@bag)
      pocket = win.pocket
      pocket_entries = (bag.pockets[pocket] rescue nil)
      filterlist = (win.instance_variable_get(:@filterlist) rescue nil)
      visible = (filterlist && filterlist[pocket]) ? filterlist[pocket] : pocket_entries
      count = (win.respond_to?(:itemCount) ? (win.itemCount rescue nil) : nil)
      count = visible.length + 1 if count.nil? && visible
      return PokeAccess::I18n.t(:mn_close_bag) if count.nil? || i >= count - 1
      real = (filterlist && filterlist[pocket]) ? filterlist[pocket][i] : i
      itemid = (win.item rescue nil) if win.respond_to?(:item)
      itemid = (pocket_entries[real][0] rescue nil) if itemid.nil? && real
      return PokeAccess::I18n.t(:mn_close_bag) if itemid.nil?
      ad = win.instance_variable_get(:@adapter)
      (PokeAccess::Info.note_item_desc(itemid, ad.getDescription(itemid)) rescue nil) if ad && ad.respond_to?(:getDescription)
      name = (ad.getDisplayName(itemid) rescue nil) if ad
      name = (PokeAccess::Data.item_name(itemid) || itemid.to_s) if name.nil? || name.to_s.empty?
      name = bag_decorated_name(ad, itemid, name)
      entry = (pocket_entries[real] rescue nil)
      qty = entry.is_a?(Array) ? entry[1] : (bag.contents[itemid] rescue nil)
      qty = nil if bag_hides_qty?(itemid)
      parts = [[qty ? "#{name}: #{qty}" : "#{name}", :brief]]
      bag_marks(bag, itemid).each { |k| parts.push([PokeAccess::I18n.t(*Array(k)), :medium]) }
      parts.push([PokeAccess::I18n.t(:bag_registered), :medium]) if bag_registered?(bag, itemid)
      parts.push([PokeAccess::I18n.t(:bag_registrable), :medium]) if bag_registrable?(bag, itemid)
      moving = ((win.instance_variable_get(:@sortIndex) rescue -1) == i) ||
               ((win.instance_variable_get(:@sorting) rescue false) && (win.index rescue -1) == i)
      parts.push([PokeAccess::I18n.t(:bag_moving), :brief]) if moving
      (PokeAccess::Info.set_info(:item, itemid, PokeAccess::Verbosity.full_line(parts)) rescue nil)
      PokeAccess::Verbosity.line(:bag_item, parts)
    end

    # A cheap per-frame change witness for a bag row: the entry's id, raw count and bag_row's marks, read off the bag,
    # so a toss or use under a still cursor is heard without building the row every frame.
    def self.bag_witness(win, i)
      bag = win.instance_variable_get(:@bag)
      pocket = win.pocket
      filterlist = (win.instance_variable_get(:@filterlist) rescue nil)
      real = (filterlist && filterlist[pocket]) ? filterlist[pocket][i] : i
      entry = (bag.pockets[pocket][real] rescue nil)
      entry = bare_bag_entry(win, bag, entry) unless entry.is_a?(Array)
      return nil unless entry.is_a?(Array)
      moving = ((win.instance_variable_get(:@sortIndex) rescue -1) == i) ||
               ((win.instance_variable_get(:@sorting) rescue false) && (win.index rescue -1) == i)
      [entry[0], entry[1], bag_marks(bag, entry[0]), bag_registered?(bag, entry[0]),
       bag_registrable?(bag, entry[0]), moving]
    end

    # A pocket entry kept as a bare id (the Reborn engine) as [id, count]: the window's focused item, as bag_row reads
    # it, and its count from the bag's contents table; nil past the last item.
    def self.bare_bag_entry(win, bag, entry)
      id = win.respond_to?(:item) ? (win.item rescue nil) : nil
      id ||= entry
      id.nil? ? nil : [id, (bag.contents[id] rescue nil)]
    end

    # A cheap witness that a command window's list changed under a still cursor: [row count, focused row] (an
    # Array, not a string: 1.8.7's Array#to_s has no separator); nil when the rows are out of reach.
    def self.list_witness(win, i)
      cmds = win.instance_variable_get(:@commands)
      return nil unless cmds.is_a?(Array)
      [cmds.length, cmds[i]]
    rescue StandardError
      nil
    end

    # Bag row decorators registered by plugins and profiles: each answers name(adapter, itemid) with a replacement
    # name or nil and marks(bag, itemid) with the i18n keys to append (a [key, vars] pair for a key with slots), which
    # the witness reads too.
    def self.bag_decorators; @bag_decorators ||= []; end

    def self.bag_decorated_name(ad, itemid, name)
      bag_decorators.each do |d|
        n = (d.name(ad, itemid) rescue nil)
        name = n.to_s if n && !n.to_s.empty?
      end
      name
    end

    def self.bag_marks(bag, itemid)
      bag_decorators.inject([]) { |all, d| all + ((d.marks(bag, itemid) rescue nil) || []) }
    end

    # True when the screen hides this item's quantity: by the item data's show_quantity? where it exists (v21), else
    # for any important item (key item, machine).
    def self.bag_hides_qty?(itemid)
      data = (::GameData::Item.get(itemid) rescue nil)
      sq = (data.show_quantity? rescue nil)
      return !sq unless sq.nil?
      return true if (pbIsImportantItem?(itemid) rescue false)
      (data.is_important? rescue false)
    end

    # Whether a hidden-count item could be registered but is not yet, by the game's own pbCanRegisterItem? (the bag
    # marks it with a second frame of the registered icon); false where that function does not exist.
    def self.bag_registrable?(bag, itemid)
      return false unless bag_hides_qty?(itemid)
      return false if bag_registered?(bag, itemid)
      (pbCanRegisterItem?(itemid) rescue false) ? true : false
    rescue StandardError
      false
    end

    # Whether this item is registered, in any shape: registered? (or else the old single slot, which Pokemon Z also
    # paints), pbIsRegistered?, or a registeredItem(s) slot or array.
    def self.bag_registered?(bag, itemid)
      r = (bag.registered?(itemid) rescue nil)
      unless r.nil?
        return true if r
        slot = (bag.registeredItem rescue nil)
        return !slot.nil? && !slot.is_a?(Array) && slot == itemid
      end
      r = (bag.pbIsRegistered?(itemid) rescue nil)
      return (r ? true : false) unless r.nil?
      ri = (bag.registeredItem rescue nil)
      ri = (bag.registeredItems rescue nil) if ri.nil?
      ri = (bag.instance_variable_get(:@registeredItem) rescue nil) if ri.nil?
      ri = (bag.instance_variable_get(:@registeredItems) rescue nil) if ri.nil?
      ri.is_a?(Array) ? ri.include?(itemid) : (!ri.nil? && ri == itemid)
    rescue StandardError
      false
    end

    # The pocket prefix due when the pocket differs from the last one marked as spoken, or "". Pure: the
    # mark moves only via mark_bag_pocket, from the site that actually spoke.
    def self.bag_prefix(win)
      pocket = win.pocket
      return "" if pocket == PokeAccess.ivar(win, :@access_bag_pocket)
      pn = (PokemonBag.pocketNames[pocket] rescue nil)
      pn = (PokemonBag.pocket_names[pocket - 1] rescue nil) if pn.nil? || pn.to_s.empty?
      (pn && !pn.to_s.empty?) ? "#{pn}. " : ""
    end

    # Records the pocket as spoken, so the next row read in it carries no prefix.
    def self.mark_bag_pocket(win)
      win.instance_variable_set(:@access_bag_pocket, win.pocket)
    rescue StandardError
      nil
    end

    # Bag rows: the pocket name leads the row only when the pocket changed.
    def_extractor("Window_PokemonBag") do |win, i|
      "#{bag_prefix(win)}#{bag_row(win, i)}"
    end

    # The multi-dex region list: name and completion marks, the seen and owned counters from the Pokedex reading's
    # medium level, the region's total (where the row has one) at full; the info key keeps the whole row.
    def_extractor("Window_DexesList") do |win, i|
      base = generic_focus(win, i).to_s
      seen = (win.instance_variable_get(:@seen) rescue nil)
      owned = (win.instance_variable_get(:@owned) rescue nil)
      pair = (seen.is_a?(Array) && i < seen.length) ? [seen[i], (owned.is_a?(Array) ? owned[i] : 0)] : nil
      c2 = (win.instance_variable_get(:@commands2) rescue nil)
      row = (c2.is_a?(Array) && c2[i].is_a?(Array)) ? c2[i] : nil
      pair = [row[0], row[1]] if pair.nil? && row
      tot = (row && row[2].is_a?(Integer) && row[2] > 0) ? row[2] : nil
      next base unless pair
      marks = []
      marks.push(PokeAccess::I18n.t(:dex_region_complete)) if tot && pair[1].to_i >= tot
      marks.push(PokeAccess::I18n.t(:dex_region_all_seen)) if tot && pair[1].to_i < tot && pair[0].to_i >= tot
      counts = PokeAccess::I18n.t(:dex_region_counts, :name => base, :seen => pair[0], :owned => pair[1])
      whole = tot ? PokeAccess::I18n.t(:dex_region_counts_tot, :name => base, :seen => pair[0], :owned => pair[1], :tot => tot) : counts
      PokeAccess::Info.set_info(:text, [whole].concat(marks).join(", "))
      shown = if PokeAccess::Verbosity.keep?(:dex_entry, :full) then whole
              elsif PokeAccess::Verbosity.keep?(:dex_entry, :medium) then counts
              else base
              end
      [shown].concat(marks).join(", ")
    end

    def_extractor("Window_PokemonMart") do |win, i|
      stock = win.instance_variable_get(:@stock)
      next PokeAccess::I18n.t(:pc_cancel) if i >= stock.length
      ad = win.instance_variable_get(:@adapter)
      special = PokeAccess::Menus.mart_special(ad, stock[i])
      PokeAccess::Info.set_info(:text, special) if special
      next special if special
      PokeAccess::Menus.mart_note_desc(ad, stock[i])
      price = (ad.getDisplayPrice(stock[i]) rescue nil)
      parts = [[ad.getDisplayName(stock[i]).to_s, :brief], [price, :brief]]
      parts.push([PokeAccess::I18n.t(:shop_worn), :brief]) if PokeAccess::Menus.mart_worn?(ad, stock[i])
      PokeAccess::Menus.mart_marks(ad, stock[i]).each { |k| parts.push([PokeAccess::I18n.t(k), :medium]) }
      PokeAccess::Info.set_info(:item, stock[i], PokeAccess::Verbosity.full_line(parts))
      PokeAccess::Verbosity.line(:shop_item, parts)
    end

    def_extractor("Window_PokemonItemStorage") do |win, i|
      bag = win.instance_variable_get(:@bag)
      next PokeAccess::I18n.t(:pc_cancel) if i >= bag.length
      PokeAccess::Info.set_info(:item, bag[i][0])
      nm = win.instance_variable_get(:@adapter).getDisplayName(bag[i][0])
      PokeAccess::Menus.bag_hides_qty?(bag[i][0]) ? nm.to_s : "#{nm}: #{bag[i][1]}"
    end

    # Naming grid: read the focused character, the space/switch/ok controls by name.
    def_extractor("Window_CharacterEntry") do |win, i|
      cs = win.instance_variable_get(:@charset) || []
      if i < cs.length
        c = cs[i].to_s
        c == " " ? PokeAccess::I18n.t(:key_space) : c
      elsif i == cs.length
        PokeAccess::I18n.t(:key_space)
      elsif i == cs.length + 1
        PokeAccess::I18n.t(:kb_switch)
      else
        PokeAccess::I18n.t(:kb_ok)
      end
    end

    # A Pokedex list row, from gen-6 arrays [species, name, height, weight, number, shift] or modern hashes {:species,
    # :name, :number, :shift}; a set shift lowers the number by one, as drawItem paints it. Read through dex_row; a
    # game whose rows take another shape overrides this.
    def self.dex_list_row(_win, c)
      if c.is_a?(Hash)
        sp = c[:species]
        num = c[:number].to_i
        num -= 1 if c[:shift]
        nm = c[:name]
        nm = (PokeAccess::Data.species_name(sp) || "?") if nm.nil? || nm.to_s.empty?
        dex_row(num, sp, nm)
      else
        num = c[4].to_i
        num -= 1 if c[5]
        dex_row(num, c[0], c[1])
      end
    end

    def_extractor("Window_Pokedex") do |win, i|
      c = win.instance_variable_get(:@commands)[i]
      c ? PokeAccess::Menus.dex_list_row(win, c) : ""
    end
  end
end

# Command-window navigation: first read queued, later moves interrupt; skips @ignore_input and dedicated windows.
# Keyed on index, pocket and a list witness, so a list replaced under a still cursor is read again.
PokeAccess::Hooks.after_hook("Window_DrawableCommand", :update) do |win, _r, _a|
  next if (win.instance_variable_get(:@ignore_input) rescue false)
  next if PokeAccess.dedicated?(win)
  idx = win.instance_variable_get(:@index)
  next unless win.active && idx && idx >= 0
  pkt = (win.respond_to?(:pocket) ? (win.pocket rescue nil) : nil)
  wit = pkt ? (PokeAccess::Menus.bag_witness(win, idx) rescue nil) : PokeAccess::Menus.list_witness(win, idx)
  PokeAccess::Cursor.announce(win, :cmd_focus, [idx, pkt, wit], true, false) do
    t = PokeAccess::Menus.focused_text(win)
    PokeAccess::Menus.mark_bag_pocket(win) if pkt && t && !t.to_s.empty?
    t = PokeAccess::Menus.unknown_row(t)
    PokeAccess::Menus.placeholder?(t) ? PokeAccess::I18n.t(:row_empty) : PokeAccess::Menus.checkbox_row(t)
  end
end

# The classic pause menu reruns pbShowCommands on the same window and index after every option, so each entry
# resets the window's dedup and the option is said again.
PokeAccess::Hooks.before_hook("PokemonMenu_Scene", :pbShowCommands, :optional => true) do |scene, _a|
  win = PokeAccess.sprite(scene, "cmdwindow")
  PokeAccess::Cursor.reset(win, :cmd_focus) if win
end

# Generic auto-detection (Config.auto_detect, on by default): reads a navigable SpriteWindow_Selectable with no
# dedicated reader from its own option list; command windows are left to the hook above.
PokeAccess::Hooks.after_hook("SpriteWindow_Selectable", :update) do |win, _r, _a|
  next unless (PokeAccess::Config.auto_detect rescue false)
  next if defined?(Window_DrawableCommand) && win.is_a?(Window_DrawableCommand)
  next if (win.instance_variable_get(:@ignore_input) rescue false)
  next if PokeAccess.dedicated?(win)
  idx = (win.respond_to?(:index) ? (win.index rescue nil) : win.instance_variable_get(:@index))
  next unless (win.active rescue false) && idx && idx >= 0
  pkt = (win.respond_to?(:pocket) ? (win.pocket rescue nil) : nil)
  PokeAccess::Cursor.announce(win, :auto_focus, [idx, pkt], true, false) { PokeAccess::Menus.generic_focus(win, idx) }
end
