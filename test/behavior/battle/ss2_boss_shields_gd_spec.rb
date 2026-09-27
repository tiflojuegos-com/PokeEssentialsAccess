# Soulstones 2's Rejuvenation-style bosses: a knock-out hit breaks a shield instead, said as it happens with the
# shields left, before the shield's effects and the refilled bar. Gamedata pass.

# The plugin's flow: pbShieldDamage runs the effects, drops a shield, refills the bar; entry runs pbShieldEffects.
module Battle
  def pbShieldEffects(_battler, data, _delay = false)
    @scene.pbDisplayMessage(data[:message]) if data && data[:message]
  end

  def pbShieldDamage(battler, amt)
    pbShieldEffects(battler, battler.on_break) if battler.on_break
    battler.shieldCount -= 1 if battler.shieldCount > 0
    battler.pbRecoverHP(battler.totalhp)
    amt
  end
end

class SS2ShieldBattle
  include Battle
  def initialize(scene); @scene = scene; end
end

# The plugin declares the shield counter on the battler class, where the reader watches it drop.
module Battle
  class Battler
    attr_accessor :shieldCount
  end
end

class SS2ShieldBoss < Battle::Battler
  attr_accessor :on_break
end

require File.expand_path("../../../games/soulstones2/boss_shields", File.dirname(__FILE__))

def ss2_shield_setup(shields, on_break, hp = 30)
  scene = Battle::Scene.new
  battle = SS2ShieldBattle.new(scene)
  boss = SS2ShieldBoss.new("Jefe", hp, 100, 1)
  boss.shieldCount = shields
  boss.on_break = on_break
  boss.on_reduce = lambda { |b| battle.pbShieldDamage(b, hp) }
  [battle, boss]
end

Suite.define("ss2 bosses: a broken shield is said first, then its effects, then the refill") do
  _battle, boss = ss2_shield_setup(3, { :message => "El jefe se enfurece!" })
  boss.pbReduceHP(30)
  lines = SpeakCapture.lines
  eq "the break comes first, with the shields left", lines[0], PokeAccess::I18n.t(:ss2_shield_broken, :n => 2)
  match "then the message the shield's effects show", lines[1], /El jefe se enfurece/
  eq "then the refilled bar", lines[2], PokeAccess::BattleScene.hp_change_text(boss, 100, false)
  eq "and nothing else: no loss read against the refilled bar", lines.length, 3
end

Suite.define("ss2 bosses: a shield with no effects is said to break as the counter drops, before the refill") do
  _battle, boss = ss2_shield_setup(1, nil)
  boss.pbReduceHP(30)
  eq "the break with none left, then the refilled bar", SpeakCapture.lines,
     [PokeAccess::I18n.t(:ss2_shield_broken, :n => 0), PokeAccess::BattleScene.hp_change_text(boss, 100, false)]
end

# A boss hit at full HP (the first hit after each refill) reads the break and the refill, and no loss.
Suite.define("ss2 bosses: a boss knocked from full HP is not also said to lose it") do
  _battle, boss = ss2_shield_setup(2, nil, 100)
  boss.pbReduceHP(100)
  eq "the break and the refill, and no loss", SpeakCapture.lines,
     [PokeAccess::I18n.t(:ss2_shield_broken, :n => 1), PokeAccess::BattleScene.hp_change_text(boss, 100, false)]
end

Suite.define("ss2 bosses: the entry effects break nothing and say no break") do
  battle, boss = ss2_shield_setup(2, nil)
  battle.pbShieldEffects(boss, { :message => "Aparece un jefe!" })
  not_spoke "entering the fight is not a broken shield", /Escudo roto/
  spoke "the entry message itself is read", /Aparece un jefe/
end
