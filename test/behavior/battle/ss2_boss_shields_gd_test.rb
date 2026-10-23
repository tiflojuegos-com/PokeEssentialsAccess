# Soulstones 2's Rejuvenation-style bosses (games/soulstones2/boss_shields.rb): a knockout hit breaks a shield instead,
# said as it happens with the shields left, before the shield's effects and the refilled bar.

# The plugin's flow: pbShieldDamage runs the effects, drops a shield and refills the bar; a boss's entry runs
# pbShieldEffects alone.
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

# A battle running the plugin's shield methods over its scene.
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

# A boss, with the effects its next shield runs as it breaks (nil for none).
class SS2ShieldBoss < Battle::Battler
  attr_accessor :on_break
end

ss2_boss_shields = File.join(Harness::ROOT, "games", "soulstones2", "boss_shields.rb")
eval(Harness.source(ss2_boss_shields), TOPLEVEL_BINDING, ss2_boss_shields)

class Ss2BossShieldsGdTest < PokeAccessTest
  test "says a broken shield first, with the shields left, then its effects, then the refill" do
    _battle, boss = shield_setup(3, { :message => "El jefe se enfurece!" })
    boss.pbReduceHP(30)
    assert_equal [[broken(2), false], ["El jefe se enfurece!", false], [refill, false]], SpeakCapture.log
  end

  test "says a break with no effects as the counter drops, before the refill" do
    _battle, boss = shield_setup(1, nil)
    boss.pbReduceHP(30)
    assert_equal [[broken(0), false], [refill, false]], SpeakCapture.log
  end

  test "says no loss for a boss knocked from full HP: the break and the refill only" do
    _battle, boss = shield_setup(2, nil, 100)
    boss.pbReduceHP(100)
    assert_equal [[broken(1), false], [refill, false]], SpeakCapture.log
  end

  test "says each later hit's break again" do
    _battle, boss = shield_setup(2, nil)
    boss.pbReduceHP(30)
    SpeakCapture.clear
    boss.hp = 30
    boss.pbReduceHP(30)
    assert_equal [[broken(0), false], [refill, false]], SpeakCapture.log
  end

  test "says none left rather than a count below zero" do
    _battle, boss = shield_setup(0, { :message => "Grr" })
    boss.pbReduceHP(30)
    assert_equal [[broken(0), false], ["Grr", false], [refill, false]], SpeakCapture.log
  end

  test "says the entry effects' message and no break" do
    battle, boss = shield_setup(2, nil)
    battle.pbShieldEffects(boss, { :message => "Aparece un jefe!" })
    assert_equal [["Aparece un jefe!", false]], SpeakCapture.log
  end

  test "says nothing as the shields are set outside a hit" do
    _battle, boss = shield_setup(2, nil)
    boss.shieldCount = 3
    assert_nothing_spoken
  end

  private

  # A battle and its boss Jefe (100 HP at most, hp now), with shields shields and on_break run as one breaks; a hit
  # that knocks it out goes through the battle's pbShieldDamage, as the plugin's pbReduceHP does. The reader starts as
  # the game does, with no hit under way and no break said.
  def shield_setup(shields, on_break, hp = 30)
    PokeAccess::SS2BossShields.instance_variable_set(:@breaking, nil)
    PokeAccess::SS2BossShields.instance_variable_set(:@said, false)
    battle = SS2ShieldBattle.new(Battle::Scene.new)
    boss = SS2ShieldBoss.new("Jefe", hp, 100, 1)
    boss.shieldCount = shields
    boss.on_break = on_break
    boss.on_reduce = lambda { |b| battle.pbShieldDamage(b, hp) }
    SpeakCapture.clear
    [battle, boss]
  end

  # The break as said, with the shields left.
  def broken(left)
    PokeAccess::I18n.t(:ss2_shield_broken, :n => left)
  end

  # The boss's bar refilled from nothing, as the hit points line says it.
  def refill
    t = PokeAccess::I18n
    t.t(:bt_hp_change_pct, :name => "Jefe", :verb => t.t(:bt_gain), :n => 100, :rest => t.t(:bt_hp_pct, :n => 100))
  end
end
