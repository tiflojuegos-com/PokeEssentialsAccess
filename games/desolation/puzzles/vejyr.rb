# The stone pillars of Inner Vejyr (maps 118 to 123) and of Bountilia Core (maps 403, 404 and 433): pairs of events named
# "Pillar", with no sprite, that Rock Smash breaks (Kernel.pbCheckMove(:ROCKSMASH)); each pair writes one switch, and a
# rock falls into the lava where a shadow ("Shad1", "ShadBount<n>") waits for it, a step for the touch tiles that jump the
# player two tiles. Those jumps and rocks the core routes by itself. The pillars of the side chambers (119 to 122) drop
# their rock in the big cave (118).
module PokeAccess
  module DesolationVejyr
    # The pillars' switches of each zone, for the count with the assist.
    ZONES = { 118 => (172..180).to_a, 119 => (172..180).to_a, 120 => (172..180).to_a, 121 => (172..180).to_a,
              122 => (172..180).to_a, 123 => [181, 182], 403 => (744..750).to_a, 404 => (744..750).to_a,
              433 => (744..750).to_a }

    # True for a shadow still waiting for its rock.
    def self.shadow?(ev)
      ev.character_name.to_s == "shadow"
    end
  end
end

PokeAccess::Game.define("desolation") do
  vejyr = PokeAccess::DesolationVejyr
  vejyr::ZONES.each do |map, switches|
    mechanic(:state, map) do
      auto
      switches.each { |s| watch :switch => s, :quiet => true }
      controls
      name(/\APillar\z/, :deso_vejyr_pillar, :grouped => true)
      name(/\AShad/, lambda { |ev| vejyr.shadow?(ev) ? :deso_vejyr_shadow : nil }, :when => lambda { |ev| vejyr.shadow?(ev) })
      count :deso_vejyr_pillars, :switches => switches, :assist => true
      arrival_hint :deso_vejyr_rule, :once => true
      hint :deso_vejyr_hint
      solved { switches.all? { |s| $game_switches[s] } }
    end
  end
end
