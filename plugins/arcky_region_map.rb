module PokeAccess
  # Arcky's Region Map, extended preview: a paged grid of the species found on the focused map, one grid per
  # encounter type, with a panel below naming the species.
  #
  # The cell cursor is a local inside the preview's loop, but updateSpeciesInfo(index, pageInfo) receives it
  # on every move, so the argument is read rather than the @extIndex mirror.
  module ArckyRegionMap
    # The focused species. Three constraints shape it:
    #
    # The name is in the dedup key, not just the index: leaving the grid or switching encounter type rebuilds
    # the list and returns to index 0, so an index-only key would never announce the new list's first entry.
    #
    # The panel's own detail (type, catch rate, chance per level band) goes to the info key: the grid is
    # swept cell by cell and four facts per arrow would make that unusable.
    #
    # The same redraw feeds the bottom-bar reader, which interrupts. Its slot is marked with the text it is
    # about to see so it stays quiet here without being disabled, since on the plain map screen it is the
    # only reader that speaks.
    def self.species(scene, index)
      list = PokeAccess.ivar(scene, :@list)
      i = index.to_i
      return unless list.is_a?(Array) && i >= 0 && i < list.length
      name = species_name(list[i])
      return if name.nil? || name.empty?
      spoken = PokeAccess::Cursor.on_change(scene, :arcky_species, [i, name]) do
        PokeAccess::I18n.t(:list_entry, :name => name, :n => i + 1, :tot => list.length)
      end
      return if spoken.nil? || spoken.empty?
      PokeAccess.speak(spoken, true)
      PokeAccess::Info.set_info(:text, panel_detail(scene, list[i]))
      PokeAccess::Cursor.changed?(nil, :regionmap, PokeAccess.clean(bar_text(i, list.length)))
    rescue StandardError
      nil
    end

    # The panel beside the grid, rebuilt from the same table the screen paints it from: the entry keyed by
    # species in the focused encounter table.
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

    # A chance as the plugin prints it: its convertIntegerOrFloat drops the decimal of a whole-number Float,
    # so the screen says 12% where the raw value is 12.0.
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

    # The species name, through the shared data layer so the reader does not care which era resolves it.
    def self.species_name(sp)
      return nil if sp.nil?
      n = (PokeAccess::Data.species_name(sp) rescue nil)
      (n && !n.to_s.empty?) ? PokeAccess.clean(n.to_s).to_s.strip : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonRegionMap_Scene", :updateSpeciesInfo, :optional => true) do |scene, _r, args|
  PokeAccess::ArckyRegionMap.species(scene, args[0])
end

# The panel's detail lives on the info key while the grid is open, and only then: once the screen closes the
# key would answer for a map square with the data of a species no longer on screen.
PokeAccess::Hooks.after_hook("PokemonRegionMap_Scene", :pbEndScene, :optional => true) do |_s, _r, _a|
  PokeAccess::Info.clear_text
end
