# Reborn's Move Tutor app of the Pokegear (MoveTutorScene), read by the engine's MoveTutorRV: each focused move's type,
# PP and party marks follow its name. A container: pbUpdate drives the list, whose reader says the name.
PokeAccess::Game.define("reborn") do
  after("MoveTutorScene", :pbUpdate, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::MoveTutorRV.describe(scene)
  end
end
