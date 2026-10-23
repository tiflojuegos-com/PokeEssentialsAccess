# The modern battle's HP lines (gamedata pass), off Battle::Battler's pbReduceHP and pbRecoverHP: each change is said,
# queued, against the bar it leaves; messages shown inside pbReduceHP are read, and a drop the bar ends no lower
# than it began is not read as a loss.
class HpHooksGdTest < PokeAccessTest
  T = PokeAccess::I18n

  test "says what a foe lost and what is left of its bar, as a percentage" do
    Battle::Battler.new("Onix", 80, 100, 1).pbReduceHP(30)
    assert_equal [[foe_change("Onix", :bt_lose, 30, T.t(:bt_hp_pct, :n => 50)), false]], SpeakCapture.log
  end

  test "says a foe's loss as the change of its bar's percentage, not in hit points" do
    Battle::Battler.new("Onix", 80, 160, 1).pbReduceHP(30)
    assert_equal [[foe_change("Onix", :bt_lose, 19, T.t(:bt_hp_pct, :n => 31)), false]], SpeakCapture.log
  end

  test "says a foe's change that leaves its bar's floored percentage as it was as less than 1 percent" do
    Battle::Battler.new("Onix", 299, 300, 1).pbReduceHP(1)
    Battle::Battler.new("Onix", 297, 300, 1).pbRecoverHP(1)
    rest = T.t(:bt_hp_pct, :n => 99)
    assert_equal [[sliver("Onix", :bt_lose, rest), false], [sliver("Onix", :bt_gain, rest), false]], SpeakCapture.log
  end

  test "says the player's own Pokemon's hp exactly" do
    Battle::Battler.new("Pikachu", 35, 35, 0).pbReduceHP(12)
    assert_equal [[change("Pikachu", :bt_lose, 12, T.t(:bt_hp_exact, :hp => 23, :tot => 35)), false]], SpeakCapture.log
  end

  test "says a hit by what it took, however much more was asked" do
    Battle::Battler.new("Onix", 20, 100, 1).pbReduceHP(50)
    assert_equal [[foe_change("Onix", :bt_lose, 20, T.t(:bt_hp_pct, :n => 0)), false]], SpeakCapture.log
  end

  test "says what a heal restored" do
    Battle::Battler.new("Onix", 40, 100, 1).pbRecoverHP(25)
    assert_equal [[foe_change("Onix", :bt_gain, 25, T.t(:bt_hp_pct, :n => 65)), false]], SpeakCapture.log
  end

  test "says nothing for a hit or a heal that moves no hp" do
    Battle::Battler.new("Onix", 40, 100, 1).pbReduceHP(0)
    Battle::Battler.new("Onix", 100, 100, 1).pbRecoverHP(25)
    assert_nothing_spoken
  end

  test "reads a message shown while the hp drops, before the loss" do
    scene = Battle::Scene.new
    boss = Battle::Battler.new("Jefe", 40, 100, 1)
    boss.on_reduce = lambda { |_b| scene.pbDisplayMessage("¡El escudo del Jefe se resquebraja!") }
    boss.pbReduceHP(10)
    loss = foe_change("Jefe", :bt_lose, 10, T.t(:bt_hp_pct, :n => 30))
    assert_equal [["¡El escudo del Jefe se resquebraja!", false], [loss, false]], SpeakCapture.log
  end

  test "reads a drop the bar refills from as the refill, not as a loss" do
    boss = Battle::Battler.new("Jefe", 40, 100, 1)
    boss.on_reduce = lambda { |b| b.pbRecoverHP(b.totalhp) }
    boss.pbReduceHP(40)
    assert_equal [[foe_change("Jefe", :bt_gain, 100, T.t(:bt_hp_pct, :n => 100)), false]], SpeakCapture.log
  end

  test "reads a drop healed back to where it began as the heal alone" do
    boss = Battle::Battler.new("Jefe", 40, 100, 1)
    boss.on_reduce = lambda { |b| b.pbRecoverHP(10) }
    boss.pbReduceHP(10)
    assert_equal [[foe_change("Jefe", :bt_gain, 10, T.t(:bt_hp_pct, :n => 40)), false]], SpeakCapture.log
  end

  test "keeps the amounts the hp methods answer" do
    onix = Battle::Battler.new("Onix", 80, 100, 1)
    assert_equal [30, 15], [onix.pbReduceHP(30), onix.pbRecoverHP(15)]
  end

  private

  # The hp line for the player's own battler: its name, the verb key's word, the amount and what is left.
  def change(name, verb, n, rest)
    T.t(:bt_hp_change, :name => name, :verb => T.t(verb), :n => n, :rest => rest)
  end

  # The hp line for a foe, whose box paints only its bar: the change of the percentage left, then what is left.
  def foe_change(name, verb, n, rest)
    T.t(:bt_hp_change_pct, :name => name, :verb => T.t(verb), :n => n, :rest => rest)
  end

  # The hp line for a foe whose bar's percentage did not move: less than 1 percent of it, then what is left.
  def sliver(name, verb, rest)
    T.t(:bt_hp_change_under_pct, :name => name, :verb => T.t(verb), :rest => rest)
  end
end
