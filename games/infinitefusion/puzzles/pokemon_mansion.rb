# Pokemon Mansion (maps 173, 174, 181, 187): each secret switch flips switch 285, and with it every gate of the four
# floors, the closed ones opening and the open ones closing.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, [173, 174, 181, 187]) do
    watch :switch => 285, :label => :ifk_mn_switch, :on => :ifk_mn_on, :off => :ifk_mn_off
    controls
    [2696, 2668, 2670, 2692, 2669].each { |tile| obstacle({ :tile => tile }, :label => :ifk_mn_gate) }
    hint :ifk_mn_hint
  end
end
