# The battle closes as its pbStartBattle returns (battle_g6's hook on the battle classes), not when pbBattleAnimation
# does: what that block runs after the fight (an evolution, the end-of-battle events) reads as out of battle, so the
# HP key says the party, the info key lets go of the foe and the lines go to the dialogue history.

# A battle as far as its end goes: pbStartBattle runs the fight (the block it was made with) and answers its decision.
module BattleCloseFight
  def initialize(&fight); @fight = fight; end
  def pbStartBattle(*_a)
    @fight.call if @fight
    :decision
  end
end

# The gen-6 battle, PokeBattle_Battle for the moment of the binding.
class BattleCloseStock; include BattleCloseFight; end

# The Safari Zone's battle, PokeBattle_SafariZone for the moment of the binding: not a PokeBattle_Battle.
class BattleCloseSafari; include BattleCloseFight; end

# A screen with a hooked method of its own, for a fight that runs it inside pbStartBattle.
class BattleCloseProbe
  def ping; :pong; end
end

PokeAccess::Hooks.before_hook("BattleCloseProbe", :ping) { |_p, _a| PokeAccess.speak("ping", false) }

class BattleCloseTest < PokeAccessTest
  class << self
    private

    # Evaluates battle_g6 (as the harness reads it) with stand_ins under their game names for the moment: the hooks it
    # binds to them stay, while what it added to everything else (hooks on classes bound before, function bodies, the
    # missing list) is put back.
    def bind_battle_g6(stand_ins)
      hooks = PokeAccess::Hooks
      chains = hooks.instance_variable_get(:@chains)
      chains_was = {}
      chains.each { |k, v| chains_was[k] = v.dup }
      bodies_was = {}
      hooks.fn_bodies.each { |k, v| bodies_was[k] = v.dup }
      missing = hooks.missing.dup
      made = stand_ins.reject { |n, _k| Object.const_defined?(n) }
      made.each { |n, k| Object.const_set(n, k) }
      verbose = $VERBOSE
      $VERBOSE = nil
      path = File.join(Harness::ROOT, "core", "battle", "gen6", "battle_g6.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
    ensure
      $VERBOSE = verbose
      (made || {}).each_key { |n| Object.send(:remove_const, n) }
      chains_was.each { |k, v| chains[k] = v }
      bodies = hooks.fn_bodies
      bodies.keys.each { |k| bodies_was.key?(k) ? bodies[k].replace(bodies_was[k]) : bodies.delete(k) }
      hooks.missing.replace(missing)
    end
  end

  # The battle hooks bound to the stand-ins once, as this file loads.
  bind_battle_g6(:PokeBattle_Battle => BattleCloseStock, :PokeBattle_SafariZone => BattleCloseSafari)

  test "inside pbStartBattle the battle runs and can be read" do
    seen = nil
    fight(BattleCloseStock) { seen = [PokeAccess::Battle.in_battle?, PokeAccess::Battle.battle] }
    assert_equal [true, :the_battle], seen
  end

  test "the battle is over as its pbStartBattle returns, still inside pbBattleAnimation" do
    [BattleCloseStock, BattleCloseSafari].each do |klass|
      fight(klass)
      refute PokeAccess::Battle.in_battle?, klass.name
      assert_nil PokeAccess::Battle.battle, klass.name
    end
  end

  test "an evolution after the fight: the HP key says the party, its lines go to the dialogue history" do
    fight(BattleCloseStock)
    with_party([Poke.build(:name => "Charmeleon", :hp => 46, :totalhp => 46)]) { PokeAccess::Battle.announce_hp(false) }
    said = PokeAccess::I18n.t(:pty_member_nolv, :name => "Charmeleon", :sex => "", :hp => 46, :tot => 46)
    assert_equal [[said, true]], SpeakCapture.log
    assert_equal :dialogue, PokeAccess.dialogue_category
  end

  test "the info key lets go of the battle's foe as the battle returns" do
    fight(BattleCloseStock) { PokeAccess::Info.set_info(:battle_foe, nil, "Rattata, nivel 3") }
    assert_nil PokeAccess::Info.row_text
  end

  test "keeps the battle's own decision" do
    assert_equal :decision, fight(BattleCloseStock)
  end

  test "the hooks of what the battle runs keep reading inside its pbStartBattle" do
    fight(BattleCloseStock) { BattleCloseProbe.new.ping }
    assert_equal ["ping"], SpeakCapture.lines
  end

  private

  # Starts a battle of klass the way pbBattleAnimation's block does, running the block as its fight with the battle
  # stored as the message hook stores it; answers pbStartBattle's own value.
  def fight(klass, &inside)
    PokeAccess::Battle.battle_started
    klass.new do
      PokeAccess::Battle.set_battle(:the_battle)
      inside.call if inside
    end.pbStartBattle
  end

  # Runs the block with the player's party as these members, put back after.
  def with_party(members)
    saved = $Trainer
    $Trainer = Struct.new(:party).new(members)
    yield
  ensure
    $Trainer = saved
  end
end
