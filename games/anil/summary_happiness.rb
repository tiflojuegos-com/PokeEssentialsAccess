# Anil's SV Summary writes the happiness as figures beside the meter (value over maximum), which are what is said.
PokeAccess::Game.define("anil") do
  override("PokeAccess::EnhancedPokemonUI", :happiness_figures?) { |_mod, _original, _args| true }
end
