# The creator's notice at the quick-start intro (CreadorEventScene, the intro_creador picture, _en in English): its
# transcribed text (rcr_notice) is said as it goes up, with the key while hints are said, as the title screen says it.
PokeAccess::Game.define("royal") do
  after("CreadorEventScene", :pbStartScene, :optional => true) do |_s, _r, _a|
    PokeAccess.speak(PokeAccess::TitleScreen.prompt(:rcr_notice), true)
  end
end
