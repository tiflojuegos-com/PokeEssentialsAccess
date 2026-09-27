# Relict's load screen paints each panel's title alone (the continue panel's save data is commented out and the
# party is never set), so nothing is composed from the save: the focused command is all there is to say.
PokeAccess::Game.define("relict") do
  override("PokeAccess::LoadPanel", :summary) { |_mod, _original, _args| nil }
end
