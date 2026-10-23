# Infinite Fusion 2's Pokedex search by name (PokedexTextEntry, the action key on the Pokedex list): the stock keyboard
# naming screen copied under its own name, read as that screen is, its caption and what it paints (TextEntry.opening).
PokeAccess::Game.define("infinitefusion_hoenn") do
  around("PokedexTextEntry", :pbStartScene) { |_scene, nxt, args| PokeAccess::TextEntry.opening(args) { nxt.call } }
end
