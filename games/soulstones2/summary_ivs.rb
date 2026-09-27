# Soulstones 2's stats page writes each stat's IVs and EVs, said after the stats; outside purist mode the Sp.
# Atk row shows Attack's EVs, which that row trains.
PokeAccess::Game.define("soulstones2") do
  override("PokeAccess::SummaryGameData", :stats_extras) do |mod, original, args|
    ev_sp = (::Settings::PURIST_MODE rescue false) ? :SPECIAL_ATTACK : :ATTACK
    [mod.iv_ev_text(args[0], ev_sp)].compact + original.call
  end
end
