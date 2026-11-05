# Antigua Forja (map 318): the crystals either side of the structure that bars the way, drawn tiles of events 69 and 70,
# light by an autorun's scene as the player comes back from the memory (switches 546, 547, turned on elsewhere) of a druid
# statue on map 319, the last self switch of each in that scene; both lit move the guardian.
PokeAccess::Game.define("pokemon_z") do
  mechanic(:state, 318) do
    watch :self => [69, "C"], :label => :z_forge_left, :on => :z_forge_lit, :off => :z_forge_unlit
    watch :self => [70, "C"], :label => :z_forge_right, :on => :z_forge_lit, :off => :z_forge_unlit
    solved(nil, :quiet => true) { $game_self_switches[[318, 69, "C"]] && $game_self_switches[[318, 70, "C"]] }
    hint :z_forge_hint
  end
end
