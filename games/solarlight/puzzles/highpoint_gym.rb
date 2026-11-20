# Highpoint's gym (map 134): seven levers ("Switch1" to "Switch7"), each flipping the switch of a stone ("Stone1" to
# "Stone7") that, raised, lets the jump spots on its two sides ("Jump1" to "Jump7") hop the player over it (games/solarlight/
# jumps.rb). Each lever stands on the platform before its stone, so the stones go up in order; switch 8 is the badge.
PokeAccess::Game.define("solarlight") do
  stones = [258, 259, 260, 261, 262, 274, 275]
  levers = { 6 => 1, 5 => 2, 17 => 3, 20 => 4, 21 => 5, 4 => 6, 22 => 7 }
  spots = { 8 => 1, 13 => 1, 9 => 2, 10 => 2, 18 => 3, 19 => 3, 27 => 4, 28 => 4, 11 => 5, 12 => 5, 29 => 6, 30 => 6,
            31 => 7, 32 => 7 }
  next_lever = lambda do
    k = stones.index { |s| !$game_switches[s] }
    k ? [:solar_highpoint_next, { :n => k + 1 }] : :solar_highpoint_amber
  end
  mechanic(:state, 134) do
    levers.each { |id, n| name id, [:solar_highpoint_lever, { :n => n }] }
    spots.each { |id, n| name id, [:solar_highpoint_jump, { :n => n }] }
    stones.each_with_index do |s, i|
      watch :switch => s, :label => [:solar_highpoint_stone, { :n => i + 1 }], :on => :solar_highpoint_up,
            :off => :solar_highpoint_down
    end
    phase lambda { true }, :quiet => true, :hint => next_lever
    solved { $game_switches[8] }
    arrival_hint :solar_highpoint_rule
  end
end
