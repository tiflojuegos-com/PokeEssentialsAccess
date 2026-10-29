# Grueling Gold's mission reminder (Mission_Overlay, its own): the main quest's current stage, written at the top of
# the map for five steps after Continue and as the story moves on, said queued as its window writes it.
PokeAccess::Game.define("gruelinggold") do
  read_on_open("Mission_Overlay", :pbShow) do |overlay|
    (PokeAccess.sprite(overlay, "descwindow").text rescue nil)
  end
end
