# raZ's Simple Encounter List Window (EncounterListUI: awakening's "Dex NAv", Pokemon Z's DexNav panel,
# realidea's "Encuentros Updated"): the current map's wild species as icons with no readable text and no
# cursor -- it draws everything once and its loop only waits for B/C. getEncData fills @encarray inside the
# constructor (realidea's copy: loadEncounterData fills @encounterArray), so the zone and species are read
# right after it, before the loop starts.
#
# A map with no encounters does not get an empty array: getEncData fills it with the sentinel [7], and the
# screen decides by comparing the LAST entry to 7 before writing its no-encounters line. Read as-is, that
# sentinel became species 7 and announced one wild Squirtle on a map the screen says is empty.
module PokeAccess
  module SimpleEncounterList
    def self.read(scene)
      enc = PokeAccess.ivar(scene, :@encarray) || PokeAccess.ivar(scene, :@encounterArray)
      loc = ($game_map.name rescue nil).to_s
      if !enc.is_a?(Array) || enc.empty? || enc.last == 7
        PokeAccess.speak(PokeAccess::I18n.t(:enc_none, :loc => loc), true)
        return
      end
      entries = enc.map do |sp|
        nm = (PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s
        st = PokeAccess::Util.dex_owned?(sp) ? :dex_caught : (PokeAccess::Util.dex_seen?(sp) ? :dex_seen : :dex_unknown)
        [nm, st]
      end
      PokeAccess.speak(PokeAccess::EncounterList.summary(loc, entries), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("EncounterListUI", :getEncData, :optional => true) { |s, _r, _a| PokeAccess::SimpleEncounterList.read(s) }
PokeAccess::Hooks.after_hook("EncounterListUI", :loadEncounterData, :optional => true) { |s, _r, _a| PokeAccess::SimpleEncounterList.read(s) }
