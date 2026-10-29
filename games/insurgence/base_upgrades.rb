# Insurgence's shops built by a function, not a scene: the secret base upgrade shop (Kernel.buySecretBaseUpgrades,
# 173_Secret_Base_Code.rb, and pbBuyUpgradesPre, 181_PokemonBaseBuy.rb) and the Sim Depot's ID shops (pbBuyIDs and
# pbBattleIDs, 183_PokemonSimDepot.rb). Each builds and repaints its own "Money:" window, watched while it runs.
PokeAccess::Game.define("insurgence") do
  %w[buySecretBaseUpgrades pbBuyUpgradesPre pbBuyIDs pbBattleIDs].each do |fn|
    kernel(fn, :around) { |_args, nxt| PokeAccess::MoneyWindow.watch { nxt.call } }
  end
end
