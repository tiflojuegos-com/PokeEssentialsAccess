# The tides of the postgame: "Tide" events that carry the player one or two tiles when stepped on. In the Sacred Lighthouse
# (maps 229 and 238) and under Route 10 (map 255), with the Tidal Bell in the bag each carry flips the tide's self switch
# A, and with it the way it runs; on Route 19 (map 221) the tides turn right with the story (switch 326, variable 131).
# Each is named by the way it runs now, from its live page: the first without conditions, the second with them.
module PokeAccess
  module UraniumTides
    # Each map's tides and the way they run on their first page and on their second.
    def self.ways
      { 229 => [[40], [4, 6]], 238 => [[25, 27], [4, 6]], 255 => [[46], [6, 4]] }
    end

    def self.second_page?(ev)
      page = PokeAccess.ivar(ev, :@page)
      c = page && page.condition
      c ? (c.switch1_valid || c.variable_valid || c.self_switch_valid) : false
    end

    def self.label(ev, first, second)
      (second_page?(ev) ? second : first) == 4 ? :ura_r3_tide_left : :ura_r3_tide_right
    end
  end
end

PokeAccess::Game.define("uranium") do
  PokeAccess::UraniumTides.ways.each do |map, entry|
    ids, way = entry
    mechanic(:state, map, :part => :tides) do
      auto
      name ids, lambda { |ev| PokeAccess::UraniumTides.label(ev, way[0], way[1]) }
      ids.each do |id|
        watch :self => [id, "A"], :label => :ura_r3_tide, :on => (way[1] == 4 ? :ura_r3_left : :ura_r3_right),
              :off => (way[0] == 4 ? :ura_r3_left : :ura_r3_right)
      end
      hint(map == 255 ? :ura_r3_tide_bell_255 : :ura_r3_tide_bell)
    end
  end

  mechanic(:state, 221, :part => :tides) do
    auto
    name(/\ATide\z/, lambda { |ev| PokeAccess::UraniumTides.label(ev, 4, 6) })
  end
end
