# Realidea's encounter list (raZ's window "Adapted to v.16.3 Bezier"): loadCurrentPage paints "<map>: <type>" over
# the page's species and "Especies: N, Capturados: M" under them, and left and right change the type; a map with no
# wild Pokemon gets its own line from loadEncounterData.
module PokeAccess
  module ReaEncounters
    # The page as painted: map and type, its species with their Pokedex state, and how many are caught.
    def self.page(scene)
      enc = PokeAccess.ivar(scene, :@encounterArray)
      return unless enc.is_a?(Array)
      head = "#{($game_map.name rescue nil)}: #{PokeAccess.ivar(scene, :@name)}"
      entries = enc.map { |sp| entry(sp) }
      owned = entries.select { |_n, st| st == :dex_caught }.length
      tail = PokeAccess::I18n.t(:rea_enc_owned, :n => owned)
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([PokeAccess::EncounterList.summary(head, entries, true), tail]))
      PokeAccess.speak(PokeAccess.sentences([PokeAccess::EncounterList.summary(head, entries), tail]), true)
    rescue StandardError
      nil
    end

    # A species of the page as [name, Pokedex state key].
    def self.entry(sp)
      name = (PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s
      st = PokeAccess::Util.dex_owned?(sp) ? :dex_caught : (PokeAccess::Util.dex_seen?(sp) ? :dex_seen : :dex_unknown)
      [name, st]
    end

    # The no-encounters line, when loadEncounterData found no data for the map (it then leaves @num_enc unset).
    def self.none(scene)
      return unless PokeAccess.ivar(scene, :@num_enc).nil?
      PokeAccess.speak(PokeAccess::I18n.t(:enc_none, :loc => ($game_map.name rescue nil).to_s), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  after("EncounterListUI", :loadEncounterData, :optional => true) { |s, _r, _a| PokeAccess::ReaEncounters.none(s) }
  after("EncounterListUI", :loadCurrentPage, :optional => true) { |s, _r, _a| PokeAccess::ReaEncounters.page(s) }
end
