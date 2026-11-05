# Opalo's boulders that fill a hole (map 166, Parque Boreal, and 206, Ruta 13): with the Strength gloves (switch 165) the boulder's page
# moves it into the hole and turns a switch on, and the hole, filled, lets the player through. Declaring them so has the assisted routes
# work the boulder on the way past the hole.
PokeAccess::Game.define("opalo") do
  [[166, 361, 7], [206, 415, 1]].each do |map, filled, boulder|
    mechanic(:state, map) do
      auto
      watch :switch => filled, :quiet => true
      controls
      obstacle(/\Aagujero/, :label => :op_hole)
      name boulder, :op_hole_rock
    end
  end
end
