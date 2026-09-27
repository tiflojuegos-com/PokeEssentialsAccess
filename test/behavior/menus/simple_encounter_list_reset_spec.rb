# The Simple Encounter List reader forgets a list still waiting for its icons when the mod's caches reset (a new map,
# a loaded save), so a window gone before its first frame is never read later.
Suite.define("simple encounter list: a list waiting to be read is forgotten when the caches reset") do
  scene = Object.new
  scene.instance_variable_set(:@encarray, [16, 19])
  scene.instance_variable_set(:@pkmnsprite, [Object.new, Object.new])
  PokeAccess::SimpleEncounterList.filled(scene)
  PokeAccess::Caches.reset_all
  SpeakCapture.clear
  PokeAccess::SimpleEncounterList.poll
  silent "nothing is read on the frame after the reset"
end
