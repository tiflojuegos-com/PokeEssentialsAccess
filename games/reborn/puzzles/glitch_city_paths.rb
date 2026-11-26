# Glitch City: the false Rocket Hideout (map 448; the way on is the door at (25..26, 15)), Lavender Town (449; only the
# middle door, event 13, goes on) and Mansion (451; a statue, event 13, used facing up, toggles switch 519 and the
# barrier in the middle; the way on is the door at (20, 15) to 452). The statue's page is too long for the core.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 448, :part => :glitch_hideout) do
    auto
    arrival_hint :rbb_glitch_hideout_rule, :once => true
    sent_back :rbb_glitch_hideout_restart, :to => [27, 3], :events => [6]
    sent_back :rbb_glitch_hideout_top, :to => [22, 3], :events => [7]
    sent_back :rbb_glitch_lavender_back, :maps => [449], :to => [25, 14]
    hide [6, 7], :assist => true
    phase lambda { true }, :quiet => true, :hint => :rbb_glitch_hideout_hint, :hidden => right_way(53, 54)
  end
  mechanic(:state, 449, :part => :glitch_lavender) do
    auto
    hide [7, 8, 9, 10], :assist => true
    phase lambda { true }, :quiet => true, :hint => :rbb_glitch_lavender_hint, :hidden => right_way(13)
  end
  mechanic(:state, 451, :part => :glitch_mansion) do
    auto
    watch :switch => 519, :label => :rbf_glitch_gate, :on => :rbf_glitch_gate_open, :off => :rbf_glitch_gate_closed
    controls
    name 13, :rbf_glitch_statue
    right_choice 13, :takes => lambda { $game_switches[519] ? nil : { :switch => 519 } }
    hide [9, 10], :assist => true
    phase lambda { true }, :quiet => true, :hidden => right_way(11),
          :hint => lambda { $game_switches[519] ? :rbb_glitch_mansion_exit_hint : :rbb_glitch_mansion_switch_hint }
  end
end
