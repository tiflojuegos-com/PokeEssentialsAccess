# Hoenn's smaller field puzzles in Sevii: the secret switches of the Underwater Temple of Draconid Ruins (maps 443, 552
# and 554, a switch with no sprite on a rock, a wall and a statue, which floods the room into its twin map); the tides
# of Shoal Cave (Route 125 sends the player to map 483 at low tide, from 3:00 to 8:59 and 15:00 to 20:59, else to 482); the
# log bridges of Route 119 and the Safari Zone (maps 409 and 449), whose ends ("bikeOnly") only let a bicycle on, facing
# along the logs; the warp tiles of the Mossdeep Gym (map 514), six of which lead from the door to Liza and Tate; the
# murals of Draconid Ruins (map 436), whose holes take the Adamant and Lustrous Orbs; and the bicycle ramps of Granite
# Cave and Routes 111 and 115 and the Safari Zone, which launch a rider three tiles up and bounce a walker back.
module PokeAccess
  module SeviiHoenn
    # Temple room => [switch event, the switch it lights, what it hides in].
    TEMPLE = { 443 => [1, 189, :sevii_temple_rock], 552 => [1, 222, :sevii_temple_wall], 554 => [1, 223, :sevii_temple_statue] }
    SHOAL = [482, 483, 484, 485, 486, 487, 488]
    # Log bridge map => its bicycle-only ends.
    LOGS = { 409 => [7, 12, 15, 16, 17, 18, 24, 25], 449 => [4, 5] }
    # Map => the ramp events (pairs, the bottom and top of each).
    RAMPS = { 48 => [3, 4], 272 => [1, 2], 412 => [2, 3], 413 => [1, 2, 3, 4], 446 => [1, 2] }
    MOSSDEEP = 514
    # The warp tiles from the gym's door to the leaders, in the order they are taken (simulated on the floor and the
    # warp events, auditoria/puzzles-2026-11/_pulido/sim/sevii/mossdeep.rb).
    MOSSDEEP_WAY = [6, 11, 23, 27, 29, 13]

    # Draconid Ruins (map 436): the murals' holes with no sprite (EV49 for the Adamant Orb, lighting switch 186; EV48 for
    # the Lustrous Orb, switch 187) and the Griseous Orb that can be taken from its own (EV46).
    RUINS = 436
    ORB_HOLES = { 49 => [:ADAMANTORB, 186], 48 => [:LUSTROUSORB, 187] }
    GRISEOUS = 46

    # An item's name as the game writes it.
    def self.item_name(sym)
      PokeAccess::Data.item_name(sym) || sym.to_s
    end

    # The cave's maps by the tide Route 125 sent the player in on (pbIsLowTide? as they entered): the game keeps that
    # tide's maps until they leave, whatever the clock says meanwhile.
    LOW_TIDE = [483, 484, 485, 486, 488]

    # The tide the player entered on, read from the map the game chose.
    def self.low_tide?
      LOW_TIDE.include?($game_map.map_id)
    end

    def self.tide_line
      case low_tide?
      when true then :sevii_tide_low
      when false then :sevii_tide_high
      end
    end
  end
end

PokeAccess::Game.define("sevii") do
  hoenn = PokeAccess::SeviiHoenn

  hoenn::TEMPLE.each do |map, spec|
    ev, switch, where = spec
    mechanic(:state, map) do
      auto
      spot :event => ev, :label => where, :assist => true
      hint :sevii_temple_hint
      solved(nil, :quiet => true) { $game_switches[switch] }
    end
  end

  mechanic(:state, hoenn::SHOAL) do
    auto
    arrival_hint lambda { hoenn.tide_line }
    info { hoenn.tide_line }
    hint :sevii_tide_hint
  end

  hoenn::LOGS.each do |map, ends|
    mechanic(:state, map) do
      auto
      name ends, :sevii_logs_end
      watch :switch => 179, :label => :sevii_logs, :on => :sevii_logs_on, :off => :sevii_logs_off
      hint :sevii_logs_hint
    end
  end

  hoenn::RAMPS.each do |map, ramps|
    mechanic(:state, map, :part => :ramps) do
      auto
      name ramps, :sevii_ramp, :grouped => true
      hint :sevii_ramp_hint
    end
  end

  mechanic(:state, hoenn::RUINS) do
    auto
    hoenn::ORB_HOLES.each do |ev, spec|
      name ev, lambda { |_e| [$game_switches[spec[1]] ? :sevii_orb_hole_full : :sevii_orb_hole, { :item => hoenn.item_name(spec[0]) }] }
    end
    name hoenn::GRISEOUS, lambda { |_e| [:sevii_orb_slot, { :item => hoenn.item_name(:GRISEOUSORB) }] }
    hint :sevii_orb_hint
    solved(nil, :quiet => true) { $game_switches[186] && $game_switches[187] }
  end

  mechanic(:state, hoenn::MOSSDEEP, :part => :way) do
    auto
    hoenn::MOSSDEEP_WAY.each_with_index do |ev, i|
      spot :event => ev, :label => [:sevii_mossdeep_way, { :n => i + 1, :of => hoenn::MOSSDEEP_WAY.length }],
           :assist => true, :onto => true
    end
    hint :sevii_mossdeep_hint
    solved(nil, :quiet => true) { $game_switches[277] || $game_switches[278] }
  end
end
