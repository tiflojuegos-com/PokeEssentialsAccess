# The Forsaken Laboratory's two password terminals (map 403): graphic-less computers (events 39 and 44) used facing them
# from below; Mosely reads each password aloud just before. Their pages empty once accepted.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 403, :part => :terminals) do
    auto
    name [39, 44], :rj_lab_terminal
  end
end
