# Opalo's psychic gym (map 36): a sensor lights the safe path for a step, switch 313 on the way to the leader and 314 north;
# its lights (events named luz) are named while lit, as a sighted player sees them. The leader's door has no condition,
# so the leader's medal (switch 312) ends it: nothing on the info key.
PokeAccess::Game.define("opalo") do
  mechanic(:state, 36) do
    watch :switch => 313, :label => :op_lights,       :on => :op_lights_on, :off => :op_lights_off
    watch :switch => 314, :label => :op_lights_north, :on => :op_lights_on, :off => :op_lights_off
    name(/\Aluz/, :op_light, :when => lambda { |_ev| $game_switches[313] || $game_switches[314] })
    arrival_hint :op_traps_hint
    solved { $game_switches[312] }
  end
end
