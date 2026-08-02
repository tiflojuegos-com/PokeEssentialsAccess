module PokeAccess
  # The pokedex entry detail (PokemonPokedexInfo_Scene) rewritten by the Modular UI Scenes plugin into
  # modular pages dispatched through drawPage(page): :page_info (category, height, weight, dex text),
  # :page_area, :page_forms and, with the MUI Pokedex Data Page plugin, :page_data (types, abilities, base
  # stats). Up/down change the species, left/right the page; both redraw via drawPage, so reading there
  # covers every move. Content is read from GameData by species and form. The main dex list (Window_Pokedex)
  # is read by the core menu hook, so only the detail is added.
  module PokedexInfoV21
    # Species per page in the MUI Data Page sub-list (its grid is 12 entries).
    DATA_PAGE_SIZE = 12

    # Resets both dedups (Cursor slots on the scene) so reopening an entry reads it again.
    def self.reset(scene)
      PokeAccess::Cursor.reset(scene, :pdx_page)
      PokeAccess::Cursor.reset(scene, :pdx_data)
    end

    # The spoken text for the focused pokedex page, or nil.
    def self.page_text(scene)
      species = PokeAccess.ivar(scene, :@species)
      return nil unless species
      form = (scene.instance_variable_get(:@form) rescue 0).to_i
      data = (GameData::Species.get_species_form(species, form) rescue nil)
      data = (GameData::Species.get(species) rescue nil) unless data
      return nil unless data
      name  = (data.name rescue species.to_s)
      owned = (PokeAccess::Engine.player.owned?(species) rescue false)
      pid   = (scene.instance_variable_get(:@page_id) rescue :page_info)
      case pid
      when :page_area  then PokeAccess::I18n.t(:pdx_zone, :name => name)
      when :page_forms
        fname = (data.form_name rescue nil)
        (fname && !fname.to_s.empty?) ? PokeAccess::I18n.t(:pdx_form, :name => name, :f => fname) : PokeAccess::I18n.t(:pdx_forms, :name => name)
      when :page_data  then data_text(name, data)
      else                  info_text(scene, name, data, owned)
      end
    rescue StandardError
      nil
    end

    # The info page: dex number, category, height, weight and the dex entry text. param owned whether the
    # species is owned (details are hidden if only seen)
    def self.info_text(scene, name, data, owned)
      num = (entry_number(scene) rescue nil)
      parts = [num ? PokeAccess::I18n.t(:pdx_number, :n => num, :name => name) : name]
      if owned
        cat = (data.category rescue nil)
        parts.push(PokeAccess::I18n.t(:pdx_category, :cat => cat)) if cat && !cat.to_s.empty?
        h = (data.height rescue 0).to_i
        w = (data.weight rescue 0).to_i
        parts.push(PokeAccess::I18n.t(:pdx_height, :h => PokeAccess::Pokedex.fmt_dec(h))) if h > 0
        parts.push(PokeAccess::I18n.t(:pdx_weight, :w => PokeAccess::Pokedex.fmt_dec(w))) if w > 0
        desc = (data.pokedex_entry rescue nil)
        parts.push(desc.to_s) if desc && !desc.to_s.empty?
      else
        parts.push(PokeAccess::I18n.t(:pdx_not_caught))
      end
      parts.join(". ")
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
      entry = dexlist[idx]
      n = (entry[:number] rescue nil)
      return nil unless n && n > 0
      (entry[:shift] rescue false) ? n - 1 : n
    end

    # Speaks the focused page if it changed since the last read (deduped by the page TEXT -- the species
    # can change without the page id changing, so the text is the honest key).
    def self.read(scene)
      t = page_text(scene)
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

# The MUI "Modular UI Scenes" pokedex detail. A core/v21 reader so any GameData-era Essentials game with the
# addon is covered; each hook binds only where the class/method exists.

# Read the focused entry page on each redraw (drawPage fires on open, species change and page change).
PokeAccess::Hooks.after_hook("PokemonPokedexInfo_Scene", :drawPage) do |scene, _r, _a|
  PokeAccess::PokedexInfoV21.read(scene)
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
