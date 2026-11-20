# Opalo's cave of the Gatling base (map 163): the door of (52..54, 8..9), before the way out at (53, 4), opens with the lever
# of map 162 (event 40, switch 334), out of sight from the cave: with the assist, the info key tells where until it is pulled,
# whichever way the cave was entered (from map 162, or from map 157 at (53, 5), past the door).
PokeAccess::Game.define("opalo") do
  mechanic(:state, 163) do
    auto
    obstacle({ :events => 24..29 }, :label => :loc_sign_locked)
    active { PokeAccess::Puzzles.assist? && !$game_switches[334] }
    hint :op_gatling_hint_floor
  end
end
