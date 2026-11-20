# Road of Ascension (map 179): four touch events with no graphic carry the player over a gap on the dragon the rival's
# choice left them. Facing up on (28, 39) lands on (28, 28) and facing up on (28, 12) on (28, 2); facing down on (28, 28) and
# (28, 2) goes back. The gap has no other way across; the first pair answers to switches 73 and 74 (Reshiram, Zekrom), the
# second to 76 and 77 (Glastrier, Spectrier).
PokeAccess::Game.define("keishou") do
  jumps = { 9 => [:ks_o_jump_up, 11], 10 => [:ks_o_jump_down, 11], 19 => [:ks_o_jump_up, 10], 20 => [:ks_o_jump_down, 10] }
  rides = lambda do |ev|
    switches = ev.id <= 10 ? [73, 74] : [76, 77]
    switches.any? { |id| $game_switches[id] }
  end
  mechanic(:state, 179) do
    auto
    name jumps.keys, lambda { |ev|
      key, tiles = jumps[ev.id]
      PokeAccess::Puzzles.assist? ? [key, { :n => tiles }] : :ks_o_jump
    }, :when => rides
    sent_back :ks_o_jump_landed, :events => jumps.keys, :forced => true
  end
end
