# Perseida's crossings (its edited copy of Sea Gallop, 0297_BOAT, with the picture as an argument): pictures with no text,
# said queued as each starts, pbStartScene running the whole of it. In the scene on map 75 Empoleon crosses where the boat
# would.
PokeAccess::Game.define("perseida") do
  before("Seagallop_Scene", :pbStartScene, :optional => true) do |_scene, args|
    PokeAccess.speak(PokeAccess::I18n.t(args.last.to_s == "empoleon" ? :perseida_gallop_empoleon : :dh_gallop_sea), false)
  end
end
