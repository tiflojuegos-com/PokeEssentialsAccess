# The edited DBK Raid Battles' scripted battle speaker and evolution in battle, read as plugins/dbk_battle.rb reads
# the kit's own (that reader stays out: this copy lacks its probe). While the name window over a scripted line shows,
# its name leads the next line said; the evolution's box is read while it runs.
PokeAccess::Game.define("soulstones2") do
  after("Battle::Scene", :pbUpdateSpeakerWindows, :optional => true) do |scene, _r, _a|
    PokeAccess.lead_with_name_window(PokeAccess.sprite(scene, "nameWindow"))
  end

  around("PokemonEvolutionScene", :pbBattleEvolution, :optional => true) do |scene, nxt, _a|
    PokeAccess::EvolutionText.open(scene)
    begin
      nxt.call
    ensure
      PokeAccess::EvolutionText.close
    end
  end
end
