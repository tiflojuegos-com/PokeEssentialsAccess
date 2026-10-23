# The v20+ battle closes as its pbStartBattle returns, as the gen-6 one does (battle_close_test.rb): battle_g6's hook
# binds to Battle and SafariBattle too, so what pbBattleAnimation's block runs after the fight reads as out of battle.

# A v20+ battle as far as its end goes: pbStartBattle runs the fight (the block it was made with) and answers its
# decision.
module BattleCloseGdFight
  def initialize(&fight); @fight = fight; end
  def pbStartBattle(*_a)
    @fight.call if @fight
    :decision
  end
end

# The v20+ battle, Battle for the moment of the binding.
class BattleCloseGdStock; include BattleCloseGdFight; end

# The v20+ Safari Zone's battle, SafariBattle for the moment of the binding: not a Battle.
class BattleCloseGdSafari; include BattleCloseGdFight; end

class BattleCloseGdTest < PokeAccessTest
  class << self
    private

    # Evaluates battle_g6 (as the harness reads it) with stand_ins under their game names for the moment, in place of
    # any the stubs define (their Battle is a module of menus): the hooks it binds to them stay, while what it added to
    # everything else (hooks on classes bound before, function bodies, the missing list) is put back.
    def bind_battle_g6(stand_ins)
      hooks = PokeAccess::Hooks
      chains = hooks.instance_variable_get(:@chains)
      chains_was = {}
      chains.each { |k, v| chains_was[k] = v.dup }
      bodies_was = {}
      hooks.fn_bodies.each { |k, v| bodies_was[k] = v.dup }
      missing = hooks.missing.dup
      kept = {}
      stand_ins.each do |n, k|
        kept[n] = Object.send(:remove_const, n) if Object.const_defined?(n)
        Object.const_set(n, k)
      end
      verbose = $VERBOSE
      $VERBOSE = nil
      path = File.join(Harness::ROOT, "core", "battle", "gen6", "battle_g6.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
    ensure
      $VERBOSE = verbose
      stand_ins.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
      (kept || {}).each { |n, k| Object.const_set(n, k) }
      chains_was.each { |k, v| chains[k] = v }
      bodies = hooks.fn_bodies
      bodies.keys.each { |k| bodies_was.key?(k) ? bodies[k].replace(bodies_was[k]) : bodies.delete(k) }
      hooks.missing.replace(missing)
    end
  end

  # The battle hooks bound to the stand-ins once, as this file loads.
  bind_battle_g6(:Battle => BattleCloseGdStock, :SafariBattle => BattleCloseGdSafari)

  test "inside the v20+ pbStartBattle the battle runs and can be read" do
    seen = nil
    fight(BattleCloseGdStock) { seen = [PokeAccess::Battle.in_battle?, PokeAccess::Battle.battle] }
    assert_equal [true, :the_battle], seen
  end

  test "the v20+ battle and Safari Zone are over as their pbStartBattle returns, still inside pbBattleAnimation" do
    [BattleCloseGdStock, BattleCloseGdSafari].each do |klass|
      fight(klass)
      refute PokeAccess::Battle.in_battle?, klass.name
      assert_nil PokeAccess::Battle.battle, klass.name
    end
  end

  test "keeps the v20+ battle's own decision" do
    assert_equal :decision, fight(BattleCloseGdSafari)
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
end
