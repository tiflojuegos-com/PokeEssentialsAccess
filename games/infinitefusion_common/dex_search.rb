# Infinite Fusion's Pokedex search by name (PokedexTextEntry, the action key on the Pokedex list): the stock keyboard
# naming screen copied under its own name, read as that screen is, its caption and what it paints (TextEntry.opening).
PokeAccess::Game.define("infinitefusion_common") do
  around("PokedexTextEntry", :pbStartScene) { |_scene, nxt, args| PokeAccess::TextEntry.opening(args) { nxt.call } }
end
