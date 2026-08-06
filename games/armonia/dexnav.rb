# Armonia field DexNav (DexNav, opened from the pause menu). A blocking UI navigated by zone with left/
# right; loadCurrentPage redraws on open and on every zone change, and its species are shown only as
# icons. Reads the zone name (land/surf/fishing) and the species found in it.
#
# The A key flips the screen to a REWARDS page and calls the very same loadCurrentPage. @encounterArray is
# still loaded there, so without a branch the reader answered the encounter list again -- and the rewards,
# the entire content of that page, were never read at all.
module PokeAccess
  module ArmoniaDexNav
    ZONES = { "dexnavtierra" => "Hierba", "dexnavsurf" => "Surf", "dexnavrio" => "Pesca" }

    # The encounter page: the zone and the species it holds, each with the Pokedex state the screen shows by
    # tone (a species neither seen nor owned is painted as a black silhouette, so naming it is a spoiler).
    def self.encounters(scene)
      zone = (PokeAccess.ivar(scene, :@visibleZones)[PokeAccess.ivar(scene, :@index)] rescue nil)
      zname = ZONES[zone && zone[1]] || "Zona"
      list = PokeAccess.ivar(scene, :@encounterArray) || []
      return "#{zname}, sin especies detectadas" if list.empty?
      names = list.map { |s| species_label(s) }
      "#{zname}, #{list.length} especies: #{names.join(", ")}"
    rescue StandardError
      nil
    end

    # A species as the icon shows it: silhouetted while unseen, named once seen, marked once owned.
    def self.species_label(sp)
      name = (PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s
      return "sin descubrir" if !($Trainer.hasSeen?(sp) rescue true) && !($Trainer.hasOwned?(sp) rescue true)
      ($Trainer.hasOwned?(sp) rescue false) ? "#{name}, capturado" : "#{name}, visto"
    rescue StandardError
      sp.to_s
    end

    # The rewards page: how many of the zone rewards are already collected, each item with its quantity and
    # whether it has been claimed, and the completion prize.
    def self.rewards(scene)
      mapid = PokeAccess.ivar(scene, :@mapid)
      items = (::DEXNAV_REWARDS[mapid] rescue nil)
      return "Recompensas, esta zona no tiene" unless items.is_a?(Array) && items.length > 1
      got = ($PokemonGlobal.getDexNavRewards(mapid) rescue nil) || {}
      zones = items.length - 1
      taken = 0
      parts = []
      for i in 0...zones
        rw = items[i]
        claimed = (got[rw[0]] == true)
        taken += 1 if claimed
        parts.push("#{item_label(rw[1])} por #{rw[2]}#{claimed ? ', recibida' : ''}")
      end
      final = item_label(items[items.length - 1])
      done = (got[-1] == true) ? ", recibida" : ""
      "Recompensas, #{taken} de #{zones}. #{parts.join(', ')}. Al completar: #{final}#{done}"
    rescue StandardError
      nil
    end

    def self.item_label(item)
      (PokeAccess::Data.item_name(item) rescue nil) || item.to_s
    end
  end
end

PokeAccess::Game.define("armonia") do
  after("DexNav", :loadCurrentPage) do |scene, _result, _args|
    showing = PokeAccess.ivar(scene, :@showPageRewards)
    t = showing ? PokeAccess::ArmoniaDexNav.rewards(scene) : PokeAccess::ArmoniaDexNav.encounters(scene)
    PokeAccess.speak_clean(t, true) if t && !t.to_s.empty?
  end
end
