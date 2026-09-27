# Relict's species search (Swdfm's Dynamic Entry Screen, edited): a keyboard entry whose list follows the typed text,
# opened through its own pbStartScene_Dynamic, which says its heading and help as the stock keyboard screen does.
PokeAccess::Game.define("relict") do
  around("PokemonEntryScene", :pbStartScene_Dynamic) do |_s, nxt, args|
    PokeAccess::TextEntry.opening(args) { nxt.call }
  end
end
