# Realidea's party panel writes its HP figures at x 1000, off its bitmap (@hpX, @hpY): only the bar shows.
PokeAccess::Game.define("realidea") do
  override("PokeAccess::Party", :panel_hp_figures?) { |_mod, _original, _args| false }
end
