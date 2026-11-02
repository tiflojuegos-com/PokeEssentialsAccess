# The boss battles of Clara Dragon's games (NO_CAPTURES_SWITCH, each game's own number): the box of the boss, always
# battler 1, draws no level (Edas' 0222_UI Battle, Perseida's 0267_NewBattle_UI). Its lives are plugins/battle_lives.rb's.
PokeAccess::Game.define("clara_common") do
  override("PokeAccess::Battle", :shown_level) do |_mod, original, args|
    ($game_switches[NO_CAPTURES_SWITCH] rescue false) && (args[0].index rescue nil) == 1 ? nil : original.call
  end
end
