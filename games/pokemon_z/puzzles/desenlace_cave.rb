# Cueva Desenlace (map 303): the braille inscription (event 47, picture_cues.rb) points to the stone in the south-east
# corner of its room; the action event on it (48), with no graphic or text, sets 564 with a tremor and Regirock (event
# 46) appears. With the assist, the info key in that room says to press it.
PokeAccess::Game.define("pokemon_z") do
  room = at(66, 84, 4, 17)
  mechanic(:state, 303) do
    auto
    name 48, :z_regirock_stone
    active { PokeAccess::Puzzles.assist? && !$game_switches[564] && room.call }
    hint :z_regirock_hint
  end
end
