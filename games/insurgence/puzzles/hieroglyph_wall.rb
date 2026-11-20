# Holon Pyramid 1F (maps 448 and 546): the hieroglyph wall (events 14 to 21, two rows of tiles) and the sealed door among them
# (event 12, at 44,22) share the common event 56, a stone keyboard that asks a word, "sekhmet", only when faced upward.
# Switch 518 turns on switch 519, which opens the door to map 449 and leaves event 12 its own name.
PokeAccess::Game.define("insurgence") do
  wall = [12, 14, 15, 16, 17, 18, 19, 20, 21]
  label = lambda { |ev| ev.id == 12 && $game_switches[519] ? nil : :ins_u1_pyramid_wall }
  listed = lambda { |ev| !(ev.id == 12 && $game_switches[519]) }
  word = lambda do |_ev|
    $game_switches[518] || $game_player.direction != 8 ? "" : [:puzzle_answer, { :a => "sekhmet" }]
  end
  [448, 546].each do |map|
    mechanic(:state, map) do
      auto
      name wall, label, :grouped => true, :when => listed
      on_use wall, word, :assist => true
      active { !$game_switches[519] }
      solved(nil, :quiet => true) { $game_switches[519] }
    end
  end
end
