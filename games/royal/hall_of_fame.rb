# Royal's ceremony card draws its species bar as the name and type icons: the shared reader says the types after the
# species (royal_common leaves the sex out).
PokeAccess::Game.define("royal") do
  override("PokeAccess::HallOfFameBW", :species_bar) do |_mod, _original, args|
    pk, sp = args
    types = PokeAccess::Data.pokemon_types(pk)
    types.empty? ? sp.to_s : "#{sp}, #{PokeAccess::I18n.t(:mv_type, :t => types.join('/'))}"
  end
end
