# Barco "La Tarasque" (5th gym, maps 143-145): two gold valves (switches 312, 313) open the command room;
# coloured cranks (vars 132 red, 133 green, 134 blue) toggle the steam jets in the way. The steam jets ("humo")
# are walls, all drawn alike; the Sharpedo are moving traps that send the player back to the deck's entrance.
PokeAccess::Game.define("pokemon_z") do
  mechanic(:state, [143, 144, 145]) do
    watch :var => 132, :label => :ship_crank_red,   :on => :ship_crank_on, :off => :ship_crank_off
    watch :var => 133, :label => :ship_crank_green, :on => :ship_crank_on, :off => :ship_crank_off
    watch :var => 134, :label => :ship_crank_blue,  :on => :ship_crank_on, :off => :ship_crank_off
    watch :switch => 312, :label => :ship_valve1, :on => :ship_valve_on, :off => :ship_valve_off
    watch :switch => 313, :label => :ship_valve2, :on => :ship_valve_on, :off => :ship_valve_off
    controls
    obstacle(/humo/i, :label => :ship_steam)
    obstacle(/sharpedo/i, :moving => true)
    solved(:ship_solved) { $game_switches[312] && $game_switches[313] }
    hint :ship_hint
  end

  # A Sharpedo of the middle deck (map 144, events "sharpedoGym") that touches the player sends them back to the deck's
  # entrance (4, 8) with no message: a teleport there from beside one is said as its doing.
  PokeAccess::Locator.teleport_cause(:z_ship_sharpedo) do |from, to|
    sharks = to == [4, 8, 144] ? PokeAccess::World::Mechanics.pieces(:obstacle).select { |p| p.moving } : []
    touched = sharks.any? { |p| (p.ev.x - from[0]).abs + (p.ev.y - from[1]).abs <= 1 }
    touched ? PokeAccess::I18n.t(:ship_sharpedo_back) : nil
  end
end
