# Regression: the map name was spammed forever by a cache/event loop (the :map_changed reset cleared
# @last_map_id, which made announce_map_change see a change again next frame). It must announce ONCE per
# real map change, and again only when the map id actually changes.
Suite.define("field: map name announced once per map, not spammed") do
  $game_map.map_id = 35
  PokeAccess::Locator.forget_map
  10.times { PokeAccess::Locator.announce_map_change }
  spoke_once "same map announced exactly once over 10 frames", /Mapa 35/

  SpeakCapture.clear
  $game_map.map_id = 40
  5.times { PokeAccess::Locator.announce_map_change }
  spoke_once "new map announced once after the id changes", /Mapa 40/
end

# The stub MapInfos only carries the ids the specs visit, so the no-entry path is reachable: an id with no
# MapInfos row (and no persisted override) must yield nil, never a fabricated name.
Suite.define("field: map_name of an unknown id falls back to nil") do
  eq "unknown map id has no name", PokeAccess::Locator.map_name(999999), nil
  eq "a known id still resolves from MapInfos", PokeAccess::Locator.map_name(35), "Mapa 35"
end

# Loading a save can land on the very map the player was already on, and then the id has not changed. That
# is not only a missing announcement: announce_map_change is the ONLY trigger for :map_changed, so no cache
# was reset either and the previous run's emitters and targets carried over.
#
# This used to be papered over by the load screens calling forget_map -- and the spec called it BY HAND, so
# the wiring was never what got tested. Only the two classic screens ever did it; v22 loads through
# UI::LoadVisuals and nobody called it there. What actually identifies a load is that $game_map is a new
# object, which is what these drive.
Suite.define("field: loading re-announces even on the same map") do
  PokeAccess::Locator.forget_map
  $game_map.map_id = 35
  PokeAccess::Locator.announce_map_change
  spoke "map announced on entry", /Mapa 35/

  SpeakCapture.clear
  3.times { PokeAccess::Locator.announce_map_change }
  silent "standing still on it says nothing more"

  # A load: same id, rebuilt object. No load screen is involved, which is the point. The probe rides on the
  # cache registry rather than the event bus so the whole chain is driven -- announce -> :map_changed ->
  # Caches.reset_all -> this reset -- and because registering the same name twice replaces it, the spec can
  # take its own probe back out and not leak into later suites.
  SpeakCapture.clear
  reset_runs = 0
  PokeAccess::Caches.register(:spec_load_probe) { reset_runs += 1 }
  begin
    $game_map = $game_map.dup
    PokeAccess::Locator.announce_map_change
    spoke "a rebuilt $game_map on the same id is a load, and it is announced", /Mapa 35/
    eq "and every cache was reset with it", reset_runs, 1
    SpeakCapture.clear
    PokeAccess::Locator.announce_map_change
    silent "the frame after the load is quiet again"
    eq "and nothing was reset a second time", reset_runs, 1
  ensure
    PokeAccess::Caches.register(:spec_load_probe) { }
  end

  SpeakCapture.clear
  PokeAccess::Locator.forget_map
  PokeAccess::Locator.announce_map_change
  spoke "forget_map still works for the classic screens that call it", /Mapa 35/
end
