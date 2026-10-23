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
    # for unknown, since a screen reader leaves the marks unsaid; in the Pokedex's form chooser, whose rows are forms
    # seen, a form named by marks alone (Unown's) is said by the mark's name. Any other row untouched.
    def self.unknown_row(t)
      return PokeAccess::DexEntry.form_name(t) if t.is_a?(String) && PokeAccess::DexEntry.choosing_form?
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
      next PokeAccess::Options.exit_label(win, i) if i >= opts.length
      PokeAccess::Options.row(opts[i], win[i], PokeAccess::Options.painted_value(win, i, win[i]))
    end

    # A closing row's label (the bag's, a list's cancel), handed to the info key too, so T and Ctrl+T say the row under
    # the cursor rather than the item focused before it.
    def self.close_row(key)
      t = PokeAccess::I18n.t(key)
      PokeAccess::Info.set_info(:text, t)
      t
    end

    # The bag's focused row without the pocket prefix, at the bag reading's level: name, count and moving always,
    # marks from medium, then its place (bag_line); no count where the bag paints none. The count is the pocket
    # entry's [item, count], or the bag's contents table where pockets hold bare ids (the Reborn engine). Ctrl+T gets
    # the row whole. Moves no reader state: the diag polls it.
    def self.bag_row(win, i)
      bag = win.instance_variable_get(:@bag)
      pocket = win.pocket
      pocket_entries = (bag.pockets[pocket] rescue nil)
      filterlist = (win.instance_variable_get(:@filterlist) rescue nil)
      visible = (filterlist && filterlist[pocket]) ? filterlist[pocket] : pocket_entries
      count = (win.respond_to?(:itemCount) ? (win.itemCount rescue nil) : nil)
      count = visible.length + 1 if count.nil? && visible
      return close_row(:mn_close_bag) if count.nil?
      return bag_close_row(i, count) if i >= count - 1
      real = (filterlist && filterlist[pocket]) ? filterlist[pocket][i] : i
      itemid = (win.item rescue nil) if win.respond_to?(:item)
      itemid = (pocket_entries[real][0] rescue nil) if itemid.nil? && real
      return close_row(:mn_close_bag) if itemid.nil?
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
      parts.push([PokeAccess::I18n.t(:bag_registered), :medium]) if bag_registered_mark?(bag, itemid)
      parts.push([PokeAccess::I18n.t(:bag_registrable), :medium]) if bag_registrable?(bag, itemid)
      moving = ((win.instance_variable_get(:@sortIndex) rescue -1) == i) ||
               ((win.instance_variable_get(:@sorting) rescue false) && (win.index rescue -1) == i)
      parts.push([PokeAccess::I18n.t(:bag_moving), :brief]) if moving
      (PokeAccess::Info.set_info(:item, itemid, PokeAccess::Verbosity.whole { bag_line(parts, i, count) }) rescue nil)
      bag_line(parts, i, count)
    end

    # A bag row's parts at the bag reading's level, then its place among the pocket's count rows while positions are
    # said: the close row counted, as the bag's slider counts it.
    def self.bag_line(parts, i, count)
      PokeAccess::Verbosity.line(:bag_item, parts.dup.push([PokeAccess::Verbosity.position(i + 1, count), :brief]))
    end

    # The close row, the pocket's last, with its place: the info key says its label, Ctrl+T the row whole.
    def self.bag_close_row(i, count)
      label = PokeAccess::I18n.t(:mn_close_bag)
      PokeAccess::Info.set_info(:text, label, PokeAccess::Verbosity.whole { bag_line([[label, :brief]], i, count) })
      bag_line([[label, :brief]], i, count)
    end

    # A cheap per-frame change witness for a bag row: the entry's id, raw count and bag_row's marks, read off the bag,
    # and whether a move is under way, so a toss or use under a still cursor, or a move cancelled with the cursor on
    # another item, is heard without building the row every frame.
    def self.bag_witness(win, i)
      bag = win.instance_variable_get(:@bag)
      pocket = win.pocket
      filterlist = (win.instance_variable_get(:@filterlist) rescue nil)
      real = (filterlist && filterlist[pocket]) ? filterlist[pocket][i] : i
      entry = (bag.pockets[pocket][real] rescue nil)
      entry = bare_bag_entry(win, bag, entry) unless entry.is_a?(Array)
      return nil unless entry.is_a?(Array)
      si = (win.instance_variable_get(:@sortIndex) rescue nil)
      moving = (si == i) || ((win.instance_variable_get(:@sorting) rescue false) && (win.index rescue -1) == i)
      [entry[0], entry[1], bag_marks(bag, entry[0]), bag_registered_mark?(bag, entry[0]),
       bag_registrable?(bag, entry[0]), moving, si.is_a?(Integer) && si >= 0]
    end

    # A pocket entry kept as a bare id (the Reborn engine) as [id, count]: the window's focused item, as bag_row reads
    # it, and its count from the bag's contents table; nil past the last item.
    def self.bare_bag_entry(win, bag, entry)
      id = win.respond_to?(:item) ? (win.item rescue nil) : nil
      id ||= entry
      id.nil? ? nil : [id, (bag.contents[id] rescue nil)]
    end

    # The ivars a command window's witness takes its rows from: its commands, else a mart's stock, else the item
    # storage's [item, count] slots, which its PCItemStorage keeps in @items.
    WITNESS_IVARS = [:@commands, :@stock, :@bag]

    # A cheap witness that a command window's list changed under a still cursor: [row count, focused row], the row
    # copied, since the item storage changes a slot's count in place (an Array, not a string: 1.8.7's Array#to_s has
    # no separator); nil when the rows are out of reach.
    def self.list_witness(win, i)
      rows = WITNESS_IVARS.map { |iv| win.instance_variable_get(iv) }.find { |r| r.is_a?(Array) }
      rows ||= PokeAccess.ivar(win.instance_variable_get(:@bag), :@items)
      return nil unless rows.is_a?(Array)
      row = rows[i]
      [rows.length, row.is_a?(Array) ? row.dup : row]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether a command window's read keyed on [index, pocket, witness] interrupts: when the cursor left the row and
    # pocket its last read was keyed on, or nothing was said since that read (:cmd_seq, the player's own change or a
    # silent one); a row that changes after a line was said, the message the game shows with it, is queued behind it.
    def self.read_interrupts?(win, key)
      prev = PokeAccess::Cursor.current(win, :cmd_focus)
      return true unless prev.is_a?(Array) && prev[0] == key[0] && prev[1] == key[1]
      PokeAccess::Cursor.current(win, :cmd_seq) == PokeAccess.spoken_seq
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

    # Whether the row says registered: on the gen-6 era only for an item with a hidden count, the only rows its bag
    # paints the icon on; in the others whenever the item is registered.
    def self.bag_registered_mark?(bag, itemid)
      return false if PokeAccess::Engine.gen6? && !bag_hides_qty?(itemid)
      bag_registered?(bag, itemid)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
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

    # Runs an opener whose command list starts on row, holding back through the pulse it opens in any first read of a
    # list on another row: gen 6's storage scene updates its list once on row 0 before moving the cursor to row.
    def self.opening_on(row)
      was = @opening
      @opening = [row, PokeAccess::Frame.pulses]
      yield
    ensure
      @opening = was
    end

    # True for a fresh command list updated on another row than the one its opener is moving it to, in the pulse it
    # opened in: its first read waits for that row, so the move does not cut it.
    def self.before_start_row?(win, idx)
      o = @opening
      return false if o.nil? || o[0] == idx || o[1] != PokeAccess::Frame.pulses
      PokeAccess::Cursor.pending?(win, :cmd_focus)
    end

    # Records the pocket as spoken, so the next row read in it carries no prefix.
    def self.mark_bag_pocket(win)
      win.instance_variable_set(:@access_bag_pocket, win.pocket)
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
      next PokeAccess::Menus.close_row(:pc_cancel) if i >= stock.length
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
      next PokeAccess::Menus.close_row(:pc_cancel) if i >= bag.length
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

# Command-window navigation: first read queued (on its opener's start row), later moves interrupt; skips @ignore_input
# and dedicated windows.
# Keyed on index, pocket and a list witness, so a row that changes under a still cursor is read again: queued when a
# line was said since the window's last read (the message the game shows with the change), else at once; each read
# that speaks keeps the session's spoken count it left (:cmd_seq). The first active window after an options screen
# closes (the load screen's commands) takes its return and says its row again.
PokeAccess::Hooks.after_hook("Window_DrawableCommand", :update) do |win, _r, _a|
  next if (win.instance_variable_get(:@ignore_input) rescue false)
  next if PokeAccess.dedicated?(win)
  idx = win.instance_variable_get(:@index)
  next unless win.active && idx && idx >= 0
  next if PokeAccess::Menus.before_start_row?(win, idx)
  PokeAccess::Options.consume_return(win)
  pkt = (win.respond_to?(:pocket) ? (win.pocket rescue nil) : nil)
  wit = pkt ? (PokeAccess::Menus.bag_witness(win, idx) rescue nil) : PokeAccess::Menus.list_witness(win, idx)
  key = [idx, pkt, wit]
  said = PokeAccess::Cursor.announce(win, :cmd_focus, key, PokeAccess::Menus.read_interrupts?(win, key), false) do
    t = PokeAccess::Menus.focused_text(win)
    PokeAccess::Menus.mark_bag_pocket(win) if pkt && t && !t.to_s.empty?
    t = PokeAccess::Menus.unknown_row(t)
    PokeAccess::Menus.placeholder?(t) ? PokeAccess::I18n.t(:row_empty) : PokeAccess::Menus.checkbox_row(t)
  end
  PokeAccess::Cursor.store(win, :cmd_seq, PokeAccess.spoken_seq) if said
end

# The classic pause menu reruns pbShowCommands on the same window and index after every option, so each entry
# resets the window's dedup and the option is said again.
PokeAccess::Hooks.before_hook("PokemonMenu_Scene", :pbShowCommands, :optional => true) do |scene, _a|
  win = PokeAccess.sprite(scene, "cmdwindow")
  PokeAccess::Cursor.reset(win, :cmd_focus) if win
end

# The PC's command menus open on the row their caller gives (the box chooser on the current box), after its question:
# the list's first read is that row, queued behind the question.
PokeAccess::Hooks.around_hook("PokemonStorageScene", :pbShowCommands, :optional => true) do |_scene, nxt, args|
  PokeAccess::Menus.opening_on(args[2].is_a?(Integer) ? args[2] : 0) { nxt.call }
end

# Back on the Pokedex list from a species entry, the search or its results, the list paints its row again, after its
# header when that changed: the row's dedup is reset, so it is said again, queued behind the header.
PokeAccess::Engine.scene_classes("PokemonPokedexScene", "PokemonPokedex_Scene").each do |cn|
  [:pbDexEntry, :pbDexSearch, :pbCloseSearch].each do |meth|
    PokeAccess::Hooks.after_hook(cn, meth, :optional => true, :hook_container => true) do |scene, _r, _a|
      win = PokeAccess.sprite(scene, "pokedex")
      PokeAccess::Cursor.reset(win, :cmd_focus) if win
    end
  end
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
