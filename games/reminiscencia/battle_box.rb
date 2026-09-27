# Reminiscencia's databox draws every battler's hit points, as numbers or with the game's option a percentage, and
# no level; the HP and info keys say the same.
PokeAccess::Game.define("reminiscencia") do
  override("PokeAccess::Battle", :shown_level) do |_mod, _original, _args|
    nil
  end
  override("PokeAccess::Battle", :shown_hp) do |mod, _original, args|
    b = args[0]
    mod.hp_phrase(b.hp, b.totalhp, ($PokemonSystem.porcentaje == 1 rescue false))
  end
end
