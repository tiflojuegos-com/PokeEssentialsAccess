# The Regi chambers (0237_Regi Checks): seven floor panels that sink as they are stepped on (self switch A, a knock),
# then a parallel event (EV8) checks the party once all seven are down, or says "Nothing happened..." and raises them
# again. Regice's Island Cave (map 41) asks for six Pokémon, Relicanth first, Wailord sixth and an Ice type; Regirock's
# Desert Tomb (map 118) the same with a nickname instead; Registeel's Ancient Tomb (map 237) the same with the panels in
# reading order (variable 50, a wrong one ends the try until the room is left); Regigigas's Tanoby Temple (map 241) the
# three Regis in the party.
module PokeAccess
  module SeviiRegis
    # Map => [panel events, the variable they count in, what the party needs beyond the panels].
    CHAMBERS = { 41 => [[1, 2, 3, 4, 5, 6, 7], 43, :ice], 118 => [[1, 2, 3, 4, 5, 6, 7], 48, :nickname],
                 237 => [[1, 2, 3, 4, 5, 6, 7], 49, :order], 241 => [[1, 2, 3, 4, 5, 6, 7], 52, :royals] }
    # Registeel's panels in reading order (each page asks variable 50 to be its place).
    ORDER = [4, 6, 1, 3, 5, 2, 7]

    # A species' number, or nil where the game has none.
    def self.species(sym)
      getID(PBSpecies, sym)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What the party still lacks for the chamber's kind, as language keys, in the check's own order.
    def self.missing(kind)
      party = ($Trainer.party rescue nil)
      return [] unless party
      out = []
      if kind == :royals
        royals = [:REGICE, :REGIROCK, :REGISTEEL].map { |s| species(s) }
        out.push(:sevii_regi_need_royals) unless royals.all? { |r| party.any? { |pk| pk.species == r } }
        return out
      end
      out.push(:sevii_regi_need_six) if party.length < 6
      out.push(:sevii_regi_need_relicanth) unless party[0] && party[0].species == species(:RELICANTH)
      out.push(:sevii_regi_need_wailord) unless party[5] && party[5].species == species(:WAILORD)
      out.push(:sevii_regi_need_ice) if kind == :ice && !(pbHasType?(:ICE) rescue false)
      out.push(:sevii_regi_need_nickname) if kind == :nickname && !nicknamed?(party)
      out
    end

    # True if a party member's name is not its species' name; a species with no name known counts as none.
    def self.nicknamed?(party)
      party.any? do |pk|
        species = PokeAccess::Data.species_name(pk.species)
        species && pk.name != species
      end
    end

    # True while a panel of this map is down.
    def self.down?(map, ev)
      $game_self_switches[[map, ev, "A"]] ? true : false
    end

    # Registeel's next panel, or nil after a wrong one (variable 49 counts the presses, 50 the right ones).
    def self.next_panel
      return nil unless $game_variables[49].to_i == $game_variables[50].to_i
      ORDER[$game_variables[50].to_i]
    end

    # The assisted line: what the party lacks, then how to step on the panels.
    def self.hint(kind)
      lack = missing(kind)
      unless lack.empty?
        return [:sevii_regi_party_hint, { :list => lack.map { |k| PokeAccess::I18n.t(k) }.join(", ") }]
      end
      return :sevii_regi_panels_hint unless kind == :order
      next_panel ? :sevii_regi_order_hint : :sevii_regi_order_wrong
    end
  end
end

PokeAccess::Game.define("sevii") do
  regis = PokeAccess::SeviiRegis

  regis::CHAMBERS.each do |map, spec|
    panels, var, kind = spec
    mechanic(:state, map) do
      auto
      name panels, lambda { |ev| regis.down?(map, ev.id) ? :sevii_regi_panel_down : :sevii_regi_panel }
      count :sevii_regi_panels, :selfs => [panels, "A", map], :of => panels.length
      arrival_hint :sevii_regi_rule
      hint lambda { regis.hint(kind) }
      solved(nil, :quiet => true) { $game_variables[var].to_i >= 100 || $game_self_switches[[map, 8, "A"]] }
      next unless kind == :order
      panels.each do |panel|
        spot :event => panel, :label => :sevii_regi_next_panel, :assist => true, :onto => true,
             :when => lambda { regis.missing(kind).empty? && regis.next_panel == panel }
      end
    end
  end
end
