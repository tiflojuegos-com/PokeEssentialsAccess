module PokeAccess
  # The pokedex entry detail (PokemonPokedexInfo_Scene). Up/down change the species, left/right the page;
  # both redraw through drawPage, so reading there covers every move. Content is read from GameData by
  # species and form. The main dex list (Window_Pokedex) is read by the core menu hook, so only the detail
  # is added here.
  #
  # Which page is showing is asked TWO ways, because the screen exists in two shapes. Plain Essentials
  # dispatches drawPage(page) on a number; the Modular UI Scenes plugin rewrites the screen into named
  # pages and keeps the current one in @page_id, adding :page_data when the MUI Pokedex Data Page plugin is
  # installed too. Reading only @page_id looked right on the four games that ship MUI and was silently
  # wrong on the three that do not: with no @page_id the reader fell back to the info page every time, so
  # moving left or right produced the SAME text and the dedup swallowed it. Nothing raised; the page
  # simply never spoke.
  module PokedexInfoV21
    # Species per page in the MUI Data Page sub-list (its grid is 12 entries).
    DATA_PAGE_SIZE = 12

    # Plain Essentials' drawPage argument => the page name MUI would have used. Same three pages, same
    # order, checked against the awakening and both Infinite Fusion dumps.
    VANILLA_PAGES = { 1 => :page_info, 2 => :page_area, 3 => :page_forms }

    # The page showing now: MUI's name when the plugin is there, otherwise the number drawPage was called
    # with. nil when neither answers, which the caller reads as the info page.
    def self.page_id(scene, page)
      (scene.instance_variable_get(:@page_id) rescue nil) || VANILLA_PAGES[page]
    end

    # Resets both dedups (Cursor slots on the scene) so reopening an entry reads it again.
    def self.reset(scene)
      PokeAccess::Cursor.reset(scene, :pdx_page)
      PokeAccess::Cursor.reset(scene, :pdx_data)
    end

    # The spoken text for the focused pokedex page, or nil. param page the argument drawPage was called with
    def self.page_text(scene, page)
      species = PokeAccess.ivar(scene, :@species)
      return nil unless species
      form = (scene.instance_variable_get(:@form) rescue 0).to_i
      data = (GameData::Species.get_species_form(species, form) rescue nil)
      data = (GameData::Species.get(species) rescue nil) unless data
      name = data ? (data.name rescue nil) : nil
      name = (PokeAccess::Data.species_name(species) rescue nil) if name.nil? || name.to_s.empty?
      return nil if name.nil? || name.to_s.empty?
      owned = owned?(species)
      case page_id(scene, page)
      when :page_area  then PokeAccess::I18n.t(:pdx_zone, :name => name)
      when :page_forms
        fname = (data.form_name rescue nil)
        (fname && !fname.to_s.empty?) ? PokeAccess::I18n.t(:pdx_form, :name => name, :f => fname) : PokeAccess::I18n.t(:pdx_forms, :name => name)
      when :page_data  then data_text(name, data)
      when :page_height then measure_text(name, (data.height rescue 0), :pdx_height, :h)
      when :page_weight then measure_text(name, (data.weight rescue 0), :pdx_weight, :w)
      else                  info_text(scene, name, data, owned)
      end
    rescue StandardError
      nil
    end

    # The info page: dex number, category, height, weight and the dex entry text. param owned true, false, or
    # nil when the era could not be asked -- see owned?. Only an explicit false claims "not caught yet";
    # unknown falls through to the details, because saying nothing true is better than saying something false.
    # Every data. read is guarded, so a game with no GameData at all still gets its name, number and entry.
    def self.info_text(scene, name, data, owned)
      num = (entry_number(scene) rescue nil)
      parts = [num ? PokeAccess::I18n.t(:pdx_number, :n => num, :name => name) : name]
      if owned == false
        parts.push(PokeAccess::I18n.t(:pdx_not_caught))
      else
        cat = (data.category rescue nil)
        parts.push(PokeAccess::I18n.t(:pdx_category, :cat => cat)) if cat && !cat.to_s.empty?
        h = (data.height rescue 0).to_i
        w = (data.weight rescue 0).to_i
        parts.push(PokeAccess::I18n.t(:pdx_height, :h => PokeAccess::Pokedex.fmt_dec(h))) if h > 0
        parts.push(PokeAccess::I18n.t(:pdx_weight, :w => PokeAccess::Pokedex.fmt_dec(w))) if w > 0
        desc = (data.pokedex_entry rescue nil)
        # species_entry answers [name, category, entry]; only the third field is the prose. Speaking the
        # whole answer joined the name and category back onto the front of it with no separator, and on a
        # game whose species lookup this reader cannot resolve at all, the fallback is the ONLY path, so
        # every single entry read that way.
        if desc.nil? || desc.to_s.empty?
          row = (PokeAccess::Data.species_entry(PokeAccess.ivar(scene, :@species)) rescue nil)
          desc = row.is_a?(Array) ? row[2] : row
        end
        parts.push(desc.to_s) if desc && !desc.to_s.empty?
      end
      parts.join(". ")
    end

    # Whether the species is owned: true, false, or nil when neither era answers. v19+ exposes owned?(species)
    # on the player; gen-6 keeps a plain array indexed by species id and has no such method, so the old
    # `rescue false` turned "cannot tell" into "not caught yet" and would have hidden every entry behind a
    # false claim on a game that has the whole dex. nil is the honest third answer and info_text respects it.
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

    # One of the size-comparison pages the "Pokedex extras" plugin adds (UIHandlers.add(:pokedex,
    # :page_height / :page_weight)). Without a branch of their own they fell through to the info page and
    # produced text IDENTICAL to it -- and the dedup below keys on the text, so moving onto either page said
    # nothing at all. Naming the species alongside the measurement is what makes the page distinguishable.
    def self.measure_text(name, value, key, var)
      v = value.to_i
      return name unless v > 0
      "#{name}. #{PokeAccess::I18n.t(key, var => PokeAccess::Pokedex.fmt_dec(v))}"
    rescue StandardError
      name
    end

    # The data page: types, abilities and base stats.
    def self.data_text(name, data)
      parts = [name]
      types = (data.types rescue nil)
      if types.is_a?(Array) && !types.empty?
        parts.push(PokeAccess::I18n.t(:pdx_type, :t => types.map { |t| (GameData::Type.get(t).name rescue t.to_s) }.join(" ")))
      end
      ab = (data.abilities rescue nil)
      if ab.is_a?(Array) && !ab.empty?
        parts.push(PokeAccess::I18n.t(:pdx_ability, :a => ab.map { |a| (GameData::Ability.get(a).name rescue a.to_s) }.join(", ")))
      end
      bs = (data.base_stats rescue nil)
      if bs
        parts.push(PokeAccess::I18n.t(:pdx_stats, :hp => bs[:HP], :atk => bs[:ATTACK], :def => bs[:DEFENSE],
                   :spa => bs[:SPECIAL_ATTACK], :spd => bs[:SPECIAL_DEFENSE], :spe => bs[:SPEED]))
      end
      parts.join(". ")
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

    # A dexlist row as [displayed number, shift flag]. Vanilla rows are Hashes; some games build plain Arrays
    # instead -- push([id, real_name, 0, 0, position, shift]) -- and asking an Array for a Hash key raises, so
    # the rescue swallowed it and those games never had a number spoken at all.
    #
    # Array rows are not all the same, though, and the difference is not in the row: a game whose species data
    # carries a canonical dex number computes the row's fields and then throws them away in favour of that
    # number, because with thousands of entries the position in a filtered list is not what the screen means
    # by "number". A game without one has nothing else to show and uses the row. So the species is what
    # decides, and it is asked first.
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

    # Speaks the focused page if it changed since the last read (deduped by the page TEXT -- the species
    # can change without the page id changing, so the text is the honest key).
    def self.read(scene, page)
      t = page_text(scene, page)
      return if t.nil? || t.empty?
      return unless PokeAccess::Cursor.changed?(scene, :pdx_page, t)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end
  end
end

module PokeAccess
  # The MUI Data Page sub-navigation: a section cursor (@cursor) and species sub-lists, neither a command
  # window. Sections are read from pbDrawDataNotes; the move sub-list uses a command window the core hook
  # already reads; the species sub-list is read from pbDrawSpeciesDataList.
  module PokedexInfoV21
    SECTIONS = { :general => :pdx_sec_general, :stats => :pdx_sec_stats, :family => :pdx_sec_family,
                 :habitat => :pdx_sec_habitat, :shape => :pdx_sec_shape, :egg => :pdx_sec_egg,
                 :item => :pdx_sec_item, :ability => :pdx_sec_ability, :moves => :pdx_sec_moves }

    # Speaks data-sub-navigation text when it changes (a Cursor slot on the scene, separate from the page
    # reader's).
    def self.data_dedup(scene, text)
      return if text.nil? || text.to_s.empty?
      return unless PokeAccess::Cursor.changed?(scene, :pdx_data, text)
      PokeAccess.speak(text, true)
    end

    # Reads the focused data-page section name (@cursor) as the cursor moves.
    def self.section_read(scene)
      k = SECTIONS[PokeAccess.ivar(scene, :@cursor)]
      data_dedup(scene, k ? PokeAccess::I18n.t(k) : nil)
    rescue StandardError
      nil
    end

    # Reads the focused species in a data sub-list, computed as list[page*DATA_PAGE_SIZE + index].
    def self.species_list_read(scene, list, index, page)
      return unless list.is_a?(Array)
      sp = list[(page.to_i * DATA_PAGE_SIZE) + index.to_i]
      nm = sp ? (GameData::Species.try_get(sp).name rescue (GameData::Species.get(sp).name rescue nil)) : PokeAccess::I18n.t(:back)
      data_dedup(scene, nm)
    rescue StandardError
      nil
    end
  end
end

# The pokedex entry detail, plain or rewritten by MUI. A core/v21 reader so any GameData-era Essentials game
# is covered; each hook binds only where the class/method exists.

# Read the focused entry page on each redraw (drawPage fires on open, species change and page change). The
# argument is what tells the plain screen apart -- it is the only place the page number is available.
PokeAccess::Hooks.after_hook("PokemonPokedexInfo_Scene", :drawPage) do |scene, _r, args|
  PokeAccess::PokedexInfoV21.read(scene, args[0])
end

# Data-page section cursor and species sub-list (MUI Pokedex Data Page plugin). :optional -- games
# without the plugin simply lack these methods.
PokeAccess::Hooks.after_hook("PokemonPokedexInfo_Scene", :pbDrawDataNotes, :optional => true) do |scene, _r, _a|
  PokeAccess::PokedexInfoV21.section_read(scene)
end
PokeAccess::Hooks.after_hook("PokemonPokedexInfo_Scene", :pbDrawSpeciesDataList, :optional => true) do |s, _r, args|
  PokeAccess::PokedexInfoV21.species_list_read(s, args[0], args[1], args[2])
end

# Reset the dedup when an entry's loop begins so reopening reads it again.
PokeAccess::Hooks.before_hook("PokemonPokedexInfo_Scene", :pbScene) do |s, _a|
  PokeAccess::PokedexInfoV21.reset(s)
end
