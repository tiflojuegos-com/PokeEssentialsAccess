# Serenity's photos with the dagger (switch 478): three floor tiles with no sprite ask to take a picture as they are stepped
# on, each ending in a fight and a photo: Keneph Jungle (map 88, event 22), Weeping Hill (map 109, event 11) and Vejyr
# Sanctum (map 125, event 13). Nothing marks them on screen, so they are listed with the assist alone. The mural of the
# Temple to Arceus (map 246, event 12) asks the same while switch 653 is on.
module PokeAccess
  module DesolationSerenity
    SPOTS = { 88 => 22, 109 => 11, 125 => 13 }
  end
end

PokeAccess::Game.define("desolation") do
  PokeAccess::DesolationSerenity::SPOTS.each do |map, ev|
    mechanic(:state, map, :part => :photo) do
      auto
      spot(:event => ev, :label => :deso_photo_spot, :assist => true, :onto => true,
           :when => lambda { $game_switches[478] && !$game_self_switches[[map, ev, "A"]] })
    end
  end
  mechanic(:state, 246, :part => :photo) do
    auto
    name 12, :deso_photo_mural, :when => lambda { |_ev| $game_switches[653] && !$game_switches[654] }
  end
end
