# Mt. Fhenzhu (maps 208 and 209): Strength boulders that fill holes; a parallel check per boulder turns its switch on
# once it lies on any hole (1F: events 6, 7 and 8 for switches 76, 77 and 78; 2F: events 2 and 12 for 79 and 80). The
# three of 1F raise the stones across the lava of 2F, and the two of 2F those of 3F: without all five the way up stays shut.
# The assist gives the pushes of each boulder still out, checked on the map's grid.
module PokeAccess
  module SoulstonesFhenzhu
    # Map => [[switch, hint key], ...] in the order they are best pushed.
    ROCKS = { 208 => [[77, :ss1_fz_rock7], [78, :ss1_fz_rock8], [76, :ss1_fz_rock6]],
              209 => [[79, :ss1_fz_rock2], [80, :ss1_fz_rock12]] }

    # The pushes left on this floor, as one line, or the floor's done line.
    def self.hint
      left = (ROCKS[$game_map.map_id] || []).reject { |sw, _key| $game_switches[sw] }
      return :ss1_fz_done if left.empty?
      PokeAccess.sentences(left.map { |_sw, key| PokeAccess::I18n.t(key) })
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  fz = PokeAccess::SoulstonesFhenzhu

  fz::ROCKS.each do |map, rocks|
    mechanic(:state, map) do
      auto
      rocks.each { |sw, _key| watch :switch => sw, :say => :ss1_fz_filled }
      count :ss1_fz_holes, :switches => rocks.map { |sw, _key| sw }, :assist => true, :hide_zero => true
      hint lambda { fz.hint }
      solved { rocks.all? { |sw, _key| $game_switches[sw] } }
    end
  end
end
