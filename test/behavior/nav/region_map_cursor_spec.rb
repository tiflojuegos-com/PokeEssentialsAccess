# The region map cursor reader (core/nav/region_map.rb), which had no assertions after being migrated from
# its own hand-rolled ivar to the shared Cursor primitive with the SCENE as the dedup holder.
#
# The engine calls pbGetMapLocation on every frame the map is drawn, so the reader must speak only when the
# square under the cursor changes -- otherwise holding a direction repeats the same town continuously. Two
# details are easy to break and are what this file exists for:
#
#   - the dedup key is the SQUARE, not the name. A region map is mostly blank sea and empty land, and those
#     squares have no name, so they say nothing -- but they must still CONSUME the key. If a nameless square
#     were skipped, the key would still hold the last named square and crossing the blank gap back to it
#     would stay silent, i.e. the player would lose the town they just came from.
#   - the state hangs on the scene instance and pbStartScene resets it, so reopening the map re-reads the
#     square the cursor sits on instead of assuming the player still remembers it.

Suite.define("region map: a square is read once, and holding still on it says nothing") do
  scene = Object.new
  rm = PokeAccess::RegionMap

  rm.announce(scene, "Pueblo Paleta", 3, 4)
  eq "the square under the cursor is read", SpeakCapture.lines, ["Pueblo Paleta"]
  eq "a cursor move interrupts the previous read", SpeakCapture.log[0][1], true

  SpeakCapture.clear
  rm.announce(scene, "Pueblo Paleta", 3, 4)
  rm.announce(scene, "Pueblo Paleta", 3, 4)
  silent "the frames that follow, with the cursor still there, say nothing"

  SpeakCapture.clear
  rm.announce(scene, "Ciudad Verde", 4, 4)
  eq "moving one square across reads the new place", SpeakCapture.lines, ["Ciudad Verde"]

  SpeakCapture.clear
  rm.announce(scene, "Ciudad Verde", 4, 5)
  eq "the key is the SQUARE, so the same name on another square is read again",
     SpeakCapture.lines, ["Ciudad Verde"]
end

Suite.define("region map: a nameless square is silent but still consumes the dedup key") do
  scene = Object.new
  rm = PokeAccess::RegionMap

  rm.announce(scene, "Ciudad Verde", 4, 4)
  spoke_once "the named square is read", /Ciudad Verde/

  SpeakCapture.clear
  rm.announce(scene, nil, 5, 4)
  silent "an unnamed square says nothing"
  rm.announce(scene, "", 6, 4)
  silent "and neither does an empty name"

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

  # forget is what pbStartScene and pbEndScene call. Resetting the Cursor slot by hand here (which is what
  # this used to do) tested the primitive and left the method that has to call it uncovered.
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
