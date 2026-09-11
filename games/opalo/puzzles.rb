# Opalo gym (map 46, "Gimnasio Pokemon"): two three-tile machines and two levers, all silent about what they
# did; everything below was read out of Data/Map046.rxdata. The machines at (5..7,9) and (36..38,8) set 178
# (Water2) if 174 is already on, else 174 (Fire5), then their own guard switch (243, 244), so each works
# ONCE and nothing turns any of the four back off: three states, passed one way, which is why 178 is watched
# as well as 174. No obstacles: the "Humo" events are through=true and the tile-graphic events use passable
# tiles. No :solved: the door to the leader at (24,8) has no switch condition.
PokeAccess::Game.define("opalo") do
  puzzle(46,
    :kind => :state,
    :watch => [
      { :switch => 174, :label => :op_machine,  :on => :op_on, :off => :op_off },
      { :switch => 178, :label => :op_machine2, :on => :op_on, :off => :op_off },
      { :switch => 175, :label => :op_lever1,   :on => :op_on, :off => :op_off },
      { :switch => 177, :label => :op_lever2,   :on => :op_on, :off => :op_off }
    ])
end
