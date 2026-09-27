# Royal's copy of the "Hall de la Fama BW" viewer draws the species bar as name and type icons with no sex sign, and
# no sign in its PC viewer either: the shared reader says the types after the species, and never the sex.
PokeAccess::Game.define("royal") do
  override("PokeAccess::HallOfFameBW", :sex_suffix) { |_mod, _original, _args| "" }

  override("PokeAccess::HallOfFameBW", :species_bar) do |_mod, _original, args|
    pk, sp = args
    types = PokeAccess::Data.pokemon_types(pk)
    types.empty? ? sp.to_s : "#{sp}, #{PokeAccess::I18n.t(:mv_type, :t => types.join('/'))}"
  end
end
