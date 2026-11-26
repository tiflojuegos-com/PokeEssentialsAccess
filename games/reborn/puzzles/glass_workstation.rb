# Glass Workstation (map 732): four stretches of glass floor drawn on the map, events 52 to 55 at (58,27), (48,27),
# (29,27) and (22,27), have no graphic and break with Rock Smash; the broken one turns its self switch A on and stands as
# a hole down to B2F (map 737). Named as floor that breaks, and as a hole once broken.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 732, :part => :glass) do
    auto
    name 52..55, lambda { |ev|
      broken = $game_self_switches && $game_self_switches[[732, ev.id, "A"]]
      PokeAccess::I18n.t(broken ? :rbc2_glass_hole : :rbc2_glass_floor)
    }
  end
end
