# Grand Stairway B2F (map 179), the guide's Crystal Cavern: of the ways down its one-way ledges from the stairs of 48,7,
# only the one to the stairs of event 7 goes on; the others end back at the start or by a Lunatone out of reach.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 179) do
    auto
    name 7, :rba_cc_way_on, :assist => true
    hint :rba_cc_hint
  end
end
