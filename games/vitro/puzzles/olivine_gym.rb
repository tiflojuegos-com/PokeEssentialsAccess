# Vitro's gym of Olivine (map 97): six buttons, each flipping switch 135 (blocks down while on), and the one in the central chamber
# (event 13) once only, also setting switch 136, which removes two rows of blocks for good. Entering the chamber needs the blocks
# raised, since three of them rise at its north door while 135 is on. With the blocks raised the player is in the entrance rooms,
# in the corridors and chamber past the first blocks, or shut in a zone with a button of its own. Switch 9 is the badge.
PokeAccess::Game.define("vitro") do
  down = lambda { $game_switches[135] ? true : false }
  spent = lambda { $game_switches[136] ? true : false }
  entrance = lambda { $game_player.x >= 6 && $game_player.x <= 16 && $game_player.y >= 39 }
  past_blocks = lambda do
    x = $game_player.x
    y = $game_player.y
    (x >= 4 && x <= 18 && y >= 21 && y <= 29) || (x >= 10 && x <= 12 && y >= 28 && y <= 30)
  end
  hint_up = lambda do
    next :vitro_olivine_lower_hint if spent.call
    next :vitro_olivine_start_hint if entrance.call
    past_blocks.call ? :vitro_olivine_chamber_hint : :vitro_olivine_lower_hint
  end
  mechanic(:state, 97) do
    auto
    name 13, lambda { |ev| PokeAccess::Puzzles.assist? ? :vitro_olivine_button_once : :vitro_olivine_button },
         :when => lambda { |ev| !spent.call }
    name [1, 12, 14, 21, 30], :vitro_olivine_button
    phase down, :title => :vitro_olivine_down, :hint => lambda { spent.call ? :vitro_olivine_free_hint : :vitro_olivine_raise_hint }
    phase lambda { true }, :title => :vitro_olivine_up, :hint => hint_up
    solved { $game_switches[9] }
    arrival_hint :vitro_olivine_rule
  end
end
