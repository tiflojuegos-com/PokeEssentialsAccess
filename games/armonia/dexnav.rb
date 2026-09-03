# Armonia field DexNav (DexNav, opened from the pause menu). A blocking UI navigated by zone with left/
# right; loadCurrentPage redraws on open and on every zone change, and its species are shown only as
# icons. Reads the zone name (land/surf/fishing) and the species found in it.
#
# The A key flips the screen to a REWARDS page and calls the very same loadCurrentPage. @encounterArray is
# still loaded there, so without a branch the reader answered the encounter list again -- and the rewards,
# the entire content of that page, were never read at all.
module PokeAccess
  module ArmoniaDexNav
    ZONES = { "dexnavtierra" => :dxn_zone_grass, "dexnavsurf" => :dxn_zone_surf, "dexnavrio" => :dxn_zone_fish }

    # The encounter page: the zone and the species it holds, each with the Pokedex state the screen shows by
    # tone (a species neither seen nor owned is painted as a black silhouette, so naming it is a spoiler).
    def self.encounters(scene)
      zone = (PokeAccess.ivar(scene, :@visibleZones)[PokeAccess.ivar(scene, :@index)] rescue nil)
      zk = ZONES[zone && zone[1]]
      zname = zk ? PokeAccess::I18n.t(zk) : PokeAccess::I18n.t(:dxn_zone)
      list = PokeAccess.ivar(scene, :@encounterArray) || []
      return PokeAccess::I18n.t(:dxn_none, :zone => zname) if list.empty?
      names = list.map { |s| species_label(s) }
      PokeAccess::I18n.t(:dxn_list, :zone => zname, :n => list.length, :names => names.join(", "))
    rescue StandardError
      nil
    end

    # A species as the icon shows it: silhouetted while unseen, named once seen, marked once owned.
    def self.species_label(sp)
      name = (PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s
      owned = PokeAccess::Util.dex_owned?(sp)
      return PokeAccess::I18n.t(:dex_unknown) unless owned || PokeAccess::Util.dex_seen?(sp)
      "#{name}, #{PokeAccess::I18n.t(owned ? :dex_caught : :dex_seen)}"
    rescue StandardError
      sp.to_s
    end

    # The rewards page: how many of the zone rewards are already collected, each item with its quantity and
    # whether it has been claimed, and the completion prize.
    def self.rewards(scene)
      mapid = PokeAccess.ivar(scene, :@mapid)
      items = (::DEXNAV_REWARDS[mapid] rescue nil)
      return PokeAccess::I18n.t(:dxn_rewards_none) unless items.is_a?(Array) && items.length > 1
      got = ($PokemonGlobal.getDexNavRewards(mapid) rescue nil) || {}
      zones = items.length - 1
      taken = 0
      parts = []
      for i in 0...zones
        rw = items[i]
        claimed = (got[rw[0]] == true)
        taken += 1 if claimed
        line = PokeAccess::I18n.t(:dxn_reward_line, :item => item_label(rw[1]), :n => rw[2])
        line += ", " + PokeAccess::I18n.t(:dxn_claimed) if claimed
        z = zone_name(rw[0])
        parts.push(z ? "#{z}: #{line}" : line)
      end
      final = item_label(items[items.length - 1])
      final += ", " + PokeAccess::I18n.t(:dxn_claimed) if got[-1] == true
      PokeAccess::I18n.t(:dxn_rewards, :taken => taken, :tot => zones, :list => parts.join(", "), :final => final)
    rescue StandardError
      nil
    end

    # An item's real name. The rewards table holds SYMBOLS and this game names items by numeric id, so the
    # symbol is resolved first -- the same step the screen takes before it can load the icon.
    def self.item_label(item)
      pair = (PokeAccess::Data.item_id(item) rescue nil)
      name = pair.is_a?(Array) ? pair[1] : nil
      return name.to_s if name && !name.to_s.empty?
      (PokeAccess::Data.item_name(item) rescue nil).to_s
    end

    # The zone a reward belongs to, named as the encounter page names it. The reward row carries the same
    # EncounterTypes value DEXNAV_ZONES is keyed by, and the screen paints that zone's base under the icon.
    def self.zone_name(enc)
      row = (::DEXNAV_ZONES.find { |z| z[0] == enc } rescue nil)
      row ? ZONES[row[1]] : nil
    rescue StandardError
      nil
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

# With zero encounter zones on the map startUI (the screen's own loop) returns at once without opening
# anything; spoken at the return so the player learns why nothing happened.
PokeAccess::Game.define("armonia") do
  around("DexNav", :startUI, :optional => true) do |scene, nxt, _a|
    begin
      nxt.call
    ensure
      if PokeAccess.ivar(scene, :@num_enc).to_i == 0
        PokeAccess.speak(PokeAccess::I18n.t(:dxn_no_zones), true)
      end
    end
  end
end
