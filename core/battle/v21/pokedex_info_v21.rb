module PokeAccess
  # The pokedex entry detail (PokemonPokedexInfo_Scene), read on each drawPage, plain or rewritten by the Modular UI
  # Scenes plugin (named pages in @page_id), and the MUI Data Page's sections and sub-lists.
  module PokedexInfoV21
    # Species per page in the MUI Data Page sub-list (its grid is 12 entries).
    DATA_PAGE_SIZE = 12

    # Plain Essentials' drawPage argument => the page name MUI would have used.
    VANILLA_PAGES = { 1 => :page_info, 2 => :page_area, 3 => :page_forms }

    # The page showing: MUI's @page_id, else the vanilla name for drawPage's number, :page_other for a number an addon
    # added; nil (read as the info page) when neither answers.
    def self.page_id(scene, page)
      id = (scene.instance_variable_get(:@page_id) rescue nil)
      return id if id
      return VANILLA_PAGES[page] if VANILLA_PAGES.has_key?(page)
      page.is_a?(Integer) ? :page_other : nil
    end

    # Resets both dedups (Cursor slots on the scene) so reopening an entry reads it again.
    def self.reset(scene)
      PokeAccess::Cursor.reset(scene, :pdx_page)
      PokeAccess::Cursor.reset(scene, :pdx_data)
    end

    # [species data, display name] for the entry on screen; nil when no name resolves.
    def self.species_and_name(scene)
      species = PokeAccess.ivar(scene, :@species)
      return nil unless species
      form = (scene.instance_variable_get(:@form) rescue 0).to_i
      data = (GameData::Species.get_species_form(species, form) rescue nil)
      data = (GameData::Species.get(species) rescue nil) unless data
      name = data ? (data.name rescue nil) : nil
      name = (PokeAccess::Data.species_name(species) rescue nil) if name.nil? || name.to_s.empty?
      (name.nil? || name.to_s.empty?) ? nil : [data, name]
    rescue StandardError
      nil
    end

    # What the page just painted; the hook takes it on every page, so the capture is never left armed.
    def self.painted=(t); @painted = t; end
    def self.painted; @painted; end

    # The same paint as rows in reading order, for the info page (see painted_info).
    def self.painted_rows=(r); @painted_rows = r; end
    def self.painted_rows; @painted_rows; end

    # The info page as painted (DexEntry.painted_entry), with the types this era's data says the page draws;
    # nil when nothing was painted.
    def self.painted_info(rows, scene, data, owned)
      PokeAccess::DexEntry.painted_entry(rows, owned, shown_types(scene, data, owned))
    end

    # The type names the info page draws: the form's own, none when owned is false (read when it is nil). A copy that
    # draws them for every species overrides this.
    def self.shown_types(scene, data, owned)
      return [] if owned == false
      types = (data.types rescue nil) || [(data.type1 rescue nil), (data.type2 rescue nil)].compact.uniq
      types.map { |t| (GameData::Type.get(t).name rescue t.to_s) }.reject { |n| n.to_s.empty? }
    rescue StandardError
      []
    end

    # The area page as painted (its text, else a composed line), then the places its squares light (area_places).
    def self.area_text(name, painted = nil, places = nil)
      t = painted.to_s.strip.empty? ? PokeAccess::I18n.t(:pdx_zone, :name => name) : painted.to_s
      places && !places.empty? ? "#{t}. #{PokeAccess::I18n.t(:pdx_places, :list => places.join(', '))}" : t
    rescue StandardError
      PokeAccess::I18n.t(:pdx_zone, :name => name)
    end

    # The town map names of the squares the area page lights, from its own pbGetEncounterPoints (else
    # inline_encounter_points), matched to either shape of point list (TownMap's, or the older [region][2]).
    def self.area_places(scene)
      lit = scene.respond_to?(:pbGetEncounterPoints) ? (scene.pbGetEncounterPoints rescue nil) : inline_encounter_points(scene)
      return [] unless lit.is_a?(Array)
      data = PokeAccess.ivar(scene, :@mapdata)
      points = (data.point rescue nil) || (data[PokeAccess.ivar(scene, :@region)][2] rescue nil) || []
      width = area_width(scene)
      squares = []
      lit.each_with_index { |on, idx| squares.push([idx % width, idx / width]) if on }
      PokeAccess::DexEntry.places_at(points, squares)
    rescue StandardError
      []
    end

    # The row width the page numbers its squares by: the region map's own width where the page keeps one (Arcky's
    # Region Map), else the town map's fixed width.
    def self.area_width(scene)
      mw = PokeAccess.ivar(scene, :@mapWidth)
      sq = (PokemonRegionMap_Scene::SQUARE_WIDTH rescue nil)
      return mw / sq if mw.is_a?(Integer) && sq.is_a?(Integer) && sq > 0
      1 + PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT
    end

    # The squares a v19 area page lights, computed as its drawPageArea does inline: the region's maps whose
    # encounters hold the species (the page's own pbFindEncounter), minus switch-hidden points, over their map size.
    def self.inline_encounter_points(scene)
      species = PokeAccess.ivar(scene, :@species)
      region = PokeAccess.ivar(scene, :@region)
      locs = (PokeAccess.ivar(scene, :@mapdata)[region][2] rescue nil) || []
      width = 1 + PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT
      points = []
      GameData::Encounter.each_of_version($PokemonGlobal.encounter_version) do |enc|
        next unless scene.pbFindEncounter(enc.types, species)
        meta = GameData::MapMetadata.try_get(enc.map)
        pos = meta ? meta.town_map_position : nil
        next if !pos || pos[0] != region
        next if locs.any? { |l| l[0] == pos[1] && l[1] == pos[2] && l[7] && !$game_switches[l[7]] }
        size = meta.town_map_size
        if size && size[0] && size[0] > 0
          w = size[0]
          h = (size[1].length * 1.0 / w).ceil
          w.times { |i| h.times { |j| points[pos[1] + i + (pos[2] + j) * width] = true if size[1][i + j * w, 1].to_i > 0 } }
        else
          points[pos[1] + pos[2] * width] = true
        end
      end
      points
    rescue StandardError
      nil
    end

    # The forms page as painted (the species and the label of the form on show), else the form's own name.
    def self.forms_text(name, data, painted)
      return painted unless painted.nil? || painted.to_s.strip.empty?
      fname = (data.form_name rescue nil)
      (fname && !fname.to_s.empty?) ? PokeAccess::I18n.t(:pdx_form, :name => name, :f => fname) : PokeAccess::I18n.t(:pdx_forms, :name => name)
    end

    # The spoken text for the focused pokedex page, or nil.
    # param page the argument drawPage was called with
    def self.page_text(scene, page)
      pair = species_and_name(scene)
      return nil unless pair
      data, name = pair
      owned = owned?(PokeAccess.ivar(scene, :@species))
      case page_id(scene, page)
      when :page_area  then area_text(name, @painted, area_places(scene))
      when :page_forms then forms_text(name, data, @painted)
      when :page_data  then data_text(name, data, owned)
      when :page_other then other_text
      when :page_height then [measure_text(name, (data.height rescue 0), :pdx_height, :h, owned), comparator_text(scene, false)].compact.join(". ")
      when :page_weight then [measure_text(name, (data.weight rescue 0), :pdx_weight, :w, owned), comparator_text(scene, true)].compact.join(". ")
      else                  info_text(scene, name, data, owned)
      end
    rescue StandardError
      nil
    end

    # The info page as painted, else composed: number, category, height, weight and entry (the third field of
    # species_entry when pokedex_entry is empty); only an explicit false owned says "not caught yet".
    def self.info_text(scene, name, data, owned)
      painted = painted_info(@painted_rows, scene, data, owned)
      return painted if painted
      num = (entry_number(scene) rescue nil)
      parts = [[num ? PokeAccess::I18n.t(:pdx_number, :n => num, :name => name) : name, :brief]]
      if owned == false
        parts.push([PokeAccess::I18n.t(:pdx_not_caught), :brief])
      else
        cat = (data.category rescue nil)
        parts.push([PokeAccess::I18n.t(:pdx_category, :cat => cat), :medium]) if cat && !cat.to_s.empty?
        h = (data.height rescue 0).to_i
        w = (data.weight rescue 0).to_i
        parts.push([PokeAccess::I18n.t(:pdx_height, :h => PokeAccess::Pokedex.fmt_dec(h), :n => h / 10.0), :full]) if h > 0
        parts.push([PokeAccess::I18n.t(:pdx_weight, :w => PokeAccess::Pokedex.fmt_dec(w), :n => w / 10.0), :full]) if w > 0
        desc = (data.pokedex_entry rescue nil)
        if desc.nil? || desc.to_s.empty?
          row = (PokeAccess::Data.species_entry(PokeAccess.ivar(scene, :@species)) rescue nil)
          desc = row.is_a?(Array) ? row[2] : row
        end
        parts.push([desc.to_s, :full]) if desc && !desc.to_s.empty?
      end
      PokeAccess::Verbosity.info_line(:dex_page, parts, ". ")
    end

    # Whether the species is owned, by the player's owned? (v19+) or owned array (gen 6); nil when neither answers.
    def self.owned?(species)
      pl = PokeAccess::Engine.player
      return nil unless pl
      return (pl.owned?(species) ? true : false) if (pl.respond_to?(:owned?) rescue false)
      arr = (pl.owned rescue nil)
      return (arr[species] ? true : false) if arr.is_a?(Array)
      nil
    rescue StandardError
      nil
    end

    # A size page of the "Pokedex extras" plugin (:page_height, :page_weight): the species and its measure, unknown
    # when owned is false, as the page draws "???".
    def self.measure_text(name, value, key, var, owned = true)
      return "#{name}. #{PokeAccess::I18n.t(:pdx_unknown_value)}" if owned == false
      v = value.to_i
      return name unless v > 0
      "#{name}. #{PokeAccess::I18n.t(key, var => PokeAccess::Pokedex.fmt_dec(v), :n => v / 10.0)}"
    rescue StandardError
      name
    end

    # A page an addon added, read as it is painted, in reading order; nil when nothing reached the capture
    # (an addon with its own reader takes the paint itself).
    def self.other_text
      rows = PokeAccess::PaintCapture.pair_labels(@painted_rows || [])
      rows.empty? ? nil : PokeAccess::PaintCapture.text(rows, false)
    end

    # The comparator a size page stands the species beside (Royal), with its measure in m or kg; nil without one.
    def self.comparator_text(scene, weight)
      id = PokeAccess.ivar(scene, :@hwComparator)
      return nil if id.nil? || !scene.respond_to?(:pbGetComparisonName)
      nm = (scene.pbGetComparisonName(id) rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      v = weight ? (scene.pbGetComparisonWeight(id) rescue nil) : (scene.pbGetComparisonHeight(id) rescue nil)
      measure = v.nil? ? "" : "#{v} #{weight ? 'kg' : 'm'}"
      PokeAccess::I18n.t(:pdx_compare, :name => nm, :v => measure)
    rescue StandardError
      nil
    end

    # The data page: types, abilities and base stats; unknown when owned is false (the MUI page hides them).
    def self.data_text(name, data, owned = true)
      return PokeAccess::Verbosity.info_line(:dex_page, [[name, :brief], [PokeAccess::I18n.t(:pdx_unknown_value), :brief]], ". ") if owned == false
      parts = [[name, :brief]]
      types = (data.types rescue nil)
      if types.is_a?(Array) && !types.empty?
        parts.push([PokeAccess::I18n.t(:pdx_type, :t => types.map { |t| (GameData::Type.get(t).name rescue t.to_s) }.join(" ")), :medium])
      end
      ab = (data.abilities rescue nil)
      if ab.is_a?(Array) && !ab.empty?
        parts.push([PokeAccess::I18n.t(:pdx_ability, :a => ab.map { |a| (GameData::Ability.get(a).name rescue a.to_s) }.join(", ")), :medium])
      end
      hid = ((data.hidden_abilities rescue nil) || []).reject { |a| (ab || []).include?(a) }
      unless hid.empty?
        parts.push([PokeAccess::I18n.t(:pdx_hidden_ability, :a => hid.map { |a| (GameData::Ability.get(a).name rescue a.to_s) }.join(", ")), :medium])
      end
      bs = (data.base_stats rescue nil)
      if bs
        parts.push([PokeAccess::I18n.t(:pdx_stats, :hp => bs[:HP], :atk => bs[:ATTACK], :def => bs[:DEFENSE],
                    :spa => bs[:SPECIAL_ATTACK], :spd => bs[:SPECIAL_DEFENSE], :spe => bs[:SPEED]), :full])
      end
      PokeAccess::Verbosity.info_line(:dex_page, parts, ". ")
    end

    # The dex number shown for the current entry, or nil if not numbered. Mirrors the entry screen, which
    # subtracts one from the number when the entry's :shift flag is set (regions in DEXES_WITH_OFFSETS).
    def self.entry_number(scene)
      dexlist = PokeAccess.ivar(scene, :@dexlist)
      idx = PokeAccess.ivar(scene, :@index)
      return nil unless dexlist.is_a?(Array) && idx && dexlist[idx]
      n, shift = entry_fields(dexlist[idx], PokeAccess.ivar(scene, :@species))
      return nil unless n && n > 0
      shift ? n - 1 : n
    end

    # A dexlist row as [displayed number, shift flag]: a vanilla Hash, or an Array row ([id, name, 0, 0, position,
    # shift]) that gives way to the species' canonical dex number when it has one.
    def self.entry_fields(entry, species)
      return [(entry[:number] rescue nil), (entry[:shift] rescue false)] if entry.is_a?(Hash)
      return [nil, false] unless entry.is_a?(Array)
      canonical = species_number(species)
      return [canonical, false] if canonical
      [entry[4], (entry[5] ? true : false)]
    end

    def self.species_number(species)
      return nil if species.nil?
      n = (GameData::Species.get(species).id_number rescue nil)
      (n.is_a?(Integer) && n > 0) ? n : nil
    end

    # Speaks the focused page when its text changed since the last read.
    def self.read(scene, page)
      t = page_text(scene, page)
      return if t.nil? || t.empty?
      return unless PokeAccess::Cursor.changed?(scene, :pdx_page, t)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # MUI Data Page section => i18n key, the ten sections the page draws, in its own order.
    SECTIONS = { :encounter => :pdx_sec_encounter, :general => :pdx_sec_general, :stats => :pdx_sec_stats,
                 :family => :pdx_sec_family, :habitat => :pdx_sec_habitat, :shape => :pdx_sec_shape,
                 :egg => :pdx_sec_egg, :item => :pdx_sec_item, :ability => :pdx_sec_ability,
                 :moves => :pdx_sec_moves }

    # What each group of the ability and item sub-list is, by the group number the page keeps them under:
    # abilities are regular (numbered by slot), hidden or special; held items common, uncommon or rare.
    DATA_GROUPS = { :ability => [:pdx_ab_slot, :pdx_ab_hidden, :pdx_ab_special],
                    :item => [:pdx_item_common, :pdx_item_uncommon, :pdx_item_rare] }

    # The focused entry of the ability or item sub-list: name, group mark, position and description; the last entry
    # is the way back.
    def self.data_list_text(scene, list, index, cursor)
      cursor ||= PokeAccess.ivar(scene, :@cursor)
      id = list[index]
      return PokeAccess::I18n.t(:dbk_back) unless id.is_a?(Symbol)
      data = (cursor == :item) ? GameData::Item.get(id) : GameData::Ability.get(id)
      groups = (PokeAccess.ivar(scene, :@data_hash)[cursor] rescue nil)
      num = groups.is_a?(Hash) ? groups.keys.find { |k| (groups[k] || []).include?(id) } : nil
      key = num ? (DATA_GROUPS[cursor] || [])[num] : nil
      mark = key.nil? ? nil : (key == :pdx_ab_slot ? PokeAccess::I18n.t(key, :n => list.index(id) + 1) : PokeAccess::I18n.t(key))
      desc = cursor == :item ? (data.description rescue nil) : ((data.full_description rescue nil) || (data.description rescue nil))
      pos = PokeAccess::Verbosity.position(index + 1, list.length - 1)
      parts = [[data.name, :brief], [mark, :brief], [pos, :brief], [PokeAccess.clean(desc.to_s), :full]]
      PokeAccess::Info.set_info(:text, PokeAccess::Verbosity.full_line([data.name, mark, PokeAccess.clean(desc.to_s)], ". "))
      PokeAccess::Verbosity.line(:dex_page, parts, ". ")
    rescue StandardError
      nil
    end

    # Speaks data sub-navigation text when it changes (its own Cursor slot on the scene).
    def self.data_dedup(scene, text)
      return if text.nil? || text.to_s.empty?
      return unless PokeAccess::Cursor.changed?(scene, :pdx_data, text)
      PokeAccess.speak(text, true)
    end

    # The paragraphs a data-page box paints, captured as [text, x, y] from its drawFormattedTextEx calls while
    # pbDrawDataNotes or pbDrawSpeciesDataList runs.
    @notes = []
    @notes_armed = false

    def self.notes_on; @notes = []; @notes_armed = true; end

    def self.notes_off; @notes_armed = false; end

    # Keeps a paragraph drawFormattedTextEx paints while armed, with where it lands.
    def self.note_text(text, x = 0, y = 0)
      return unless @notes_armed
      return if PokeAccess.clean(text.to_s).empty?
      @notes.push([text.to_s, x.to_i, y.to_i])
    rescue StandardError
      nil
    end

    # The captured paragraphs as one text in reading order (top to bottom, then left to right). A column of names
    # with the column of values beside it (the stats box's three pairs) reads as pairs: "HP 45, Speed 45".
    def self.notes_text
      rows = []
      (@notes || []).each_with_index { |r, i| rows.push(r + [i]) }
      rows = rows.sort_by { |r| [r[2], r[1], r[3]] }
      out = []
      i = 0
      while i < rows.length
        names = note_lines(rows[i][0])
        nxt = rows[i + 1]
        values = nxt ? note_lines(nxt[0]) : []
        if nxt && nxt[2] == rows[i][2] && names.length > 1 && names.length == values.length
          pairs = []
          names.each_with_index { |n, j| pairs.push("#{n} #{values[j]}") }
          out.push(pairs.join(", "))
          i += 2
        else
          out.push(names.join(" "))
          i += 1
        end
      end
      PokeAccess.sentences(out)
    end

    # A paragraph's lines, each cleaned, the blank ones left out.
    def self.note_lines(text)
      text.to_s.split(/\r?\n/).map { |l| PokeAccess.clean(l) }.reject { |l| l.empty? }
    end

    # Reads a data-page section's name and what its box paints: the section passed in, else @cursor (the page's own
    # rule).
    def self.section_read(scene, arg = nil)
      k = SECTIONS[arg || PokeAccess.ivar(scene, :@cursor)]
      label = k ? PokeAccess::I18n.t(k) : nil
      full = PokeAccess.sentences([label, notes_text])
      data_dedup(scene, full.empty? ? nil : full)
    rescue StandardError
      nil
    end

    # The move sub-list: its claimed command window's focus, read as move_line when the focus or list changes, led
    # by the painted title when that is new.
    def self.move_list_read(scene, title)
      win = PokeAccess.dedicate(PokeAccess.sprite(scene, "movecmds"))
      cmds = PokeAccess.ivar(scene, :@moveCommands)
      return unless win && cmds.is_a?(Array)
      idx = cmds.empty? ? nil : win.index
      key = [PokeAccess.ivar(scene, :@moveListIndex), idx]
      PokeAccess::Cursor.announce(scene, :pdx_move, key, true, false) do
        t = PokeAccess.clean(title.to_s)
        head = (!t.empty? && PokeAccess::Cursor.changed?(scene, :pdx_move_list, t)) ? t : nil
        body = cmds.empty? ? PokeAccess::I18n.t(:row_empty) : move_line(scene, idx, cmds.length)
        [head, body].compact.join(". ")
      end
    rescue StandardError
      nil
    end

    # The focused move as the page describes it: move line, learn mark, position and description. A Z-Move or Max
    # Move says no pp (the row shows "??"), nor a category when its power varies (shown as "???").
    def self.move_line(scene, idx, total)
      id = scene.pbCurrentMoveID
      data = GameData::Move.get(id)
      type = (GameData::Type.get(data.type).name rescue nil)
      power = PokeAccess.attr_of(data, :power, :base_damage)
      powered = (data.powerMove? rescue false) ? true : false
      pp = powered ? nil : (data.total_pp rescue nil)
      cat = (powered && power.to_i == 1) ? nil : PokeAccess::MoveInfo.category_word((data.category rescue nil))
      args = [data.name, type, power, (data.accuracy rescue nil), { :cat => cat, :pp => pp, :total_pp => pp }]
      desc = PokeAccess.clean((data.description rescue "").to_s)
      mark = move_learn_mark(scene, idx, id)
      PokeAccess::Info.set_info(:text, PokeAccess::Verbosity.full_line([PokeAccess::MoveInfo.line(*args), mark, desc], ". "))
      parts = [[PokeAccess::MoveInfo.leveled(:learn_move, *args), :brief], [mark, :medium],
               [PokeAccess::Verbosity.position(idx + 1, total), :brief], [desc, :full]]
      PokeAccess::Verbosity.line(:learn_move, parts, ". ")
    rescue StandardError
      nil
    end

    # What the focused row marks about learning the move: its level or evolving (level-up list), the machine the
    # player holds (machine list), or the crystal beside it (Z-Move list).
    def self.move_learn_mark(scene, idx, id)
      case PokeAccess.ivar(scene, :@moveListIndex)
      when 0
        entry = (PokeAccess.ivar(scene, :@moveList)[idx] rescue nil)
        lv = entry.is_a?(Array) ? entry[0] : nil
        return PokeAccess::I18n.t(:pdx_mv_evo) if lv == 0
        return PokeAccess::I18n.t(:dbk_level, :n => lv) if lv.is_a?(Integer) && lv > 1
      when 1
        held = nil
        GameData::Item.each { |it| held = it if (it.is_machine? rescue false) && it.move == id && ($bag.has?(it.id) rescue false) }
        return held.name if held
      when 3
        crystal = (PokeAccess.ivar(scene, :@zcrystals) || []).find { |it| (it.zmove rescue nil) == id }
        return crystal.name if crystal
      end
      nil
    rescue StandardError
      nil
    end

    # Reads the focused cell of a data sub-list, list[page*DATA_PAGE_SIZE + index]: the species, or the way back for
    # the :RETURN the list ends in, which no species resolves; the page on a change of page where there are several;
    # the box beneath (a family member's evolution method, its stats...) from the Pokedex page reading's full level.
    # The info key keeps name and box.
    def self.species_list_read(scene, list, index, page, maxpage = nil)
      return unless list.is_a?(Array)
      sp = list[(page.to_i * DATA_PAGE_SIZE) + index.to_i]
      data = sp ? ((GameData::Species.try_get(sp) rescue nil) || (GameData::Species.get(sp) rescue nil)) : nil
      nm = (data.name rescue nil)
      nm = PokeAccess::I18n.t(:back) if nm.nil? || nm.to_s.empty?
      pages = maxpage.to_i + 1
      turned = pages > 1 && PokeAccess::Cursor.changed?(scene, :pdx_list_page, page.to_i)
      pg = nil
      if turned && PokeAccess::Verbosity.keep?(:positions, :medium)
        pg = PokeAccess::I18n.t(:pdx_list_page, :n => page.to_i + 1, :tot => pages)
      end
      body = notes_text
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([nm, body]))
      data_dedup(scene, PokeAccess::Verbosity.line(:dex_page, [[nm, :brief], [pg, :brief], [body, :full]], ". "))
    rescue StandardError
      nil
    end
  end
end

# Reads the entry page on each drawPage (open, species change, page change), from the paint and the page argument.
PokeAccess::Hooks.before_hook("PokemonPokedexInfo_Scene", :drawPage) do |_s, _a|
  PokeAccess::PaintCapture.arm(:pdx_page)
end
PokeAccess::Hooks.after_hook("PokemonPokedexInfo_Scene", :drawPage) do |scene, _r, args|
  pairs = PokeAccess::PaintCapture.take_pairs(:pdx_page)
  PokeAccess::PokedexInfoV21.painted = PokeAccess::PaintCapture.text(pairs.map { |r| r[0] })
  PokeAccess::PokedexInfoV21.painted_rows = PokeAccess::PaintCapture.laid_out(pairs)
  PokeAccess::PokedexInfoV21.read(scene, args[0])
end

# MUI Data Page sections and species sub-list; :optional, as games without the plugin lack these methods.
PokeAccess::Hooks.around_hook("PokemonPokedexInfo_Scene", :pbDrawDataNotes, :optional => true) do |_s, nxt, _a|
  PokeAccess::PokedexInfoV21.notes_on
  begin; nxt.call; ensure; PokeAccess::PokedexInfoV21.notes_off end
end

PokeAccess::Hooks.around_hook("PokemonPokedexInfo_Scene", :pbDrawSpeciesDataList, :optional => true) do |_s, nxt, _a|
  PokeAccess::PokedexInfoV21.notes_on
  begin; nxt.call; ensure; PokeAccess::PokedexInfoV21.notes_off end
end

PokeAccess::Hooks.wrap_kernel("drawFormattedTextEx", "pdx_data_notes", :before) do |args, _r|
  PokeAccess::PokedexInfoV21.note_text(args[4], args[1], args[2])
end

PokeAccess::Hooks.after_hook("PokemonPokedexInfo_Scene", :pbDrawDataNotes, :optional => true) do |scene, _r, args|
  PokeAccess::PokedexInfoV21.section_read(scene, args[0])
end
PokeAccess::Hooks.after_hook("PokemonPokedexInfo_Scene", :pbDrawSpeciesDataList, :optional => true) do |s, _r, args|
  PokeAccess::PokedexInfoV21.species_list_read(s, args[0], args[1], args[2], args[3])
end
# The ability and item sub-list: redrawn on every cursor move, from inside its own loop.
PokeAccess::Hooks.after_hook("PokemonPokedexInfo_Scene", :pbDrawDataList, :optional => true) do |s, _r, args|
  PokeAccess::PokedexInfoV21.data_dedup(s, PokeAccess::PokedexInfoV21.data_list_text(s, args[0], args[1], args[2]))
end

# The move sub-list on each redraw, with the capture armed for its painted title; entering it forgets both keys.
PokeAccess::Hooks.around_hook("PokemonPokedexInfo_Scene", :pbDrawMoveList, :optional => true) do |s, nxt, _a|
  PokeAccess::PaintCapture.arm(:pdx_moves)
  begin
    nxt.call
  ensure
    rows = PokeAccess::PaintCapture.take(:pdx_moves, :positions) || []
    PokeAccess::PokedexInfoV21.move_list_read(s, rows.first)
  end
end
PokeAccess::Hooks.before_hook("PokemonPokedexInfo_Scene", :pbChooseMove, :optional => true) do |s, _a|
  PokeAccess::Cursor.reset(s, :pdx_move)
  PokeAccess::Cursor.reset(s, :pdx_move_list)
end

# Opening a species list forgets the move key, so coming back says the move again, and the page, so a list that
# opens on its first page of several says it.
PokeAccess::Hooks.before_hook("PokemonPokedexInfo_Scene", :pbChooseSpeciesDataList, :optional => true) do |s, _a|
  PokeAccess::Cursor.reset(s, :pdx_move)
  PokeAccess::Cursor.reset(s, :pdx_list_page)
end

# Reset the dedup when an entry's loop begins so reopening reads it again.
PokeAccess::Hooks.before_hook("PokemonPokedexInfo_Scene", :pbScene) do |s, _a|
  PokeAccess::PokedexInfoV21.reset(s)
end
