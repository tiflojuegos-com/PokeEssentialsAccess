# Perseida's gym of Cetus (maps 91 and 105): walls of three colors (events Rojo, Azul and Amarillo) open with their switch (129
# red, 130 blue, 131 yellow, one on at a time), which Karliah turns on when asked at the invisible events along the wall
# between the lanes (common events 52, 53 and 54). V64 counts the rooms crossed; map 91 holds rooms 1 and 2, told apart by x.
# It names the walls and those events, says the switch on and, with the assist, gives a solution for each room. The leader's
# medal (switch 7) ends the rooms' rule on arriving and their line on the info key.
module PokeAccess
  module PerseidaCetus
    SWITCHES = [[129, :perseida_cetus_red_on], [130, :perseida_cetus_blue_on], [131, :perseida_cetus_yellow_on]]
    COLORS = [[129, :perseida_cetus_red], [130, :perseida_cetus_blue], [131, :perseida_cetus_yellow]]
    SPOTS = { 91 => [33, 45, 50, 51, 52, 53, 54, 55, 75] + (57..70).to_a,
              105 => [4, 5, 88, 89, 91, 92, 93, 95, 96, 97, 99] }
    ROOMS = [[1, 91, :perseida_cetus_hint1], [2, 91, :perseida_cetus_hint2], [3, 105, :perseida_cetus_hint3]]
    PROGRESS = 64
    SECOND_ROOM_X = 12
    BEATEN = 7

    # True while the player is in room n of its map and has not crossed it yet.
    def self.in_room?(n, map)
      return false unless $game_map.map_id == map && $game_variables[PROGRESS].to_i < n
      return true if map != 91
      (n == 1) == ($game_player.x < SECOND_ROOM_X)
    end

    # The room's title with the switch that is on.
    def self.title(n)
      hit = COLORS.find { |switch, _key| $game_switches[switch] }
      [:perseida_cetus_title, { :n => n, :color => PokeAccess::I18n.t(hit ? hit[1] : :perseida_cetus_none) }]
    end
  end
end

PokeAccess::Game.define("perseida") do
  cetus = PokeAccess::PerseidaCetus
  mechanic(:state, [91, 105], :part => :switches) do
    auto
    cetus::SWITCHES.each { |switch, said| watch :switch => switch, :say => said }
    active { false }
  end
  cetus::SPOTS.each do |map, spots|
    mechanic(:state, map, :part => :rooms) do
      auto
      obstacle({ :named => /\ARojo\z/ }, :label => :perseida_cetus_wall_red)
      obstacle({ :named => /\AAzul\z/ }, :label => :perseida_cetus_wall_blue)
      obstacle({ :named => /\AAmarillo\z/ }, :label => :perseida_cetus_wall_yellow)
      name spots, :perseida_cetus_karliah
      cetus::ROOMS.select { |_n, room_map, _hint| room_map == map }.each do |n, _room_map, hint|
        phase lambda { cetus.in_room?(n, map) }, :quiet => true, :title => lambda { cetus.title(n) }, :hint => hint
      end
      arrival_hint :perseida_cetus_rule
      solved { $game_switches[cetus::BEATEN] }
    end
  end
end
