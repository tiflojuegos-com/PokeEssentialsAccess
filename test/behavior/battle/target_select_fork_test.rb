# Target selection in doubles on the forks without pbUpdateSelected (both Infinite Fusion): pbSelectBattler(index, 2)
# moves the target cursor and is read, once per change; its other modes start a battler's turn and stay silent.

# Infinite Fusion's battle scene as far as the target cursor goes: pbSelectBattler and no pbUpdateSelected.
class IfTargetScene
  def initialize(battle); @battle = battle; end
  def pbSelectBattler(_index, _select_mode = 1); :selected; end
end

class TargetSelectForkTest < PokeAccessTest
  Battler = Struct.new(:name, :pokemon)
  FlagBattle = Struct.new(:doublebattle, :battlers)

  # A battle with no doublebattle flag, told single or double by how many battlers a side holds (v18 on).
  SidedBattle = Struct.new(:side_size, :battlers) do
    def pbSideSize(_side); side_size; end
  end

  class << self
    private

    # Evaluates battle_g6 (as the harness reads it) with stand_ins under their game names for the moment: the hooks it
    # binds to them stay, while what it added to everything else (hooks on classes bound before, function bodies, the
    # missing list) is put back. Answers the bindings it reported missing.
    def bind_battle_g6(stand_ins)
      hooks = PokeAccess::Hooks
      chains = hooks.instance_variable_get(:@chains)
      chains_was = {}
      chains.each { |k, v| chains_was[k] = v.dup }
      bodies_was = {}
      hooks.fn_bodies.each { |k, v| bodies_was[k] = v.dup }
      missing = hooks.missing.dup
      hooks.missing.clear
      made = stand_ins.reject { |n, _k| Object.const_defined?(n) }
      made.each { |n, k| Object.const_set(n, k) }
      verbose = $VERBOSE
      $VERBOSE = nil
      path = File.join(Harness::ROOT, "core", "battle", "gen6", "battle_g6.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      hooks.missing.dup
    ensure
      $VERBOSE = verbose
      (made || {}).each_key { |n| Object.send(:remove_const, n) }
      chains_was.each { |k, v| chains[k] = v }
      bodies = hooks.fn_bodies
      bodies.keys.each { |k| bodies_was.key?(k) ? bodies[k].replace(bodies_was[k]) : bodies.delete(k) }
      hooks.missing.replace(missing)
    end
  end

  # The gen-6 battle hooks bound to the fork's scene once, as this file loads, and what that binding reported missing.
  REPORTED_MISSING = bind_battle_g6(:PokeBattle_Scene => IfTargetScene)

  test "the target mode names the battler under the cursor, interrupting; the others start a turn and say nothing" do
    { [0] => [], [1] => [], [0, 0] => [], [1, 1] => [], [0, 2] => [[bulbasaur, true]],
      [1, 2] => [[charmander, true]] }.each do |args, want|
      scene = fork_scene
      SpeakCapture.clear
      scene.pbSelectBattler(*args)
      assert_equal want, SpeakCapture.log, "pbSelectBattler#{args.inspect}"
    end
  end

  test "the same target is said once until the cursor moves" do
    scene = fork_scene
    scene.pbSelectBattler(1, 2)
    scene.pbSelectBattler(1, 2)
    scene.pbSelectBattler(0, 2)
    assert_equal [[charmander, true], [bulbasaur, true]], SpeakCapture.log
  end

  test "deselecting on the way out lets the same target be read again on coming back" do
    scene = fork_scene
    scene.pbSelectBattler(0, 2)
    scene.pbSelectBattler(-1)
    scene.pbSelectBattler(0, 2)
    assert_equal [[bulbasaur, true], [bulbasaur, true]], SpeakCapture.log
  end

  test "a spread move's area mode names every target it lights, in one line" do
    scene = fork_scene
    scene.pbSelectBattler(%w[a b], 2)
    assert_equal [["#{bulbasaur}. #{charmander}", true]], SpeakCapture.log
  end

  test "an unlit slot of a spread move is left out" do
    scene = fork_scene
    scene.pbSelectBattler([nil, "b"], 2)
    assert_equal [[charmander, true]], SpeakCapture.log
  end

  test "the same lit targets are said once" do
    scene = fork_scene
    scene.pbSelectBattler(%w[a b], 2)
    scene.pbSelectBattler(%w[a b], 2)
    assert_equal [["#{bulbasaur}. #{charmander}", true]], SpeakCapture.log
  end

  test "a spread that lights no target says nothing" do
    scene = fork_scene
    scene.pbSelectBattler([nil, nil], 2)
    assert_nothing_spoken
  end

  test "the selection keeps the scene's own return" do
    assert_equal :selected, fork_scene.pbSelectBattler(1, 2)
  end

  test "reads only in a double battle, told by its flag or by the battlers a side holds" do
    battlers = [Battler.new("Bulbasaur", :mon), Battler.new("Charmander", :mon)]
    [["flag on", FlagBattle.new(true, battlers), [[charmander, true]]],
     ["flag off", FlagBattle.new(false, battlers), []],
     ["two a side", SidedBattle.new(2, battlers), [[charmander, true]]],
     ["one a side", SidedBattle.new(1, battlers), []]].each do |what, battle, want|
      scene = IfTargetScene.new(battle)
      PokeAccess::Battle.announce_target(scene, -1)
      SpeakCapture.clear
      scene.pbSelectBattler(1, 2)
      assert_equal want, SpeakCapture.log, what
    end
  end

  test "binding reports the scene methods it lacks, but not the optional ones" do
    assert_includes REPORTED_MISSING, "PokeBattle_Scene#pbDisplayMessage", "a gen-6 scene always has it"
    %w[pbChooseTarget pbShowAbilitySplash pbLevelUp].each do |meth|
      refute_includes REPORTED_MISSING, "PokeBattle_Scene##{meth}"
    end
  end

  test "an empty slot under the cursor or lit by a spread is named as empty" do
    empty = "#{t(:bt_empty_slot)}, #{t(:bt_target_ally)}"
    { [2, 2] => [[empty, true]], [[nil, nil, "c"], 2] => [[empty, true]] }.each do |args, want|
      scene = fork_scene
      SpeakCapture.clear
      scene.pbSelectBattler(*args)
      assert_equal want, SpeakCapture.log, "pbSelectBattler#{args.inspect}"
    end
  end

  test "a scene with no battle says nothing, for a target or a spread" do
    scene = IfTargetScene.new(nil)
    PokeAccess::Battle.announce_target(scene, -1)
    scene.pbSelectBattler(1, 2)
    scene.pbSelectBattler(%w[a b], 2)
    assert_nothing_spoken
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # The fork's scene over a double battle with Bulbasaur on the player's side (0) and Charmander on the foe's (1),
  # its cursor deselected.
  def fork_scene
    scene = IfTargetScene.new(FlagBattle.new(true, [Battler.new("Bulbasaur", :mon), Battler.new("Charmander", :mon)]))
    PokeAccess::Battle.announce_target(scene, -1)
    scene
  end

  # The target line for each battler: no fight window says who chooses, so slot 0 is the player's own.
  def bulbasaur; "Bulbasaur, #{t(:bt_target_self)}"; end
  def charmander; "Charmander, #{t(:bt_target_foe)}"; end
end
