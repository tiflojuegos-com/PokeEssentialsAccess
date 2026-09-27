module PokeAccess
  # Arcky's Region Map: the extended preview's species grid (the cell index is updateSpeciesInfo's argument), the
  # map mode and the location preview.
  module ArckyRegionMap
    # The focused species, keyed on index and name (a new list restarts at 0), its panel detail on the info key;
    # the bottom-bar reader's slot is marked with the text it is about to see, so it stays quiet.
    def self.species(scene, index)
      list = PokeAccess.ivar(scene, :@list)
      i = index.to_i
      return unless list.is_a?(Array) && i >= 0 && i < list.length
      name = species_name(list[i])
      return if name.nil? || name.empty?
      spoken = PokeAccess::Cursor.on_change(scene, :arcky_species, [i, name]) do
        PokeAccess::Verbosity.list_entry(name, i + 1, list.length)
      end
      return if spoken.nil? || spoken.empty?
      PokeAccess.speak(spoken, true)
      PokeAccess::Info.set_info(:text, panel_detail(scene, list[i]))
      PokeAccess::Cursor.changed?(nil, :regionmap, PokeAccess.clean(bar_text(i, list.length)))
    rescue StandardError
      nil
    end

    # The panel's detail (type, catch rate, chance per level band) from the focused encounter table's species entry.
    def self.panel_detail(scene, species)
      table = PokeAccess.ivar(scene, :@tableData)
      idx = PokeAccess.ivar(scene, :@tableIndex)
      entry = (table.values[idx][species] rescue nil) if table.respond_to?(:values) && idx
      return nil unless entry.is_a?(Hash)
      parts = []
      parts.push(PokeAccess::I18n.t(:arm_type, :t => entry[:type])) if entry[:type]
      parts.push(PokeAccess::I18n.t(:arm_catch, :n => entry[:catchRate])) if entry[:catchRate]
      bands = encounter_bands(entry[:entries])
      parts.push(PokeAccess::I18n.t(:arm_rate, :list => bands)) unless bands.nil? || bands.empty?
      parts.empty? ? nil : parts.join(". ")
    rescue StandardError
      nil
    end

    # A chance as the plugin prints it: a whole-number Float without its decimal (12.0 as 12).
    def self.pct(n)
      (n.is_a?(Float) && n.to_i == n) ? n.to_i : n
    end

    # "Nv. 3 a 7, 20 percent" per band, collapsing a band whose bounds match into a single level.
    def self.encounter_bands(entries)
      return nil unless entries.is_a?(Array)
      out = []
      entries.each do |data|
        lo = (data[:level][:min] rescue nil)
        hi = (data[:level][:max] rescue nil)
        next if lo.nil?
        band = (lo == hi) ? lo.to_s : PokeAccess::I18n.t(:arm_band, :lo => lo, :hi => hi)
        out.push(PokeAccess::I18n.t(:arm_chance, :band => band, :pct => pct(data[:chance])))
      end
      out.join(", ")
    rescue StandardError
      nil
    end

    # What the plugin writes to the bottom bar right after this hook returns, built with the plugin's own
    # _INTL expression so it keeps matching in any language.
    def self.bar_text(i, total)
      "#{_INTL("Especie")} #{i + 1}/#{total}"
    rescue StandardError
      ""
    end

    # Says the map's mode when it changes: the painted text that is one of the plugin's mode names.
    def self.mode(scene, rows)
      names = mode_names(scene)
      t = Array(rows).map { |r| PokeAccess.clean(r.to_s) }.reverse.find { |r| names.include?(r) }
      return if t.nil? || !PokeAccess::Cursor.changed?(scene, :arcky_mode, t)
      PokeAccess.speak(PokeAccess::I18n.t(:arm_mode, :m => t), false)
    end

    # The names the corner can show, from the table of modes the plugin builds before painting one.
    def self.mode_names(scene)
      info = PokeAccess.ivar(scene, :@modeInfo)
      return [] unless info.respond_to?(:values)
      info.values.map { |d| PokeAccess.clean((d[:text] rescue nil).to_s) }.reject { |s| s.empty? }
    rescue StandardError
      []
    end

    # The directions of the preview panel, by the icon each exit is painted after.
    DIRECTIONS = { "north" => :dir_n, "northEast" => :dir_ne, "east" => :dir_e, "southEast" => :dir_se,
                   "south" => :dir_s, "southWest" => :dir_so, "west" => :dir_o, "northWest" => :dir_no }

    # Starts collecting the location preview (getLocationInfo), painted with the plugin's own drawText; built with
    # the panel closed, it is an opening, said even if it repeats the last one.
    def self.preview_start(scene)
      @preview = []
      PokeAccess::Cursor.reset(scene, :arcky_preview) if preview_closed?(scene)
    end

    # Whether the preview panel is closed (the plugin's PreviewState at :hidden).
    def self.preview_closed?(scene)
      box = PokeAccess.ivar(scene, :@previewBox)
      box ? ((box.isHidden rescue false) ? true : false) : false
    end

    # Collects one text the panel paints, each exit's direction icon said as its word.
    def self.preview_note(text)
      return unless @preview
      t = text.to_s.gsub(/<icon=(\w+)>/) do
        k = DIRECTIONS[$1]
        k ? "#{PokeAccess::I18n.t(k)}: " : ""
      end
      t = PokeAccess.clean(t.gsub(/\s{2,}/, ". "))
      @preview.push(t) unless t.empty? || @preview.include?(t)
    end

    # Says the built panel when it says something new (the plugin rebuilds it on every move while open).
    def self.preview_end(scene)
      rows = @preview || []
      @preview = nil
      line = rows.map { |r| r =~ /[.!?]\z/ ? r : "#{r}." }.join(" ")
      return if line.empty? || !PokeAccess::Cursor.changed?(scene, :arcky_preview, line)
      PokeAccess.speak(line, true)
    end

    # The species name, through the shared data layer so the reader does not care which era resolves it.
    def self.species_name(sp)
      return nil if sp.nil?
      n = (PokeAccess::Data.species_name(sp) rescue nil)
      (n && !n.to_s.empty?) ? PokeAccess.clean(n.to_s) : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonRegionMap_Scene", :updateSpeciesInfo, :optional => true) do |scene, _r, args|
  PokeAccess::ArckyRegionMap.species(scene, args[0])
end

# The panel's detail leaves the info key when the screen closes.
PokeAccess::Hooks.after_hook("PokemonRegionMap_Scene", :pbEndScene, :optional => true) do |_s, _r, _a|
  PokeAccess::Info.clear_text
end

PokeAccess::Hooks.around_hook("PokemonRegionMap_Scene", :mapModeSwitchInfo, :optional => true) do |scene, nxt, _a|
  PokeAccess::PaintCapture.arm(:arcky_mode)
  begin
    nxt.call
  ensure
    PokeAccess::ArckyRegionMap.mode(scene, PokeAccess::PaintCapture.take(:arcky_mode, :positions))
  end
end

PokeAccess::Hooks.around_hook("PokemonRegionMap_Scene", :getLocationInfo, :optional => true) do |scene, nxt, _a|
  PokeAccess::ArckyRegionMap.preview_start(scene)
  begin
    nxt.call
  ensure
    PokeAccess::ArckyRegionMap.preview_end(scene)
  end
end
PokeAccess::Hooks.before_hook("PokemonRegionMap_Scene", :drawText, :optional => true) do |_scene, args|
  PokeAccess::ArckyRegionMap.preview_note(args[5])
end
