# Insurgence's soaring maps (games/insurgence/soaring.rb): the place the HUD would name under the player, picked as
# Scene_Map#update picks it, said as the player flies over it. The places are rows of the game's getSoarAreas (map id,
# box, landing spot); the profile's module alone is loaded, the H-Mode7 switch being the Insurgence process's.
unless defined?(PokeAccess::InsurgenceSoaring)
  path = File.join(Harness::ROOT, "games", "insurgence", "soaring.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
end

module InsurgenceSoarSpec
  # Three of getSoarAreas' boxes (maps 2, 43 and 80 in 179_ChallengeChampionship.rb, the last two sharing an edge),
  # given map ids the stubbed MapInfos names.
  TORREN = [[35, 145, 111, 150, 118, 146, 112], [40, 135, 87, 144, 95, 143, 92], [999, 125, 93, 135, 98, 0, 0]]

  # Puts the player on the soaring map at (x, y) with the Torren rows in place of the game's function.
  def self.fly(x, y, map = 676)
    PokeAccess::InsurgenceSoaring.instance_variable_set(:@areas, { 676 => TORREN, 749 => [] })
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
  end
end

Suite.define("insurgence soaring: a place is the first box holding the player strictly inside its edges") do
  s = PokeAccess::InsurgenceSoaring
  a = InsurgenceSoarSpec::TORREN
  eq "inside the first box", s.area_at(a, 146, 112), 35
  eq "on its edge is outside, as the game compares with > and <", s.area_at(a, 145, 112), 0
  eq "the edge two boxes share belongs to neither", s.area_at(a, 135, 94), 0
  eq "open sky", s.area_at(a, 10, 10), 0
  eq "no rows at all", s.area_at(nil, 146, 112), 0
end

Suite.define("insurgence soaring: says each new place once, queued on arrival and interrupting after") do
  s = PokeAccess::InsurgenceSoaring
  s.reset
  InsurgenceSoarSpec.fly(146, 112)
  s.poll
  eq "the first place follows the map's own name, queued", SpeakCapture.log, [["Mapa 35", false]]
  SpeakCapture.clear
  s.poll
  silent "the same place is not said again"
  InsurgenceSoarSpec.fly(10, 10)
  s.poll
  silent "open sky says nothing, as the HUD is blank there"
  InsurgenceSoarSpec.fly(140, 90)
  s.poll
  eq "a new place interrupts, being the player's own movement", SpeakCapture.log, [["Mapa 40", true]]
end

Suite.define("insurgence soaring: quiet off the soaring maps, and it names the place again on coming back") do
  s = PokeAccess::InsurgenceSoaring
  s.reset
  InsurgenceSoarSpec.fly(146, 112)
  s.poll
  InsurgenceSoarSpec.fly(146, 112, 5)
  SpeakCapture.clear
  s.poll
  silent "a map with no soaring rows says nothing"
  InsurgenceSoarSpec.fly(146, 112)
  s.poll
  eq "back on the soaring map, the place under the player again, queued", SpeakCapture.log, [["Mapa 35", false]]
  SpeakCapture.clear
  InsurgenceSoarSpec.fly(146, 112, 749)
  s.poll
  silent "Holon's rows (none here) name nothing over the same tile"
end
