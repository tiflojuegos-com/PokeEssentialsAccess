# Viridian City Gym (map 85): floor arrows are events that set switch 978 and var 200 (1 right, 2 left, 3 down, 4 up); a
# common event then slides the player that way until an invisible event turns the switch off. Routes keep off the
# arrows, and each one says where it slides as it is stepped on. The rule is said until Giovanni is beaten (switch 11).
PokeAccess::Game.define("infinitefusion") do
  arrows = { :left => [8, 9, 36], :right => [5, 13, 14], :up => [6, 10, 11], :down => [7, 12, 16, 17, 41, 42] }
  mechanic(:state, 85) do
    arrows.each do |way, ids|
      name ids, "ifk_va_arrow_#{way}".to_sym
      on_use ids, "ifk_va_slide_#{way}".to_sym
      avoid ids
    end
    arrival_hint :ifk_va_rule
    solved { $game_switches[11] }
  end
end
