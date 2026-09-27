# Armonia's DexNav (from the pause menu): on each loadCurrentPage, the zone and its species (shown only as icons),
# or the rewards page the A button (the Z key) flips to, which reuses loadCurrentPage with @encounterArray still
# loaded. The zone names and the keys are painted in the pages' pictures.
module PokeAccess
  module ArmoniaDexNav
    ZONES = { "dexnavtierra" => :dxn_zone_land, "dexnavsurf" => :dxn_zone_surf, "dexnavrio" => :dxn_zone_fish }

    # The page loadCurrentPage just drew: its body, the rule the rewards page paints from full, and the keys the
    # page's picture names while key hints are said.
    def self.page(scene)
      rewards_page = PokeAccess.ivar(scene, :@showPageRewards) ? true : false
      parts = [rewards_page ? rewards(scene) : encounters(scene)]
      parts.push(PokeAccess::I18n.t(:dxn_rewards_rule)) if rewards_page && PokeAccess::Verbosity.descriptions?
      parts.push(keys(rewards_page))
      PokeAccess.sentences(parts.compact)
    end

    # The keys a page's picture paints, "Z RECOMPENSA, X SALIR" or "Z POKEMON, X SALIR", as the player has them now,
    # while key hints are said; nil otherwise.
    def self.keys(rewards_page)
      return nil unless PokeAccess::Verbosity.hints?
      PokeAccess::KeyHints.localize(PokeAccess::I18n.t(rewards_page ? :dxn_keys_rewards : :dxn_keys_species))
    end

    # The zone the page shows, by the name its picture paints, with its place among the zones the arrows move
    # between; the place only where there is more than one and while positions are said.
    def self.zone_label(scene)
      index = PokeAccess.ivar(scene, :@index).to_i
      zone = (PokeAccess.ivar(scene, :@visibleZones)[index] rescue nil)
      zk = ZONES[zone && zone[1]]
      name = zk ? PokeAccess::I18n.t(zk) : PokeAccess::I18n.t(:dxn_zone)
      total = PokeAccess.ivar(scene, :@num_enc).to_i
      total < 2 ? name : PokeAccess::Verbosity.list_entry(name, index + 1, total)
    end

    # The encounter page: the zone and its species, each as species_label says it; the info key keeps it whole.
    def self.encounters(scene)
      zname = zone_label(scene)
      list = PokeAccess.ivar(scene, :@encounterArray) || []
      return PokeAccess::I18n.t(:dxn_none, :zone => zname) if list.empty?
      whole = list.map { |s| species_label(s, true) }
      zwhole = PokeAccess::Verbosity.whole { zone_label(scene) }
      PokeAccess::Info.set_info(:text, PokeAccess::I18n.t(:dxn_list, :zone => zwhole, :n => list.length, :names => whole.join(", ")))
      names = list.map { |s| species_label(s) }
      PokeAccess::I18n.t(:dxn_list, :zone => zname, :n => list.length, :names => names.join(", "))
    rescue StandardError
      nil
    end

    # A species as the icon shows it: silhouetted while unseen, named once seen, marked once owned (the mark from
    # the Pokedex reading's medium level, or always for the info key).
    def self.species_label(sp, whole = false)
      name = (PokeAccess::Data.species_name(sp) rescue nil) || sp.to_s
      owned = PokeAccess::Util.dex_owned?(sp)
      return PokeAccess::I18n.t(:dex_unknown) unless owned || PokeAccess::Util.dex_seen?(sp)
      return name.to_s unless whole || PokeAccess::Verbosity.keep?(:dex_entry, :medium)
      "#{name}, #{PokeAccess::I18n.t(owned ? :dex_caught : :dex_seen)}"
    rescue StandardError
      sp.to_s
    end

    # The rewards page: how many of the zone rewards are already collected, each item with its quantity and
    # whether it has been claimed, and the completion prize; the info key keeps it, with the rule the page paints.
    def self.rewards(scene)
      t = rewards_text(scene)
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([t, PokeAccess::I18n.t(:dxn_rewards_rule)])) if t
      t
    end

    # What the rewards page shows, or nil when it cannot be read.
    def self.rewards_text(scene)
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

    # An item's name: the rewards table holds symbols, resolved to this game's numeric ids first.
    def self.item_label(item)
      pair = (PokeAccess::Data.item_id(item) rescue nil)
      name = pair.is_a?(Array) ? pair[1] : nil
      return name.to_s if name && !name.to_s.empty?
      (PokeAccess::Data.item_name(item) rescue nil).to_s
    end

    # The zone a reward's EncounterTypes value names in DEXNAV_ZONES, by the name the encounter page says it with;
    # nil for a zone the table does not list.
    def self.zone_name(enc)
      row = (::DEXNAV_ZONES.find { |z| z[0] == enc } rescue nil)
      key = row ? ZONES[row[1]] : nil
      key ? PokeAccess::I18n.t(key) : nil
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("armonia") do
  after("DexNav", :loadCurrentPage) do |scene, _result, _args|
    PokeAccess.speak_clean(PokeAccess::ArmoniaDexNav.page(scene), true)
  end
end

# With no encounter zones on the map, startUI returns without opening anything: says so at the return.
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
