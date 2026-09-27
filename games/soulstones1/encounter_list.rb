module PokeAccess
  # Soulstones' encounter list (EncounterListUI_withforms, an edited copy of raZ's Simple Encounter List with one page
  # per encounter type, turned with left and right): each page read once getEncData fills @encarray2, headed as the
  # screen paints it, "map: encounter type". A lone 7 is the screen's no-encounters sentinel, not a species. This copy
  # paints every species' icon in colour and no Pokedex mark, so each species is said by its name alone.
  module Soulstones1Encounters
    # The page's header as painted: the map name and the encounter type of the page (@type[@index]).
    def self.header(scene)
      loc = ($game_map.name rescue nil).to_s
      types = PokeAccess.ivar(scene, :@type)
      name = ([EncounterTypes::Names].flatten[types[PokeAccess.ivar(scene, :@index).to_i]] rescue nil)
      (name.nil? || name.to_s.empty?) ? loc : "#{loc}: #{name}"
    end

    # The species of one list entry: the list keeps form-aware ids, whose base species names the icon.
    def self.species_of(fspecies)
      (pbGetSpeciesFromFSpecies(fspecies)[0] rescue nil) || fspecies
    end

    # The page's place among the area's encounter types, which the arrows at its sides show; nil for a lone type,
    # which has no arrows.
    def self.page(scene)
      types = PokeAccess.ivar(scene, :@type)
      return nil unless types.is_a?(Array) && types.length > 1
      PokeAccess::I18n.t(:adv_dex_page, :n => PokeAccess.ivar(scene, :@index).to_i + 1, :m => types.length)
    end

    # Speaks the page: its species by name, then its place among the types while positions are said; or the area's
    # lack of encounters.
    def self.read(scene)
      enc = PokeAccess.ivar(scene, :@encarray2)
      if !enc.is_a?(Array) || enc.empty? || enc == [7]
        return PokeAccess.speak(PokeAccess::I18n.t(:enc_none, :loc => ($game_map.name rescue nil).to_s), true)
      end
      head = header(scene)
      entries = enc.map do |fs|
        sp = species_of(fs)
        [(PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s, nil]
      end
      pg = page(scene)
      whole = PokeAccess::EncounterList.summary(head, entries, true)
      said = PokeAccess::EncounterList.summary(head, entries)
      PokeAccess::Info.set_info(:text, pg ? "#{whole}, #{pg}" : whole)
      said = "#{said}, #{pg}" if pg && PokeAccess::Verbosity.keep?(:positions, :medium)
      PokeAccess.speak(said, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  after("EncounterListUI_withforms", :getEncData) { |s, _r, _a| PokeAccess::Soulstones1Encounters.read(s) }
end
