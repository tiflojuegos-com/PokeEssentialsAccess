# Relict's fight menu draws the category icon from display_category alone, its branch that works Shell Side
# Arm and Photon Geyser out against the foe commented out; the core line works them out, as other screens do.
Suite.define("relict: the fight menu line says the category its icon draws") do
  bs = PokeAccess::BattleScene
  geyser = Object.new
  def geyser.function_code; "CategoryDependsOnHigherDamageIgnoreTargetAbility"; end
  def geyser.display_category(_battler); 1; end
  def geyser.clone; self; end
  def geyser.pbOnStartUse(_user, _targets); @calc = 0; end
  def geyser.calcCategory; @calc; end
  battler = Object.new
  def battler.pbDirectOpposing; nil; end
  eq "the core line works the move out against the foe", bs.fight_category(geyser, battler), 0

  meta = (class << bs; self; end)
  meta.send(:alias_method, :relict_spec_fight_category, :fight_category)
  begin
    load File.expand_path("../../../games/relict/fight_category.rb", File.dirname(__FILE__))
    eq "Relict's says the stored category its icon keeps", bs.fight_category(geyser, battler), 1
    tackle = Object.new
    def tackle.category; 0; end
    eq "and a move with no display_category falls back to the core answer", bs.fight_category(tackle, battler), 0
  ensure
    meta.send(:alias_method, :fight_category, :relict_spec_fight_category)
    meta.send(:remove_method, :relict_spec_fight_category)
  end
end
