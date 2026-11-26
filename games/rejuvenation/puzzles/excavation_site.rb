# The Terajuma Excavation Site (map 183): six black shard rocks, each with a night page; only 6 at (31,37) and 9 at
# (46,19) step away from the player on it, so they move only at night. The assist names the two.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 183, :part => :night_rocks) do
    auto
    name [6, 9], :rj_night_rock, :assist => true
    active { PokeAccess::Puzzles.assist? }
    hint :rj_night_rock_hint
  end
end
