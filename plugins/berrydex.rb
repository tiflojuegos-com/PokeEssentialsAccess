# BerryDex ("TDW Berry Core and Dex"): the list (Window_Berrydex, [berry_id, name, indexNumber] rows), the detail screen
# (BerrydexInfo_Scene), whose optional pages are asked by respond_to?, and the selector of several berries that
# compost, planters and cooking open (ChooseBerryMultiple_Scene).
module PokeAccess
  module BerryDex
    # The section names this copy of the plugin can show, in page order.
    def self.sections(scene)
      names = [PokeAccess::I18n.t(:bdx_page_info), PokeAccess::I18n.t(:bdx_page_plant)]
      names.push(PokeAccess::I18n.t(:bdx_page_battle)) if shows?(scene, :pbShowBattlePage?)
      names.push(PokeAccess::I18n.t(:bdx_page_mut)) if shows?(scene, :pbShowMutationsPage?)
      names
    end

    # Whether this copy shows an optional page (a property of the install, not of the berry).
    def self.shows?(scene, meth)
      return false unless scene.respond_to?(meth, true)
      (scene.send(meth) ? true : false) rescue false
    end

    # The focused berry in the LIST: its dex number and name, or that it is not registered yet.
    def self.entry_text(win, i)
      cmds = win.instance_variable_get(:@commands)
      return nil unless cmds.is_a?(Array) && cmds[i]
      id = cmds[i][0]
      num = cmds[i][2].to_i
      return PokeAccess::I18n.t(:bdx_entry, :num => num, :name => cmds[i][1]) if (pbBerryRegistered?(id) rescue false)
      PokeAccess::I18n.t(:bdx_unknown, :num => num)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The page's painted rows as its lines, top to bottom, each label joined to the value painted on its row
    # ("Size 2.0 cm"); rows painted without a position follow in paint order.
    # param pairs the page's capture, as take_pairs gives it (text, source, x, y)
    def self.page_lines(pairs)
      loose = (pairs || []).reject { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) }.map { |r| r[0] }
      PokeAccess::PaintCapture.lines(pairs) + loose
    end

    # The detail screen on a page change: the berry, the section and the lines the page painted; the first page
    # adds the dominant flavour, and falls back to the data's description when nothing was painted.
    # param pairs the page's capture, as take_pairs gives it
    def self.page(scene, page, pairs)
      berry = PokeAccess.ivar(scene, :@berry)
      return if berry.nil?
      sub = PokeAccess.ivar(scene, :@subpage)
      return unless PokeAccess::Cursor.changed?(scene, :bdx_page, [berry, page, sub])
      name = ((GameData::Item.get(berry).name rescue nil) || berry.to_s)
      section = sections(scene)[page.to_i - 1] || page
      parts = [name, PokeAccess::I18n.t(:bdx_section, :name => section)]
      rows = pairs.is_a?(Array) ? page_lines(pairs) : []
      body = rows.uniq.reject { |r| r.to_s.strip == name.to_s }
      if body.empty? && page == 1
        d = (GameData::BerryData.try_get(berry).description rescue nil)
        d = (GameData::Item.get(berry).description rescue nil) if d.nil? || d.to_s.empty?
        body = [d].compact
      end
      flav = flavor_line(berry)
      body.push(flav) if flav && page.to_i == 1
      parts.concat(body)
      PokeAccess.speak_clean(PokeAccess.sentences(parts), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The five flavours by the names of the page's circled sprites, and the words the mod says for them.
    FLAVORS = { :spicy => :bdx_fl_spicy, :dry => :bdx_fl_dry, :sweet => :bdx_fl_sweet, :bitter => :bdx_fl_bitter,
                :sour => :bdx_fl_sour }

    # The lang key of a flavour as the berry data keys it (:spicy, or "Spicy" in the plugin's own data), or nil.
    def self.flavor_key(k)
      FLAVORS[k.to_s.downcase.to_sym]
    end

    # A flavour's spoken name, or the data's own key for one the table lacks.
    def self.flavor_name(k)
      key = flavor_key(k)
      key ? PokeAccess::I18n.t(key) : k.to_s
    end

    # The dominant flavour(s), the ones the page circles; it paints no value, so none is said.
    def self.flavor_line(berry)
      fl = (GameData::BerryData.try_get(berry).flavor rescue nil)
      return nil unless fl.is_a?(Hash) && !fl.empty?
      max = fl.values.map { |v| v.to_i }.max
      return nil if max.nil? || max <= 0
      tops = fl.select { |_k, v| v.to_i == max }.map { |k, _v| flavor_name(k) }
      PokeAccess::I18n.t(:bdx_flavor, :f => tops.join(", "))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The list screen's title and counters (registered, planted), painted on every refresh: queued in reading
    # order when they change, minus the focused berry's name, which the row says.
    def self.list_header(scene, pairs)
      rows = PokeAccess::PaintCapture.laid_out(pairs || [])
      berry = (PokeAccess.sprite(scene, "berrydex").berry rescue nil)
      focus = berry ? (GameData::Item.get(berry).name rescue nil) : nil
      rows = rows.reject { |r| r.to_s.strip == focus.to_s } if focus
      t = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.pair_labels(rows), false)
      return if t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(scene, :bdx_header, t)
      PokeAccess.speak(t, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The label column of the selector of several berries as it paints it for its @label mode, or nil; the flavour
    # through the game's _INTL, as a translated build paints it.
    def self.multi_label(item, label)
      data = (GameData::BerryData.get(item) rescue nil)
      return nil unless data
      case label
      when :Flavor
        f = (data.flavor.max_by { |_k, v| v } rescue nil)
        f ? (_INTL(f[0].to_s) rescue f[0].to_s).to_s : nil
      when :Firm, :Firmness then (data.firmness.to_s rescue nil)
      when :Size then (data.size ? "#{data.size} cm" : nil rescue nil)
      when :Type, :TypeText, :TypeIcon then (GameData::Type.get(pbBerryGetNaturalGift(item)[0]).name rescue nil)
      else (GameData::BerryColor.get(data.color).name rescue nil)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The selector's focused row (Window_ChooseBerryMultiple, entries in @bag.pockets[5] through @filterlist): the berry
    # and how many are left, and from medium the label column for its mode and how many are chosen; past the list, close.
    def self.multi_row(win, i)
      fl = win.instance_variable_get(:@filterlist)
      return PokeAccess::Menus.close_row(:mn_close_bag) if !fl.is_a?(Array) || i >= fl.length
      bag = win.instance_variable_get(:@bag)
      entry = (bag.pockets[5][fl[i]] rescue nil)
      return nil unless entry
      item = entry[0]
      nm = (GameData::Item.get(item).name rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      scene = win.instance_variable_get(:@scene)
      qty = entry[1]
      qty -= (scene.selectedBerries.count(GameData::Item.get(item)) rescue 0) if qty
      parts = [[qty ? "#{nm}, #{qty}" : nm, :brief]]
      lbl = multi_label(item, (scene.instance_variable_get(:@label) rescue nil))
      parts.push([lbl, :medium]) if lbl && !lbl.empty?
      chosen = (scene.selectedBerries.length rescue nil)
      max = (scene.instance_variable_get(:@count) rescue nil)
      parts.push([PokeAccess::I18n.t(:bdx_chosen, :n => chosen, :tot => max), :medium]) if chosen && max
      PokeAccess::Info.set_info(:item, item, PokeAccess::Verbosity.full_line(parts))
      PokeAccess::Verbosity.line(:bag_item, parts)
    end

    # A berry chosen, which the screen shows as an icon in a circle and leaves the list's row as it was: how many are
    # chosen so far and which, queued; the opening's empty circles are for the row to say.
    def self.multi_chosen(scene)
      names = scene.selectedBerries.map { |b| b.name }
      return unless PokeAccess::Cursor.changed?(scene, :bdx_multi_chosen, names.length)
      return if names.empty?
      t = PokeAccess::I18n.t(:bdx_chosen, :n => names.length, :tot => PokeAccess.ivar(scene, :@count))
      PokeAccess.speak(PokeAccess.sentences([t, names.join(", ")]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_Berrydex") { |win, i| PokeAccess::BerryDex.entry_text(win, i) }
PokeAccess::Menus.def_extractor("Window_ChooseBerryMultiple") { |win, i| PokeAccess::BerryDex.multi_row(win, i) }

PokeAccess::Hooks.after_hook("ChooseBerryMultiple_Scene", :drawSelectedBerries, :optional => true) do |scene, _r, _a|
  PokeAccess::BerryDex.multi_chosen(scene)
end

PokeAccess::Hooks.around_hook("BerrydexInfo_Scene", :drawPage, :optional => true) do |scene, nxt, args|
  PokeAccess::PaintCapture.arm(:bdx_page)
  begin
    nxt.call
  ensure
    PokeAccess::BerryDex.page(scene, (args[0] rescue PokeAccess.ivar(scene, :@page)),
                              PokeAccess::PaintCapture.take_pairs(:bdx_page))
  end
end

PokeAccess::Hooks.around_hook("PokemonBerrydex_Scene", :pbRefresh, :optional => true) do |scene, nxt, _a|
  PokeAccess::PaintCapture.arm(:bdx_header)
  begin
    nxt.call
  ensure
    PokeAccess::BerryDex.list_header(scene, PokeAccess::PaintCapture.take_pairs(:bdx_header))
  end
end
