# The region map cursor (core/nav/region_map.rb) speaks when the square under it changes; a nameless square is said
# by its coordinates and takes the dedup key; reopening the map re-reads the square.

Suite.define("region map: a square is read once, and holding still on it says nothing") do
  scene = Object.new
  rm = PokeAccess::RegionMap

  rm.announce(scene, "Pueblo Paleta", 3, 4)
  eq "the square under the cursor is read", SpeakCapture.lines, ["Pueblo Paleta"]
  eq "the opening read waits behind what is being said", SpeakCapture.log[0][1], false

  SpeakCapture.clear
  rm.announce(scene, "Pueblo Paleta", 3, 4)
  rm.announce(scene, "Pueblo Paleta", 3, 4)
  silent "the frames that follow, with the cursor still there, say nothing"

  SpeakCapture.clear
  rm.announce(scene, "Ciudad Verde", 4, 4)
  eq "moving one square across reads the new place", SpeakCapture.lines, ["Ciudad Verde"]
  eq "a cursor move interrupts the previous read", SpeakCapture.log[0][1], true

  SpeakCapture.clear
  rm.announce(scene, "Ciudad Verde", 4, 5)
  eq "the key is the SQUARE, so the same name on another square is read again",
     SpeakCapture.lines, ["Ciudad Verde"]
end

Suite.define("region map: a nameless square is said by its coordinates and consumes the dedup key") do
  scene = Object.new
  rm = PokeAccess::RegionMap

  rm.announce(scene, "Ciudad Verde", 4, 4)
  spoke_once "the named square is read", /Ciudad Verde/

  SpeakCapture.clear
  rm.announce(scene, nil, 5, 4)
  rm.announce(scene, "", 6, 4)
  eq "an unnamed square, and an empty name, by where they are", SpeakCapture.lines,
     [PokeAccess::I18n.t(:brm_square, :x => 5, :y => 4), PokeAccess::I18n.t(:brm_square, :x => 6, :y => 4)]

  SpeakCapture.clear
  rm.announce(scene, "Ciudad Verde", 4, 4)
  eq "coming back over the blank gap re-reads the town (the blank squares took the key)",
     SpeakCapture.lines, ["Ciudad Verde"]

  SpeakCapture.clear
  rm.announce(scene, "Ciudad Verde", 4, 4)
  silent "and once back, it is still deduped normally"
end

Suite.define("region map: the dedup lives on the scene, so reopening the map re-reads the square") do
  scene = Object.new
  rm = PokeAccess::RegionMap

  rm.announce(scene, "Ciudad Plateada", 7, 2)
  SpeakCapture.clear
  rm.announce(scene, "Ciudad Plateada", 7, 2)
  silent "within the same screen the square is not re-read"

  rm.forget(scene)
  rm.announce(scene, "Ciudad Plateada", 7, 2)
  eq "after the forget the map's own open/close performs, the same square is read again",
     SpeakCapture.lines, ["Ciudad Plateada"]

  SpeakCapture.clear
  other = Object.new
  rm.announce(other, "Ciudad Plateada", 7, 2)
  eq "and a second map scene keeps its own state", SpeakCapture.lines, ["Ciudad Plateada"]

  SpeakCapture.clear
  rm.announce(scene, "Ciudad Plateada", 7, 2)
  silent "without ever disturbing the first one's"
end

# The icons the map draws: the fly mark on a visited healing spot while the map is opened to fly, and the
# player's head on the square the map opens on.
Suite.define("region map: the fly mark and the player's square are said with the place") do
  t = PokeAccess::I18n
  rm = PokeAccess::RegionMap
  scene = Object.new
  def scene.pbGetHealingSpot(x, y); (x == 3 && y == 4) ? [7, 1, 1] : nil; end
  scene.instance_variable_set(:@sprites, { "point0" => Struct.new(:visible).new(true), "player" => Object.new })
  had = $PokemonGlobal.respond_to?(:visitedMaps)
  $PokemonGlobal.define_singleton_method(:visitedMaps) { { 7 => true } }
  begin
    SpeakCapture.clear
    rm.announce(scene, "Pueblo Paleta", 3, 4)
    rm.opened(scene)
    eq "the healing spot of a visited town shows the fly mark, and the head drawn once the map is up follows it",
       SpeakCapture.lines, ["Pueblo Paleta, #{t.t(:brm_fly)}", t.t(:rmap_you)]
    rm.announce(scene, "Ruta 1", 3, 5)
    SpeakCapture.clear
    rm.announce(scene, "Pueblo Paleta", 3, 4)
    eq "and coming back to the opening square, the player is there", SpeakCapture.lines,
       ["Pueblo Paleta, #{t.t(:brm_fly)}, #{t.t(:rmap_you)}"]
  ensure
    class << $PokemonGlobal; remove_method :visitedMaps; end unless had
  end
end

# The bar's top line: the region's name, queued, as the map opens; a change with the map up (Arcky's district and
# progress) is said on the next frame, after the place.
Suite.define("region map: the bar's top line opens the map, and a change under the cursor follows the place") do
  ui = PokeAccess::UIV21
  ui.reset(:regionname)
  bar = MapBottomSprite.new
  SpeakCapture.clear
  bar.mapname = "Kanto"
  eq "opening, the region's name is said, queued", SpeakCapture.log, [["Kanto", false]]
  SpeakCapture.clear
  bar.mapname = "Distrito Norte 45%"
  PokeAccess.speak("Ruta 5", true)
  silent_before = SpeakCapture.lines.dup
  PokeAccess::Keys.run_frame_pollers
  eq "a change with the map up is held past the place the same move says", silent_before, ["Ruta 5"]
  eq "and said after it", SpeakCapture.lines, ["Ruta 5", "Distrito Norte 45%"]
  ui.reset(:regionname)
end

# Nothing is said while the map builds (Armonia asks there for a square the pan then shifts); the loop's first square
# carries the player's mark, as the map opens on the player.
Suite.define("region map: a build left unsaid says its first square later, with the player's mark") do
  t = PokeAccess::I18n
  rm = PokeAccess::RegionMap
  scene = Object.new
  scene.instance_variable_set(:@sprites, { "player" => Object.new })
  SpeakCapture.clear
  rm.building do
    rm.announce(scene, "Bosque Lejano", 10, 5)
    MapBottomSprite.new.maplocation = "Bosque Lejano"
  end
  rm.opened(scene)
  silent "nothing is said while the map builds, nor the mark with no square said yet"
  falsy "and the build is over", rm.building?
  rm.announce(scene, "Ruta 7", 10, 6)
  eq "the loop's first square is the player's", SpeakCapture.lines, ["Ruta 7, #{t.t(:rmap_you)}"]
  rm.forget(scene)
end
