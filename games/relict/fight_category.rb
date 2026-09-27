# Relict's fight menu shows the category icon from display_category alone (its foe-dependent branch is commented
# out), so the line says the category the icon shows.
PokeAccess::Game.define("relict") do
  override("PokeAccess::BattleScene", :fight_category) do |_mod, original, args|
    move, battler = args
    c = battler ? (move.display_category(battler) rescue nil) : nil
    c.is_a?(Integer) ? c : original.call
  end
end
