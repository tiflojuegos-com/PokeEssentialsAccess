# Perseida's Desidia Castle (map 172): four braziers round a lever (EV2 north, EV5 west, EV9 south, EV11 east) each step
# their fire on every use, out, red, blue, purple and out again, kept in V176, V179, V181 and V183. The lever (EV1, drawn
# with S113) opens the north door EV27 and sets S93 when north is blue, west red, south red and east purple, as the slabs
# around the castle hint ("a blue ember in the north"). The braziers and the lever in the map's top-left corner (EV3, EV4,
# EV8, EV10, EV102) belong to an older version of the room and are out of reach.
module PokeAccess
  module PerseidaDesidia
    MAP = 172
    BRAZIERS = [[2, 176, :perseida_desidia_north], [5, 179, :perseida_desidia_west], [9, 181, :perseida_desidia_south],
                [11, 183, :perseida_desidia_east]]
    FIRES = { 0 => :perseida_desidia_out, 1 => :perseida_desidia_red, 2 => :perseida_desidia_blue,
              3 => :perseida_desidia_purple }
    LEFTOVERS = [3, 4, 8, 10, 102]
    OPEN = 93
    ROOM = [58, 78, 4, 22]

    # A brazier's name with the fire it shows.
    def self.label(ev)
      row = BRAZIERS.find { |id, _var, _side| id == ev.id }
      fire = FIRES[$game_variables[row[1]].to_i] || FIRES[0]
      [:perseida_desidia_brazier, { :side => PokeAccess::I18n.t(row[2]), :fire => PokeAccess::I18n.t(fire) }]
    end

    # True while the player stands in the braziers' room and the door is still shut.
    def self.in_room?
      x0, x1, y0, y1 = ROOM
      px = $game_player.x
      py = $game_player.y
      !$game_switches[OPEN] && px >= x0 && px <= x1 && py >= y0 && py <= y1
    end
  end
end

PokeAccess::Game.define("perseida") do
  desidia = PokeAccess::PerseidaDesidia
  mechanic(:state, desidia::MAP) do
    auto
    ids = desidia::BRAZIERS.map { |row| row[0] }
    not_control ids
    hide desidia::LEFTOVERS
    desidia::BRAZIERS.each { |_id, var, side| watch :var => var, :label => side, :words => desidia::FIRES }
    name ids, lambda { |ev| lambda { desidia.label(ev) } }
    hint :perseida_desidia_hint
    active { desidia.in_room? }
    solved(:perseida_desidia_solved) { $game_switches[desidia::OPEN] }
  end
end
