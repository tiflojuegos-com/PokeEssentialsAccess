# Granite Cave's floor holes: touch events calling floorHole(<map below>), declared as transfers so routes do not
# cross them and the locator lists them as ways down.
PokeAccess::Game.define("infinitefusion_hoenn") do
  transfer_script(/\bfloorHole\(\s*(\d+)/)
end
