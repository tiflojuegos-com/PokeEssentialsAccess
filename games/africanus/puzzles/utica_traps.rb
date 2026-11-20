# Utica's ruins (maps 52 to 54): plates on the floor, the events named "#EOT SHOW", shoot an arrow across the corridor
# when stepped on, make the player hop a tile and poison a Pokemon at random. Shown only through the panic amulet
# (0224_Amuleto panico), they are named, and kept off by the walks while there is another way, with the puzzle assist
# alone; the arrows, drawn only while they fly, stay out of the lists.
PokeAccess::Game.define("africanus") do
  [52, 53, 54].each do |map|
    mechanic(:state, map) do
      auto
      name(/EOT SHOW/, :af_arrow_plate, :assist => true)
      avoid(/EOT SHOW/, :assist => true)
      hide(/\Aflecha/i)
    end
  end
end
