# Royal's Pokedex entry draws the type icons for seen species too, not only for owned ones as the shared reader does.
PokeAccess::Game.define("royal") do
  override("PokeAccess::PokedexInfoV21", :shown_types) do |_mod, _original, args|
    data = args[1]
    types = (data.types rescue nil) || []
    types.map { |t| (GameData::Type.get(t).name rescue t.to_s) }.reject { |n| n.to_s.empty? }
  end
end
