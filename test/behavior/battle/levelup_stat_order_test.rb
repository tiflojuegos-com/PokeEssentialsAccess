# The level-up line from pbLevelUp's old stats: v16-17 pass hp, atk, def, speed, spatk, spdef after the Pokemon and
# battler, both Infinite Fusion (v18 hybrids) hp, atk, def, spatk, spdef, speed; same arity, so the era is passed in.
# The gen-6 battle hooks are evaluated again over a PokeBattle_Scene made here, as this file loads.
class LevelupStatOrderTest < PokeAccessTest
  T = PokeAccess::I18n

  # Gen 6's battle scene as far as its level-up goes: pbLevelUp shows the stat panels, which the modal panel reader
  # would read.
  Scene = Class.new do
    def pbLevelUp(_pokemon, _battler, *_old)
      PokeAccess::ModalPanel.say("Ataque 100 > 101")
      :leveled
    end
  end

  test "reads a v16-17 call's last three old stats as speed, special attack and special defense" do
    line = PokeAccess::Battle.levelup_from_args(call_args(99, 98, 97, 96, 95, 94), false)
    assert_equal gains([:st_hp, 1], [:st_atk, 2], [:st_def, 3], [:st_spatk, 5], [:st_spdef, 6], [:st_speed, 4]), line
  end

  test "reads a v18 call's last three old stats as special attack, special defense and speed" do
    line = PokeAccess::Battle.levelup_from_args(call_args(99, 98, 97, 96, 95, 94), true)
    assert_equal gains([:st_hp, 1], [:st_atk, 2], [:st_def, 3], [:st_spatk, 4], [:st_spdef, 5], [:st_speed, 6]), line
  end

  test "names only the stats that grew, in the summary's order" do
    mon = Poke.build(:totalhp => 50, :attack => 30, :defense => 28, :spatk => 33, :spdef => 26, :speed => 40)
    assert_equal gains([:st_hp, 5], [:st_spatk, 1], [:st_speed, 3]),
                 PokeAccess::Battle.levelup_text(mon, 45, 30, 28, 32, 26, 37)
  end

  test "leaves out a stat whose old value the call did not pass" do
    mon = Poke.build(:totalhp => 50, :attack => 31)
    assert_equal gains([:st_atk, 1]), PokeAccess::Battle.levelup_text(mon, nil, 30, 28, 32, 26, 35)
  end

  test "has no line when nothing grew or there is no Pokemon" do
    mon = Poke.build
    same = [mon.totalhp, mon.attack, mon.defense, mon.spatk, mon.spdef, mon.speed]
    assert_nil PokeAccess::Battle.levelup_text(mon, *same), "nothing grew"
    assert_nil PokeAccess::Battle.levelup_text(nil, 1, 1, 1, 1, 1, 1), "no Pokemon"
  end

  test "says a gen-6 battle's level-up in the v16-17 order, queued, with the scene's own panels muted" do
    with_scene { |scene| scene.pbLevelUp(*call_args(99, 98, 97, 96, 95, 94)) }
    line = gains([:st_hp, 1], [:st_atk, 2], [:st_def, 3], [:st_spatk, 5], [:st_spdef, 6], [:st_speed, 4])
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "keeps what the scene's level-up answers" do
    with_scene { |scene| assert_equal :leveled, scene.pbLevelUp(*call_args(100, 100, 100, 100, 100, 100)) }
  end

  test "the scene holds the game's class name only while the hooks bind, not while a test runs" do
    held = with_scene { |_scene| Object.const_defined?(:PokeBattle_Scene) ? Object.const_get(:PokeBattle_Scene) : nil }
    refute_same Scene, held
  end

  private

  # pbLevelUp's arguments for a Pokemon whose six stats are now 100, with the six old values in the call's order.
  def call_args(*old)
    mon = Poke.build(:totalhp => 100, :attack => 100, :defense => 100, :spatk => 100, :spdef => 100, :speed => 100)
    [mon, nil] + old
  end

  # The level-up line for [stat key, gain] pairs, as the game's level-up panel lists them.
  def gains(*pairs)
    pairs.map { |key, n| T.t(:lvl_stat, :stat => T.t(key), :n => n) }.join(", ")
  end

  # Yields a new scene with the gen-6 battle hooks bound to it attached.
  def with_scene
    attached(BOUND) { yield Scene.new }
  end

  # Runs the block with the hook chains bound to the stand-ins at load attached, then takes them away, putting back
  # whatever chains held those keys before. The stand-ins hold the game's names only while bind evaluates the hooks.
  def attached(bound)
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    held = bound.keys.select { |k| chains.key?(k) }.map { |k| [k, chains[k]] }
    chains.update(bound)
    yield
  ensure
    bound.each_key { |k| chains.delete(k) }
    (held || []).each { |k, v| chains[k] = v }
  end

  class << self
    private

    # Evaluates the mod files at rels, read as the harness reads them, over the stand-ins set for the moment under
    # their game names (top-level name => class), and answers the hook chains bound to them, to attach per test; all
    # else the evaluation changed (the names, other chains, function bodies, overrides, the missing list, the battle
    # marks and singletons) is put back as it was.
    def bind(stand_ins, rels)
      hooks = PokeAccess::Hooks
      chains = hooks.instance_variable_get(:@chains)
      chains_was = {}
      chains.each { |k, v| chains_was[k] = v.dup }
      bodies_was = {}
      hooks.fn_bodies.each { |k, v| bodies_was[k] = v.dup }
      overrides = hooks.overrides.length
      missing = hooks.missing.dup
      marks = PokeAccess::Battle::ICON_MARKS.dup
      singletons = [:shown_sex, :shown_level].map { |n| [n, PokeAccess::Battle.method(n)] }
      ours = lambda { |key| stand_ins.keys.any? { |n| key.start_with?("#{n}#", "#{n}::") } }
      chains.delete_if { |k, _v| ours.call(k) }
      priors = stand_ins.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
      stand_ins.each { |n, k| Object.const_set(n, k) }
      verbose = $VERBOSE
      $VERBOSE = nil
      rels.each do |rel|
        path = File.join(Harness::ROOT, rel)
        eval(Harness.source(path), TOPLEVEL_BINDING, path)
      end
      chains.select { |k, _v| ours.call(k) }
    ensure
      $VERBOSE = verbose
      stand_ins.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
      (priors || []).each { |n, k| Object.const_set(n, k) if k }
      (chains.keys - chains_was.keys).each do |key|
        cname, meth = key.split("#", 2)
        k = PokeAccess.const_at(cname)
        orig = "#{meth}__pa_orig_#{cname.gsub(/[^a-zA-Z0-9]/, '_')}"
        unwrap = !ours.call(key) && k.is_a?(Module) && (k.method_defined?(orig) || k.private_method_defined?(orig))
        k.send(:alias_method, meth, orig) if unwrap
        chains.delete(key)
      end
      chains_was.each { |k, v| chains[k] = v }
      bodies = hooks.fn_bodies
      bodies.keys.each { |k| bodies_was.key?(k) ? bodies[k].replace(bodies_was[k]) : bodies.delete(k) }
      hooks.overrides.slice!(overrides..-1)
      hooks.missing.replace(missing)
      PokeAccess::Battle::ICON_MARKS.replace(marks)
      singletons.each { |n, m| PokeAccess::Battle.define_singleton_method(n, m) }
    end
  end

  # The gen-6 battle hooks' chains on Scene, bound once as this file loads: evaluating a file again starts its coverage
  # afresh, so binding before any test lets every test's reading count.
  BOUND = bind({ :PokeBattle_Scene => Scene }, ["core/battle/gen6/battle_g6.rb"])
end
