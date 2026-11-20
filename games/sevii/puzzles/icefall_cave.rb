# The Icefall Cave of Four Island. On its middle floor (map 70) nine ice tiles (EV7 to EV15) crack at the first step
# (self switch A, then drawn cracked) and give way at the second, dropping the player to fixed tiles of the floor below
# (map 71), whose ladders lead back up; pbResetIcefCave mends them on leaving by the entrance room (map 69). None of them
# is on the way to the back room (map 74, EV6 at (4,7)): that way climbs the waterfall of the entrance room's lake to
# the ladder at its top (map 69 EV3), which lands in the corridor above EV6.
module PokeAccess
  module SeviiIcefall
    MIDDLE = 70
    LOWER = 71
    CRACKS = (7..15).to_a
    # Where each crack drops the player on the floor below.
    LANDINGS = [[3, 15], [3, 11], [3, 10], [4, 11], [4, 10], [3, 4], [10, 6], [11, 10], [5, 6]]

    # A crack's name once it shows, nil before (it is drawn as plain ice until stepped on).
    def self.crack_name(ev)
      $game_self_switches[[MIDDLE, ev.id, "A"]] ? :sevii_ice_cracked : nil
    end
  end
end

PokeAccess::Game.define("sevii") do
  ice = PokeAccess::SeviiIcefall

  mechanic(:state, ice::MIDDLE) do
    auto
    name ice::CRACKS, lambda { |ev| ice.crack_name(ev) }
    avoid ice::CRACKS, :assist => true
    hint :sevii_ice_hint
    solved(nil, :quiet => true) { $game_switches[115] }
  end

  mechanic(:state, 69, :part => :way) do
    auto
    hint :sevii_ice_hint
    solved(nil, :quiet => true) { $game_switches[115] }
  end

  mechanic(:state, ice::LOWER) do
    auto
    ice::LANDINGS.each { |tile| sent_back :sevii_ice_fell, :maps => [ice::MIDDLE], :to => tile }
  end
end
