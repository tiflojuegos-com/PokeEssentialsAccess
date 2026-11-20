# The five elemental temples (maps 100, 101, 157, 277 and 278, one layout): the stone set on the pillar (event 2, faced from
# below) opens the door only with a Pokemon of the temple's type in the party; set without one, it has to be taken back and
# set again. Each temple's switch is its door open.
PokeAccess::Game.define("solarlight") do
  [[100, 761, :solar_temple_hint_ground], [101, 763, :solar_temple_hint_electric], [157, 765, :solar_temple_hint_fire],
   [277, 767, :solar_temple_hint_flying], [278, 769, :solar_temple_hint_water]].each do |map, door, hint|
    mechanic(:state, map) do
      auto
      name 2, :solar_temple_pillar
      phase lambda { true }, :quiet => true, :hint => hint
      solved { $game_switches[door] }
    end
  end
end
