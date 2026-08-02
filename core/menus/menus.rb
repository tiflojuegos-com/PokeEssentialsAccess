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

    # The focused option's text for a command window. Of every registered extractor whose class matches
    # the window, the MOST DERIVED wins (smallest ancestor distance) -- mirroring Ruby's own method
    # dispatch, so a profile can specialise a SUBCLASS of a window the core already covers and its
    # extractor wins regardless of registration order (first-match-by-registration let the core capture
    # the subclass forever). An exact tie in distance means the same class, where the FIRST registration
    # keeps winning, preserving the old behaviour for duplicates (min_by keeps the first minimum).
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
        # Fall back to the generic read instead of going mute: a broken dedicated extractor should cost the
        # EXTRA it added, not the option's name, which generic_focus takes from the window's own list.
        generic_focus(win, i)
      end
    end

    # The ivars an Essentials selectable window commonly stores its option list in, tried in order
    # (introspection, never OCR), so list[index] yields the exact string the game holds.
    LIST_IVARS = [:@commands, :@items, :@list, :@data, :@choices, :@names, :@entries, :@stock]

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

    # Bag: the pocket name is prefixed only when the pocket changes, so switching category and the
    # focused item are read in a single utterance. In choose-item mode the window filters the pocket via
    # @filterlist and exposes the mapped id through #item; the visual index is honoured through it (and the
    # matching real index for the quantity) so a filtered list never announces a neighbouring item, and the
    # trailing "Close bag" row is read as such, not as an item.
    def_extractor("Window_PokemonBag") do |win, i|
      bag = win.instance_variable_get(:@bag)
      pocket = win.pocket
      prefix = ""
      if pocket != PokeAccess.ivar(win, :@access_bag_pocket)
        win.instance_variable_set(:@access_bag_pocket, pocket)
        pn = (PokemonBag.pocketNames[pocket] rescue nil)
        pn = (PokemonBag.pocket_names[pocket - 1] rescue nil) if pn.nil? || pn.to_s.empty?
        prefix = "#{pn}. " if pn && !pn.to_s.empty?
      end
      pocket_entries = (bag.pockets[pocket] rescue nil)
      filterlist = (win.instance_variable_get(:@filterlist) rescue nil)
      visible = (filterlist && filterlist[pocket]) ? filterlist[pocket] : pocket_entries
      count = (win.respond_to?(:itemCount) ? (win.itemCount rescue nil) : nil)
      count = visible.length + 1 if count.nil? && visible
      next "#{prefix}#{PokeAccess::I18n.t(:mn_close_bag)}" if count.nil? || i >= count - 1
      real = (filterlist && filterlist[pocket]) ? filterlist[pocket][i] : i
      itemid = (win.item rescue nil) if win.respond_to?(:item)
      itemid = (pocket_entries[real][0] rescue nil) if itemid.nil? && real
      next "#{prefix}#{PokeAccess::I18n.t(:mn_close_bag)}" if itemid.nil?
      ad = win.instance_variable_get(:@adapter)
      (PokeAccess::Info.set_info(:item, itemid) rescue nil)
      (PokeAccess::Info.note_item_desc(itemid, ad.getDescription(itemid)) rescue nil) if ad && ad.respond_to?(:getDescription)
      name = (ad.getDisplayName(itemid) rescue nil) if ad
      name = (PokeAccess::Data.item_name(itemid) || itemid.to_s) if name.nil? || name.to_s.empty?
      qty = (pocket_entries[real][1] rescue nil)
      qty ? "#{prefix}#{name}: #{qty}" : "#{prefix}#{name}"
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
      "#{win.instance_variable_get(:@adapter).getDisplayName(bag[i][0])}: #{bag[i][1]}"
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

    # In-game control remap: read each action with its assigned key, plus the controls.
    def_extractor("Window_PokemonControls") do |win, i|
      controls = win.instance_variable_get(:@controls) || []
      n = controls.length
      if i == n + 1
        PokeAccess::I18n.t(:sm_exit)
      elsif i == n
        PokeAccess::I18n.t(:mn_default_keys)
      elsif controls[i]
        "#{controls[i].controlAction}: #{controls[i].keyName}"
      end
    end

    # Dual-shape: gen-6 entries are arrays ([species, name, .., displayname]); the modern Window_Pokedex
    # stores hashes ({:species, :name}). One extractor covers both. The seen/owned state goes through
    # Util.dex_seen?/dex_owned?, which probe the predicate API before the gen-6 arrays -- some v18-era
    # games keep the array row shape but expose only seen?/owned?, so reading the arrays directly raised
    # and left the whole dex list silent. A row already carrying its name (c[1]) is spoken as-is, which
    # is also what resolves a custom composite species name without rebuilding the species.
    def_extractor("Window_Pokedex") do |win, i|
      c = win.instance_variable_get(:@commands)[i]
      cap = PokeAccess::I18n.t(:dex_caught)
      sn = PokeAccess::I18n.t(:dex_seen)
      unk = PokeAccess::I18n.t(:dex_unknown)
      if c.is_a?(Hash)
        sp = c[:species]
        nm = c[:name]
        nm = (PokeAccess::Data.species_name(sp) || "?") if nm.nil? || nm.to_s.empty?
        if PokeAccess::Util.dex_seen?(sp)
          "#{nm}, #{PokeAccess::Util.dex_owned?(sp) ? cap : sn}"
        else
          "#{nm}, #{unk}"
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

# Command-window navigation (the game changes @index directly). The first read is queued so it does not
# cut a question/title spoken just before; later navigation interrupts (Cursor's first_interrupt). Battle
# menus (@ignore_input) are skipped (they have dedicated readers); bag windows re-read on a pocket change
# too, so the dedup key is [index, pocket]. @access_dedicated is the mod's own "a dedicated reader owns this
# window" flag: on gen-6, SpriteWindow_Selectable#update itself gates navigation on @ignore_input (050_Sprite-
# Window), so a reader must NOT set that to mute us or it freezes the cursor -- it sets @access_dedicated instead.
PokeAccess::Hooks.after_hook("Window_DrawableCommand", :update) do |win, _r, _a|
  next if (win.instance_variable_get(:@ignore_input) rescue false)
  next if (win.instance_variable_get(:@access_dedicated) rescue false)
  idx = win.instance_variable_get(:@index)
  next unless win.active && idx && idx >= 0
  pkt = (win.respond_to?(:pocket) ? (win.pocket rescue nil) : nil)
  PokeAccess::Cursor.announce(win, :cmd_focus, [idx, pkt], true, false) { PokeAccess::Menus.focused_text(win) }
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
  next if (win.instance_variable_get(:@access_dedicated) rescue false)
  idx = (win.respond_to?(:index) ? (win.index rescue nil) : win.instance_variable_get(:@index))
  next unless (win.active rescue false) && idx && idx >= 0
  pkt = (win.respond_to?(:pocket) ? (win.pocket rescue nil) : nil)
  PokeAccess::Cursor.announce(win, :auto_focus, [idx, pkt], true, false) { PokeAccess::Menus.generic_focus(win, idx) }
end
