# Viridian's gym (map 182): floor tiles with no sprite carry the player several tiles in a line, and the leader's door, in
# two halves, opens only with the red key (S226) and the blue key (S227) in the bag, which sets S228. The routes already
# follow the carrying tiles; this names the keys and the door and counts the keys.
PokeAccess::Game.define("anil") do
  mechanic(:state, 182) do
    auto
    name 8, :anil_key_red
    name 9, :anil_key_blue
    name [16, 20], :anil_two_key_door
    count :anil_keys, :switches => [226, 227]
    solved(nil) { $game_switches[228] }
    arrival_hint :anil_slide_rule
  end
end
