module PokeAccess
  # Command windows: per-class extractor dispatch over Window_DrawableCommand.
  module Menus
    EXTRACTORS = []

    # Registers an extractor for a window class. yields (window, index) -> the focused option text
    def self.def_extractor(cname, &blk)
      EXTRACTORS.push([cname, blk])
    end

    # Reads the focused entry of a sprite-driven menu (no command window to introspect) on cursor change,
    # deduped per scene instance via Cursor. The entries live in items_ivar, the cursor in @index; the block
    # maps the focused entry to its spoken name. Shared by the ready menu, the pokegear pickers and Neo
    # PauseMenu. param items_ivar the ivar symbol holding the entry array; param dedup_slot the Cursor slot
    # symbol for the dedup state (bare name; a legacy leading @ is tolerated and stripped by Cursor)
    def self.poll_sprite_menu(scene, items_ivar, dedup_slot)
      items = PokeAccess.ivar(scene, items_ivar)
      idx = PokeAccess.ivar(scene, :@index)
      return unless items.is_a?(Array) && idx && idx >= 0 && idx < items.length
      PokeAccess::Cursor.announce(scene, dedup_slot, idx) { yield(items[idx]) }
    rescue StandardError => e
      PokeAccess.log_once("poll_sprite_#{scene.class}", e)
    end

    # The focused option's text for a command window. Of every registered extractor whose class matches the
    # window the MOST DERIVED wins (smallest ancestor distance), mirroring Ruby's own method dispatch, so a
    # profile can specialise a SUBCLASS of a window the core already covers whatever the registration order.
    # An exact tie means the same class, where the first registration wins (min_by keeps the first minimum).
    #
    # An extractor that raises falls back to the generic read rather than going mute: a broken dedicated
    # extractor should cost the EXTRA it added, not the option's name.
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

    # The ivars an Essentials selectable window commonly stores its option list in, tried in order
    # (introspection, never OCR), so list[index] yields the exact string the game holds.
    LIST_IVARS = [:@commands, :@items, :@list, :@data, :@choices, :@names, :@entries, :@stock]

    # A field-menu button label, with the trainer card named when the game labels it with the player's own
    # name. Three of the custom field menus do that -- anil's Diamond/Pearl grid, africanvs's bezier panel
    # and armonia's -- and all three PRINT the name beside the icon, so both halves are spoken: the name
    # because it is what the screen shows, the function because a player's own name sitting between
    # "Mochila" and "Guardar" says nothing about what the button opens.
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

    # Resolves one list entry to spoken text conservatively: a String/Symbol directly, else its .name or
    # .text when a non-empty String; anything else returns nil, so the reader stays silent over garbage.
    def self.entry_text(e)
      return nil if e.nil?
      return e if e.is_a?(String)
      return e.to_s if e.is_a?(Symbol)
      nm = (e.name rescue nil); return nm if nm.is_a?(String) && !nm.empty?
      tx = (e.text rescue nil); return tx if tx.is_a?(String) && !tx.empty?
      nil
    end

    #base extractors (shared across Essentials fangames)

    def_extractor("Window_PokemonOption") do |win, i|
      opts = win.instance_variable_get(:@options)
      next PokeAccess::I18n.t(:sm_exit) if i >= opts.length
      o = opts[i]
      "#{o.name}: #{PokeAccess::Options.value_of(o, win[i])}"
    end

    # Bag focused row WITHOUT the pocket prefix: "Pocion: 5" / "Cerrar mochila". Pure on purpose -- it is
    # polled every frame by per-frame readers and by the diagnostic, so it must never move reader state.
    # In choose-item mode the window filters the pocket via @filterlist and exposes the mapped id through
    # #item; the visual index is honoured through it (and the matching real index for the quantity) so a
    # filtered list never announces a neighbouring item, and the trailing "Close bag" row is read as such.
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
      (PokeAccess::Info.set_info(:item, itemid) rescue nil)
      (PokeAccess::Info.note_item_desc(itemid, ad.getDescription(itemid)) rescue nil) if ad && ad.respond_to?(:getDescription)
      name = (ad.getDisplayName(itemid) rescue nil) if ad
      name = (PokeAccess::Data.item_name(itemid) || itemid.to_s) if name.nil? || name.to_s.empty?
      name = bag_decorated_name(ad, itemid, name)
      qty = (pocket_entries[real][1] rescue nil)
      qty = nil if bag_hides_qty?(itemid)
      row = qty ? "#{name}: #{qty}" : "#{name}"
      bag_marks(bag, itemid).each { |k| row += ", #{PokeAccess::I18n.t(k)}" }
      row += ", #{PokeAccess::I18n.t(:bag_registered)}" if bag_registered?(bag, itemid)
      moving = ((win.instance_variable_get(:@sortIndex) rescue -1) == i) ||
               ((win.instance_variable_get(:@sorting) rescue false) && (win.index rescue -1) == i)
      moving ? "#{row}, #{PokeAccess::I18n.t(:bag_moving)}" : row
    end

    # The cheap per-frame change witness for a bag row: the focused entry's id and raw count plus the marks
    # bag_row appends (favourite, registered, being moved), read straight off the bag. Toss/Use rewrite the
    # row without moving the index, so the index alone misses them; keying on the formatted row itself would
    # build it 60 times a second (with bag_row's Info side effects) for a cursor that sits still.
    def self.bag_witness(win, i)
      bag = win.instance_variable_get(:@bag)
      pocket = win.pocket
      filterlist = (win.instance_variable_get(:@filterlist) rescue nil)
      real = (filterlist && filterlist[pocket]) ? filterlist[pocket][i] : i
      entry = (bag.pockets[pocket][real] rescue nil)
      return nil unless entry.is_a?(Array)
      moving = ((win.instance_variable_get(:@sortIndex) rescue -1) == i) ||
               ((win.instance_variable_get(:@sorting) rescue false) && (win.index rescue -1) == i)
      [entry[0], entry[1], bag_marks(bag, entry[0]), bag_registered?(bag, entry[0]), moving]
    end

    # Row decorators registered by a plugin whose bag adds what the vanilla row does not have (a machine's
    # move name, a favourite mark): each answers name(adapter, itemid) with a replacement name or nil and
    # marks(bag, itemid) with the i18n keys to append. A protocol rather than a lambda because the witness
    # above has to see the same marks the row shows. Core itself probes nothing fork-specific here.
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

    # True when the screen hides the quantity for this item (key items, machines): twelve of the
    # thirteen copies paint those without a count, and the item-storage extractor already follows the
    # same rule -- the criterion was split inside the mod until this call.
    def self.bag_hides_qty?(itemid)
      return true if (pbIsImportantItem?(itemid) rescue false)
      (::GameData::Item.get(itemid).is_important? rescue false)
    end

    # Whether the bag has this item registered, across the three shapes in the wild: the modern
    # predicate, the gen-6 single slot, and the multi-register arrays two games patch in.
    def self.bag_registered?(bag, itemid)
      r = (bag.registered?(itemid) rescue nil)
      return (r ? true : false) unless r.nil?
      ri = (bag.registeredItem rescue nil)
      ri = (bag.instance_variable_get(:@registeredItem) rescue nil) if ri.nil?
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

    # Bag: the pocket name is prefixed only when the pocket changes, so switching category and the
    # focused item are read in a single utterance.
    def_extractor("Window_PokemonBag") do |win, i|
      "#{bag_prefix(win)}#{bag_row(win, i)}"
    end

    # The region list of the multi-dex Pokedex menu: each row paints VISTOS and PROPIOS counters beside
    # the name, and choosing a region IS a comparison of those numbers.
    def_extractor("Window_DexesList") do |win, i|
      base = generic_focus(win, i).to_s
      seen = (win.instance_variable_get(:@seen) rescue nil)
      owned = (win.instance_variable_get(:@owned) rescue nil)
      pair = (seen.is_a?(Array) && i < seen.length) ? [seen[i], (owned.is_a?(Array) ? owned[i] : 0)] : nil
      c2 = (win.instance_variable_get(:@commands2) rescue nil)
      pair = [c2[i][0], c2[i][1]] if pair.nil? && c2.is_a?(Array) && c2[i].is_a?(Array)
      pair ? PokeAccess::I18n.t(:dex_region_counts, :name => base, :seen => pair[0], :owned => pair[1]) : base
    end

    def_extractor("Window_PokemonMart") do |win, i|
      stock = win.instance_variable_get(:@stock)
      next PokeAccess::I18n.t(:pc_cancel) if i >= stock.length
      PokeAccess::Info.set_info(:item, stock[i])
      ad = win.instance_variable_get(:@adapter)
      price = (ad.getDisplayPrice(stock[i]) rescue nil)
      price ? "#{ad.getDisplayName(stock[i])}, #{price}" : ad.getDisplayName(stock[i]).to_s
    end

    def_extractor("Window_PokemonItemStorage") do |win, i|
      bag = win.instance_variable_get(:@bag)
      next PokeAccess::I18n.t(:pc_cancel) if i >= bag.length
      PokeAccess::Info.set_info(:item, bag[i][0])
      nm = win.instance_variable_get(:@adapter).getDisplayName(bag[i][0])
      hide_qty = (defined?(pbIsImportantItem?) && pbIsImportantItem?(bag[i][0]) rescue false)
      hide_qty ? nm.to_s : "#{nm}: #{bag[i][1]}"
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

    # Dual-shape: gen-6 entries are arrays ([species, name, .., displayname]) and the modern Window_Pokedex
    # stores hashes ({:species, :name}), so one extractor covers both. The seen/owned state goes through
    # Util.dex_seen?/dex_owned?, which probe the predicate API before the gen-6 arrays, since a v18-era game
    # can keep the array row shape and expose only seen?/owned?. A row already carrying its name (c[1]) is
    # spoken as-is, which also resolves a custom composite species name without rebuilding the species.
    def_extractor("Window_Pokedex") do |win, i|
      c = win.instance_variable_get(:@commands)[i]
      cap = PokeAccess::I18n.t(:dex_caught)
      sn = PokeAccess::I18n.t(:dex_seen)
      unk = PokeAccess::I18n.t(:dex_unknown)
      if c.is_a?(Hash)
        sp = c[:species]
        num = c[:number].to_i
        num -= 1 if c[:shift]
        if PokeAccess::Util.dex_seen?(sp)
          nm = c[:name]
          nm = (PokeAccess::Data.species_name(sp) || "?") if nm.nil? || nm.to_s.empty?
          "#{num}, #{nm}, #{PokeAccess::Util.dex_owned?(sp) ? cap : sn}"
        else
          "#{num}, #{unk}"
        end
      elsif c
        if PokeAccess::Util.dex_seen?(c[0])
          "#{c[4]}, #{c[1]}, #{PokeAccess::Util.dex_owned?(c[0]) ? cap : sn}"
        else
          "#{c[4]}, #{unk}"
        end
      else
        ""
      end
    end
  end
end

# Command-window navigation (the game changes @index directly). First read queued, later moves interrupt
# (Cursor's first_interrupt); battle menus (@ignore_input) have dedicated readers. A bag window keys on
# [index, pocket, witness]: Toss/Use rewrite the focused row without moving the index. @access_dedicated is
# the mod's own claim flag; gen-6 gates navigation on @ignore_input, so setting that would freeze the
# cursor.
PokeAccess::Hooks.after_hook("Window_DrawableCommand", :update) do |win, _r, _a|
  next if (win.instance_variable_get(:@ignore_input) rescue false)
  next if PokeAccess.dedicated?(win)
  idx = win.instance_variable_get(:@index)
  next unless win.active && idx && idx >= 0
  pkt = (win.respond_to?(:pocket) ? (win.pocket rescue nil) : nil)
  wit = pkt ? (PokeAccess::Menus.bag_witness(win, idx) rescue nil) : nil
  PokeAccess::Cursor.announce(win, :cmd_focus, [idx, pkt, wit], true, false) do
    t = PokeAccess::Menus.focused_text(win)
    PokeAccess::Menus.mark_bag_pocket(win) if pkt && t && !t.to_s.empty?
    t
  end
end

# Generic auto-detection (Config.auto_detect, on by default): reads navigable SpriteWindow_Selectable
# windows with no dedicated reader (and not Window_DrawableCommand, covered above), by introspecting the
# index + option list (the real strings, so it cannot misread like OCR). SpriteWindow_Selectable is the
# highest class in the shared chain that owns the real navigation update, identical across gen-6/v21/v22, so
# the net actually binds; the is_a?(Window_DrawableCommand) guard below keeps it from double-reading the
# entries the sibling hook (Window_DrawableCommand#update) already announces. Guarded and deduped by index/pocket.
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
