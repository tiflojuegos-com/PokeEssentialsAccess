# Opalo's gym (map 46; switches from Data/Map046.rxdata): two machines and two levers (175, 177). A machine
# sets 174, or 178 once 174 is on, and nothing turns them off. No :solved: the leader's door has no condition.
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
