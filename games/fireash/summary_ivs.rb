# Fire Ash's "EVs and IVs in Summary" plugin: each stat's IVs and EVs after the stats, ahead of other extras.
# Its labels follow the own nature (not a mint's), uncoloured for a Shadow Pokemon at heart stage 3 or below.
PokeAccess::Game.define("fireash") do
  override("PokeAccess::SummaryGameData", :stats_extras) do |mod, original, args|
    [mod.iv_ev_text(args[0])].compact + original.call
  end

  override("PokeAccess::Summary", :stats_nature) do |_mod, _original, args|
    pk = args[0]
    ((pk.shadowPokemon? rescue false) && (pk.heartStage rescue 0).to_i <= 3) ? nil : (pk.nature rescue nil)
  end
end
