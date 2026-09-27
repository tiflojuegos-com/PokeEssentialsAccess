# Infinite Fusion's speed-up key (its edit of Better Fast-forward): in the default Hold mode the game runs fast only
# while the key is held and each press still cycles $GameSpeed, unused; the index is followed only in Toggle mode
# ($PokemonSystem.speedup 1), where it picks the SPEEDUP_STAGES multiplier.
PokeAccess::Game.define("infinitefusion_common") do
  override("PokeAccess::Turbo", :current_speed) do |_mod, original, _args|
    ($PokemonSystem.speedup == 1 rescue false) ? original.call : nil
  end
end
