# Ice Mountains Peak (map 694): blowing the Azure Flute at the circle (event 1, switch 469) raises a stair of tiles
# (events 6 to 24, switch 521) up to the Hall of Origin. The circle is named by the flute only with the assist, and the
# hint stops once the stair stands.
PokeAccess::Game.define("infinitefusion") do
  flute = lambda { PokeAccess::Data.item_name(:AZUREFLUTE).to_s }
  stair = lambda { $game_switches[521] }

  mechanic(:state, 694) do
    auto
    name 1, lambda { |_ev| PokeAccess::Puzzles.assist? ? [:ifp_azure_circle, { :item => flute.call }] : :ifp_circle }
    watch :switch => 521, :say => :ifp_azure_stairs
    hint lambda { stair.call ? nil : [:ifp_azure_hint, { :item => flute.call }] }
  end
end
