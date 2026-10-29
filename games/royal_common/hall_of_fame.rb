# Royal's copy of the "Hall de la Fama BW" draws no sex sign, in its PC viewer or on its ceremony cards; what the
# cards' bars show past that differs per game and is read by each profile.
PokeAccess::Game.define("royal_common") do
  override("PokeAccess::HallOfFameBW", :sex_suffix) { |_mod, _original, _args| "" }
end
