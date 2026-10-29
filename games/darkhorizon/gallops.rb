# Dark Horizon's crossings, picture-only cutscenes with no text: the boat over the sea (its edited copy of Sea Gallop,
# after a trip on the world map), the motorbike over the desert, alone or with a passenger (Bike Gallop, after a trip
# on the bike map; pbStartScene's second argument), and the submarine under the sea (Submarine Gallop, map events).
# Each is said briefly, queued, as it starts: pbStartScene runs the whole crossing before it returns.
PokeAccess::Game.define("darkhorizon") do
  read_on_open("Seagallop_Scene", :pbStartScene, :timing => :before) { |_scene| PokeAccess::I18n.t(:dh_gallop_sea) }
  read_on_open("SubmarineGallop_Scene", :pbStartScene, :timing => :before) { |_scene| PokeAccess::I18n.t(:dh_gallop_sub) }

  before("Bikegallop_Scene", :pbStartScene) do |_scene, args|
    PokeAccess.speak(PokeAccess::I18n.t(args[1] ? :dh_gallop_bike_duo : :dh_gallop_bike), false)
  end
end
