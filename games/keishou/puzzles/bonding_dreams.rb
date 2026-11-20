# The three Bonding Dreams (maps 104, 106 and 105), trials of Chushin City's dream quest, each ending at its starter's
# gigantic partner. Fire: the boulder (event 2, on (22, 33)) has to rest on (18, 23) before the flames catch the player, who
# is put back at the start; the core says what opens. Water: the orb of event 30 is the one to escort and the one the sensors
# read, and touching it throws the player out of the dream to Chushin City; the other orbs send the player back to the start.
# Grass: four floor plates (events 23 to 26) open the way and the forest spirits reset the count; fourteen pads with no
# graphic, working while switch 107 is on, throw the player the way a key is pressed; its exit (event 7) brings the player
# back with the plates loose while the way is shut.
PokeAccess::Game.define("keishou") do
  flames = [1, 7, 8, 9]
  orbs = [14, 15, 16, 17, 18, 19]
  spirits = 27..34
  pads = [1, 9, 10] + (12..22).to_a
  plates = 23..26

  mechanic(:state, 104) do
    auto
    obstacle({ :events => flames }, :moving => true, :label => :ks_o_flame)
    sent_back :ks_o_flame_back, :to => [18, 37], :events => flames
    spot :at => [18, 23], :label => :ks_o_boulder_goal, :onto => true, :when => lambda { !$game_self_switches[[104, 10, "A"]] }
    hint :ks_o_fire_hint
    active { PokeAccess::Puzzles.assist? && !$game_self_switches[[104, 10, "A"]] }
  end

  mechanic(:state, 106) do
    auto
    obstacle({ :events => orbs }, :moving => true, :label => :ks_o_dark_orb)
    name 30, :ks_o_escort_orb
    sent_back :ks_o_orb_back, :to => [25, 61], :events => orbs
    watch :self => [13, "A"], :say => :ks_o_water_open
    spot :at => [10, 26], :label => :ks_o_orb_goal, :onto => true, :when => lambda { !$game_self_switches[[106, 13, "A"]] }
    hint :ks_o_water_hint
    active { PokeAccess::Puzzles.assist? && !$game_self_switches[[106, 13, "A"]] }
  end

  mechanic(:state, 105) do
    auto
    obstacle({ :events => spirits }, :moving => true, :label => :ks_o_spirit)
    name pads, :ks_o_launch_pad, :when => lambda { |_ev| $game_switches[107] }
    name plates, :ks_o_floor_plate, :when => lambda { |ev| !$game_self_switches[[105, ev.id, "A"]] }
    count :ks_o_plates_down, :var => 83, :of => 4, :hide_zero => true
    sent_back :ks_o_spirit_back, :to => [8, 40], :events => spirits
    sent_back :ks_o_dream_exit_back, :to => [8, 40], :events => [7]
    sent_back :ks_o_pad_thrown, :events => pads, :forced => true
    hint :ks_o_grass_hint
    active { PokeAccess::Puzzles.assist? && !$game_self_switches[[105, 3, "A"]] }
  end
end
