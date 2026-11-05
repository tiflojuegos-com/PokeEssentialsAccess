# What Keishou's BW Summary Screen writes beside the stats (SHOW_EV_IV is on): each stat's IVs and EVs.
PokeAccess::Game.define("keishou") do
  override("PokeAccess::SummaryGameData", :stats_extras) do |mod, original, args|
    [mod.iv_ev_text(args[0])].compact + original.call
  end
end
