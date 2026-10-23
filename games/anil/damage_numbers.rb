# Anil's damage numbers (its Misc Scripts, shown while the "Mostrar Nº de daño" option is on): the hit points a battler
# loses or gains, painted over it, so the core says a foe's change in hit points too.
PokeAccess::Game.define("anil") do
  override("PokeAccess::Battle", :foe_change_painted?) do |_mod, original, _args|
    ($PokemonSystem.show_damage_numbers? rescue false) || original.call
  end
end
