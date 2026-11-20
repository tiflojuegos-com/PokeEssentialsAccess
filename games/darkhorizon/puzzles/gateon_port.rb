# Gateon Port (map 138): two bridges that turn. The first (events 1 to 70) is horizontal on switch 181, x 29 to 40, and vertical on
# switch 182, y 13 to 24, turned by levers 164, 165 and 169 and by the sensor at its middle (event 71); the second (events 73 to
# 102) points north on switch 184, y 13 to 17, and south on switch 185, y 20 to 24, turned by levers 166 and 167 and by its sensor
# (event 72). The way to the east side is the second to the south and the first horizontal. The bridge pieces drawn on the
# way only rearm the sensors as they are walked over, so they are no controls.
PokeAccess::Game.define("darkhorizon") do
  mechanic(:state, 138) do
    auto
    not_control [1, 2, 12, 13, 19, 20, 21, 22, 73, 74, 83, 84]
    name [164, 165, 169], :dh_o_lever_one
    name [166, 167], :dh_o_lever_two
    name 71, :dh_o_sensor_one
    name 72, :dh_o_sensor_two
    watch :switch => 181, :say => :dh_o_bridge_one_horizontal
    watch :switch => 182, :say => :dh_o_bridge_one_vertical
    watch :switch => 184, :say => :dh_o_bridge_two_north
    watch :switch => 185, :say => :dh_o_bridge_two_south
    arrival_hint :dh_o_bridges_rule, :once => true
    hint :dh_o_bridges_hint
  end
end
