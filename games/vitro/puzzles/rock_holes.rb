# Vitro's boulders that fall (maps 77, the Ice Path's first basement, and 86, Clair's gym): a parallel event per hole waits for its
# boulder on the hole's tile, then turns a switch on, with a sound and the screen shaking and no text. The switch hides the boulder
# and shows a Holed boulder below: on map 78, on the ice, where it stops a slide; on map 86, in the gap, where the touch events the
# same switches turn on hop the player across. The routes read those hops and the boulder as they do any other (Routes::Effects).
# On map 86 one of the first two holes already opens the way to Debora, so its win is the badge (switch 11), not the count.
PokeAccess::Game.define("vitro") do
  [[77, [83, 84, 85, 86], :vitro_rocks_ice, nil], [86, [89, 90, 91], :vitro_rocks_gym, 11]].each do |map, switches, rule, badge|
    fallen = lambda { switches.select { |id| $game_switches[id] }.length }
    mechanic(:state, map) do
      switches.each { |id| watch :switch => id, :label => :vitro_rock, :on => :vitro_rock_fell, :off => :vitro_rock_up }
      info { PokeAccess::I18n.t(:vitro_rocks_fallen, :n => fallen.call, :of => switches.length) }
      solved { badge ? $game_switches[badge] : fallen.call == switches.length }
      arrival_hint rule
    end
  end
end
