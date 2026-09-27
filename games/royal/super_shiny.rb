# Royal's copy of the DBK battler panel draws the purple star (shiny_ur) for a super shiny, as its party and summary
# do, so the panel's shiny word is the party's, which skyflyer_common tells apart.
PokeAccess::Game.define("royal") do
  override("PokeAccess::DBKBattlerInfo", :shiny_word) { |_mod, _original, args| PokeAccess::Party.shiny_word(args[0]) }
end
