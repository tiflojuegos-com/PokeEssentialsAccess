# The Lava Vent (map 244): jets of lava teleport the player back to the last checkpoint, and plugs, once launched, seal the
# outlets of jets 1, 2, 3, 6, 7 and 8. Nothing on the way to the Emperor's Map needs a plug: the jets stay in the corridors
# and walks keep off them. The Tinkerer, who gives the mask that lets the player cross the hot lava at x 30, sits behind an
# unmarked tunnel (events 9 and 10) that carries the player six tiles under the rock; events 19 and 31 are another. An
# autorun event puts every plug back each time the map is entered.
module PokeAccess
  module UraniumLava
    def self.plugs
      {
        30 => :ura_pp_lava_plug_1, 166 => :ura_pp_lava_plug_2, 168 => :ura_pp_lava_plug_3,
        155 => :ura_pp_lava_plug_67, 165 => :ura_pp_lava_plug_8
      }
    end

    # The plug's name, with how it seals its outlet when the puzzle assist is on.
    def self.plug_label(ev)
      return :ura_pp_lava_plug unless PokeAccess::Puzzles.assist? && plugs[ev.id]
      plugs[ev.id]
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 244) do
    auto
    name(/\APlug /, lambda { |ev| PokeAccess::UraniumLava.plug_label(ev) })
    name(/\AOutlet /, :ura_pp_lava_outlet, :when => false)
    name(/\ABlast /, :ura_pp_lava_blast, :when => false)
    avoid(/\ABlast /)
    [[9, :south], [10, :north], [19, :east], [31, :west]].each do |event, way|
      spot :event => event, :label => "ura_pp_lava_tunnel_#{way}".to_sym, :onto => true, :assist => true
    end
    arrival_hint :ura_pp_lava_rule
  end
end
