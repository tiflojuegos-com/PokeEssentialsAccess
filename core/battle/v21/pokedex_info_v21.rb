module PokeAccess
  # The pokedex entry detail (PokemonPokedexInfo_Scene). Up/down change the species, left/right the page,
  # and both redraw through drawPage, so reading there covers every move. Content comes from GameData by
  # species and form; the main dex list (Window_Pokedex) is read by the core menu hook.
  #
  # Which page is showing is asked TWO ways, because the screen exists in two shapes: plain Essentials
  # dispatches drawPage(page) on a number, while the Modular UI Scenes plugin rewrites it into named pages
  # kept in @page_id (plus :page_data when the MUI Pokedex Data Page plugin is installed). A game without
  # MUI has no @page_id, so reading only that one falls back to the info page for every page.
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

    # The species data and display name for the entry on screen.
    # param scene the pokedex info scene
    # return [data, name], or nil when neither the form nor the species resolves
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

    # The spoken text for the focused pokedex page, or nil.
    # param page the argument drawPage was called with
    def self.page_text(scene, page)
      pair = species_and_name(scene)
      return nil unless pair
      data, name = pair
      owned = owned?(PokeAccess.ivar(scene, :@species))
      case page_id(scene, page)
      when :page_area  then PokeAccess::I18n.t(:pdx_zone, :name => name)
      when :page_forms
        fname = (data.form_name rescue nil)
        (fname && !fname.to_s.empty?) ? PokeAccess::I18n.t(:pdx_form, :name => name, :f => fname) : PokeAccess::I18n.t(:pdx_forms, :name => name)
      when :page_data  then data_text(name, data, owned)
      when :page_height then measure_text(name, (data.height rescue 0), :pdx_height, :h, owned)
      when :page_weight then measure_text(name, (data.weight rescue 0), :pdx_weight, :w, owned)
      else                  info_text(scene, name, data, owned)
      end
    rescue StandardError
      nil
    end

    # The info page: dex number, category, height, weight and the dex entry text. Every data. read is
    # guarded, so a game with no GameData at all still gets its name, number and entry. When pokedex_entry
    # is empty the fallback takes only the THIRD field of species_entry, which answers [name, category,
    # entry] and would otherwise glue the name and the category onto the front of the prose.
    # param owned true, false, or nil when the era could not be asked (see owned?); only an explicit false
    #   claims "not caught yet", since saying nothing true beats saying something false
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
        if desc.nil? || desc.to_s.empty?
          row = (PokeAccess::Data.species_entry(PokeAccess.ivar(scene, :@species)) rescue nil)
          desc = row.is_a?(Array) ? row[2] : row
        end
        parts.push(desc.to_s) if desc && !desc.to_s.empty?
      end
      parts.join(". ")
    end

    # Whether the species is owned: true, false, or nil when neither era answers. v19+ exposes owned?(species)
    # on the player; gen-6 keeps a plain array indexed by species id and has no such method, so a `rescue
    # false` would turn "cannot tell" into "not caught yet" and hide every entry behind a false claim on a
    # game that has the whole dex. nil is the third answer, and info_text respects it.
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
    # :page_height / :page_weight)). The species is named alongside the measurement, since the dedup below
    # keys on the text and the info page already speaks the same figures.
    #
    # A species the player has not caught reads as unknown, because that is what the page draws: the plugin
    # writes "??? m" and "??? kg" and substitutes the figure only "if $player.owned?(@species)". Speaking
    # the real height and weight of a Pokemon the screen hides is the same leak as naming a silhouette.
    def self.measure_text(name, value, key, var, owned = true)
      return "#{name}. #{PokeAccess::I18n.t(:pdx_unknown_value)}" if owned == false
      v = value.to_i
      return name unless v > 0
      "#{name}. #{PokeAccess::I18n.t(key, var => PokeAccess::Pokedex.fmt_dec(v))}"
    rescue StandardError
      name
    end

    # The data page: types, abilities and base stats. Withheld for a species the player has not caught,
    # because the MUI page draws the types, the egg groups and the base stats only "if owned" and the
    # abilities live behind a sub-menu gated the same way.
    # param owned nil where the era could not be asked; only an explicit false withholds
    def self.data_text(name, data, owned = true)
      return "#{name}. #{PokeAccess::I18n.t(:pdx_unknown_value)}" if owned == false
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

    # A dexlist row as [displayed number, shift flag]. Vanilla rows are Hashes; some games build plain
    # Arrays instead -- push([id, real_name, 0, 0, position, shift]) -- and asking an Array for a Hash key
    # raises.
    #
    # Which Array field to use is decided by the SPECIES, not by the row: a game whose species data carries
    # a canonical dex number shows that, since with thousands of entries a position in a filtered list is
    # not what the screen means by "number". A game without one has only the row to show.
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

  # The MUI Data Page sub-navigation: a section cursor (@cursor) and species sub-lists, neither a command
  # window. Sections are read from pbDrawDataNotes; the move sub-list uses a command window the core hook
  # already reads; the species sub-list is read from pbDrawSpeciesDataList.
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

    # El parrafo que la seccion pinta, capturado de su propia llamada de dibujo. La pagina compone el texto
    # por seccion y lo suelta de una vez con drawFormattedTextEx, asi que rehacerlo aqui seria reimplementar
    # el plugin: se lee lo que PINTO. Sin esto solo se oia la etiqueta -- "Estadisticas" -- y nunca las
    # cifras, que son el motivo de abrir la pagina.
    @notes = nil
    @notes_armed = false

    def self.notes_on; @notes = nil; @notes_armed = true; end

    def self.notes_off; @notes_armed = false; end

    # param text el cuarto argumento de drawFormattedTextEx, el parrafo ya compuesto
    def self.note_text(text)
      return unless @notes_armed
      t = PokeAccess.clean(text.to_s).to_s.strip
      @notes = t unless t.empty?
    rescue StandardError
      nil
    end

    # Reads the focused data-page section name (@cursor) as the cursor moves, and the paragraph under it.
    def self.section_read(scene)
      k = SECTIONS[PokeAccess.ivar(scene, :@cursor)]
      label = k ? PokeAccess::I18n.t(k) : nil
      body = @notes
      full = [label, body].compact.reject { |s| s.to_s.empty? }.join(". ")
      data_dedup(scene, full.empty? ? nil : full)
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
PokeAccess::Hooks.around_hook("PokemonPokedexInfo_Scene", :pbDrawDataNotes, :optional => true) do |_s, nxt, _a|
  PokeAccess::PokedexInfoV21.notes_on
  begin; nxt.call; ensure; PokeAccess::PokedexInfoV21.notes_off end
end

PokeAccess::Hooks.wrap_kernel("drawFormattedTextEx", "pdx_data_notes", :before) do |args, _r|
  PokeAccess::PokedexInfoV21.note_text(args[4])
end

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
