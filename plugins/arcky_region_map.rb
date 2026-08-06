module PokeAccess
  # Arcky's Region Map, extended preview: a paged grid of the species that can be found on the focused map,
  # one grid per encounter type. Arrows move between cells and the panel below names the species.
  #
  # The cell cursor is a local inside the preview's own loop, but the scene mirrors it into @extIndex and
  # calls updateSpeciesInfo(index, pageInfo) on every move with that index as its first argument -- so the
  # argument is read rather than the mirror, which is one less thing to drift.
  #
  # Until now the only thing this screen said was "species N of M", and by accident: the same redraw writes
  # to maplocation, which the bottom-bar reader picks up. The species itself, which is the entire point of
  # opening the grid, was never named.
  module ArckyRegionMap
    def self.species(scene, index)
      list = PokeAccess.ivar(scene, :@list)
      i = index.to_i
      return unless list.is_a?(Array) && i >= 0 && i < list.length
      name = species_name(list[i])
      return if name.nil? || name.empty?
      # The name is in the dedup key, not just the index. Leaving the grid, and switching encounter type,
      # both clear the plugin's own cursor and rebuild the list, so coming back starts at index 0 -- equal to
      # the last key recorded -- and the first species of the NEW list would never be spoken.
      spoken = PokeAccess::Cursor.on_change(scene, :arcky_species, [i, name]) do
        PokeAccess::I18n.t(:list_entry, :name => name, :n => i + 1, :tot => list.length)
      end
      return if spoken.nil? || spoken.empty?
      PokeAccess.speak(spoken, true)
      # The panel's own content -- type, catch rate and the encounter chance per level band -- goes to the
      # info key rather than into this line. It is the reason for opening the grid, but the grid is swept
      # cell by cell, and reading four facts on every arrow would make sweeping unusable. One key away is
      # where the rest of the mod puts detail like this.
      PokeAccess::Info.set_info(:text, panel_detail(scene, list[i]))
      # The same redraw writes the cell position into the bottom bar, and that reader interrupts with a line
      # that changes on every move, so it would cut this one off mid-word. Marking its slot with what it is
      # about to see keeps it quiet here without disabling it, which matters: on the plain map screen it is
      # the only reader that speaks.
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

    # "Nv. 3 a 7, 20 percent" per band, collapsing a band whose bounds match into a single level.
    def self.encounter_bands(entries)
      return nil unless entries.is_a?(Array)
      out = []
      entries.each do |data|
        lo = (data[:level][:min] rescue nil)
        hi = (data[:level][:max] rescue nil)
        next if lo.nil?
        band = (lo == hi) ? lo.to_s : PokeAccess::I18n.t(:arm_band, :lo => lo, :hi => hi)
        out.push(PokeAccess::I18n.t(:arm_chance, :band => band, :pct => data[:chance]))
      end
      out.join(", ")
    rescue StandardError
      nil
    end

    # What the plugin writes to the bottom bar right after this hook returns, rebuilt with the plugin's own
    # expression rather than a copy of the wording: the label goes through the game's own _INTL, so hardcoding
    # it here would stop matching the moment the game is played in another language, and the mark would
    # silence nothing.
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
