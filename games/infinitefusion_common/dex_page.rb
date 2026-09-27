# Infinite Fusion's fifth summary page opens the species' Pokedex entry and returns to page four, so that draw
# is read as the page the scene is back on, not as the vanilla ribbons page.
PokeAccess::Game.define("infinitefusion_common") do
  override("PokeAccess::SummaryV21", :speak_page) do |_mod, original, args|
    if args[1] == 5
      PokeAccess::Summary.forget_page(args[0])
      args[1] = PokeAccess.ivar(args[0], :@page)
    end
    original.call
  end
end
