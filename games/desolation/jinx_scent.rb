# Desolation's Jinx Scent (Scripts/Pokemon Desolation/DesoPokegear.rb, Scene_EncounterRate): a Pokegear app that sets
# the encounter rate with a centred number chooser over a picture that writes "SET ENCOUNTER RATE:" and has no message
# window. The picture's words are said as the app opens; the chooser's number is the core's, queued behind them.
PokeAccess::Game.define("desolation") do
  before("Scene_EncounterRate", :main) { |_s, _a| PokeAccess.speak(PokeAccess::I18n.t(:deso_jinx_rate), true) }
end
