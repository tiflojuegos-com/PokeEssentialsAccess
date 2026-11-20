# Vitro's Hidden Tower (Torre Oculta, map 132): Kyogre (event 1) and Groudon (event 2), both named Shaymin in the editor, turn
# switches 148 and 149 on when caught; a win without the catch only erases them until the map is entered again. With both on,
# Rayquaza (event 3) appears in the middle room and two of the warp tiles (events 4 and 7) lead beside it instead of below,
# which the routes read from the pages. Each is named by its sprite; with the assist, what brings Rayquaza out.
PokeAccess::Game.define("vitro") do
  mechanic(:state, 132) do
    auto
    name [1, 2, 3], lambda { |ev| PokeAccess::Locator.sprite_species(ev.character_name) }, :when => false
    active { PokeAccess::Puzzles.assist? && !($game_switches[148] && $game_switches[149]) }
    info { :vitro_tower_hint }
  end
end
