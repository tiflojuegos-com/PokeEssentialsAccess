# Reminiscencia's own battle cues (games/reminiscencia/battle_effect.rb): the fight menu's effectiveness icon and the
# foe's types, and a hit's "-N PS" or "-X%" line led by the effectiveness word the game floats over the target.
class ReminBattleEffectTest < PokeAccessTest
  # Reminiscencia's battle scene (PokeBattle_Scene), reduced to the three methods its profile hooks: the fight menu
  # opening, a hit's damage animation (the battler struck and the effectiveness the floating text shows) and the
  # effectiveness icon's repaint for a move type against a foe index.
  Scene = Class.new do
    def initialize(battle, sprites); @battle = battle; @sprites = sprites; end
    def pbFightMenu(_index); :fight; end
    def pbDamageAnimation(_pkmn, _effectiveness); :animated; end
    def rewriteType(_type, _enemy_index); :painted; end
  end

  # The effectiveness icon (its picture's path), the fight menu's move window and the battle the menu measures in.
  Icon = Struct.new(:name, :visible)
  Window = Struct.new(:index)
  Battle = Struct.new(:battlers, :doublebattle, :sosbattle)
  # The game's HP option: porcentaje 1 shows hit points as a percentage.
  SystemOptions = Struct.new(:porcentaje)

  # A battler as the menu and the hit read it: its name, types, fainted state, hit points and side.
  class Battler
    attr_accessor :name, :hp, :totalhp, :index
    def initialize(name, types, fainted = false); @name = name; @types = types; @fainted = fainted; end
    def pbTypes(_withtype3 = false); @types; end
    def isFainted?; @fainted; end
  end

  # The core's hit points line, which the profile's replaces while a test runs, and the profile's file.
  META = (class << PokeAccess::Battle; self; end)
  CORE_HP = META.instance_method(:announce_hp_change)
  PATH = File.join(Harness::ROOT, "games", "reminiscencia", "battle_effect.rb")

  class << self
    private

    # Evaluates the profile, read as the harness reads it, over Scene set for the moment as PokeBattle_Scene, and
    # answers the hook chains bound to Scene and the profile's hit points line, to put in per test; the name, the
    # chains it found on that name, the core's line, the overrides listed and the profiles declared are put back.
    def load_profile
      game = PokeAccess::Game
      hooks = PokeAccess::Hooks
      chains = hooks.instance_variable_get(:@chains)
      ours = lambda { |key| key.start_with?("PokeBattle_Scene#") }
      held = chains.select { |k, _v| ours.call(k) }
      listed = hooks.overrides.length
      declared = [game.profiles.dup, game.instance_variable_get(:@profile_name)]
      prior = Object.const_defined?(:PokeBattle_Scene) ? Object.send(:remove_const, :PokeBattle_Scene) : nil
      chains.delete_if { |k, _v| ours.call(k) }
      Object.const_set(:PokeBattle_Scene, Scene)
      begin
        eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
        [chains.select { |k, _v| ours.call(k) }, META.instance_method(:announce_hp_change)]
      ensure
        Object.send(:remove_const, :PokeBattle_Scene) if Object.const_defined?(:PokeBattle_Scene)
        Object.const_set(:PokeBattle_Scene, prior) if prior
        chains.delete_if { |k, _v| ours.call(k) }
        chains.update(held)
        META.send(:define_method, :announce_hp_change, CORE_HP)
        hooks.overrides.slice!(listed..-1)
        game.profiles.replace(declared[0])
        game.instance_variable_set(:@profile_name, declared[1])
      end
    end
  end

  # The profile's chains on Scene and its hit points line, loaded once as this file loads: evaluating a file again
  # starts its coverage afresh, so loading it before any test lets every test's reading count.
  BOUND, OWN_HP = load_profile

  # Each test runs under the profile, from a turn with no hit noted: the hook chains it bound to Scene put in, its hit
  # points line in place of the core's; teardown takes both out, putting back what held those chains before.
  def setup
    super
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    @held = BOUND.keys.select { |k| chains.key?(k) }.map { |k| [k, chains[k]] }
    chains.update(BOUND)
    META.send(:define_method, :announce_hp_change, OWN_HP)
    PokeAccess::ReminBattle.forget_hits
  end

  def teardown
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    BOUND.each_key { |k| chains.delete(k) }
    (@held || []).each { |k, v| chains[k] = v }
    META.send(:define_method, :announce_hp_change, CORE_HP)
    super
  end

  test "says the effectiveness icon rewriteType painted and, from full, the foe's types" do
    rows = vb_levels do
      SpeakCapture.clear
      fight_scene(single_battle, "x2").rewriteType(11, 1)
      SpeakCapture.log.dup
    end
    word = t(:mv_eff_super)
    full = foe_line(:mv_eff_super, "Gyarados", 11, 2)
    assert_equal [[[word, false]], [[word, false]], [[full, false]]], rows
  end

  test "says the same focus against the same foe once" do
    scene = fight_scene(single_battle, "x2")
    scene.rewriteType(11, 1)
    scene.rewriteType(11, 1)
    assert_equal [foe_line(:mv_eff_super, "Gyarados", 11, 2)], SpeakCapture.lines
  end

  test "says the focus again once the fight menu opens anew" do
    scene = fight_scene(single_battle, "x2")
    scene.rewriteType(11, 1)
    SpeakCapture.clear
    scene.pbFightMenu(0)
    scene.rewriteType(11, 1)
    assert_equal [foe_line(:mv_eff_super, "Gyarados", 11, 2)], SpeakCapture.lines
  end

  test "names each effectiveness picture by its word" do
    PokeAccess::Config.verbosity = :brief
    { "x0" => :mv_eff_none, "m4" => :mv_eff_barely, "m2" => :mv_eff_weak, "x1" => :mv_eff_neutral,
      "x2" => :mv_eff_super, "x4" => :mv_eff_hyper }.each do |file, key|
      SpeakCapture.clear
      fight_scene(single_battle, file).rewriteType(0, 1)
      assert_equal [t(key)], SpeakCapture.lines, "#{file} is #{key}"
    end
  end

  test "stays silent while the game's option hides the icons" do
    fight_scene(single_battle, "x2", false).rewriteType(11, 1)
    assert_nothing_spoken
  end

  test "stays silent for a picture that is no effectiveness icon" do
    fight_scene(single_battle, "blank").rewriteType(11, 1)
    assert_nothing_spoken
  end

  test "measures the move against the foe at index 1 when rewriteType names none" do
    fight_scene(single_battle, "x1").rewriteType(11, nil)
    assert_equal [foe_line(:mv_eff_neutral, "Gyarados", 11, 2)], SpeakCapture.lines
  end

  test "in a double or SOS battle, measures the move against the foe left standing" do
    down = Battler.new("Caido", [0], true)
    onix = Battler.new("Onix", [5, 4])
    gyarados = Battler.new("Gyarados", [11, 2])
    cases = { "a double, the first foe down" => [Battle.new([nil, down, nil, onix], true, false), 1, onix],
              "a double, the second foe down" => [Battle.new([nil, gyarados, nil, down], true, false), 3, gyarados],
              "an SOS call, the first foe down" => [Battle.new([nil, down, nil, onix], false, true), 1, onix] }
    cases.each do |what, (battle, index, want)|
      SpeakCapture.clear
      fight_scene(battle, "x0").rewriteType(0, index)
      assert_equal [foe_line(:mv_eff_none, want.name, *want.pbTypes)], SpeakCapture.lines, "in #{what}"
    end
  end

  test "says the word alone where the foe's types cannot be told" do
    fight_scene(Battle.new([nil, Battler.new("Missingno", [])], false, false), "x2").rewriteType(11, 1)
    assert_equal [t(:mv_eff_super)], SpeakCapture.lines
  end

  test "says the word alone with no foe in the slot" do
    fight_scene(Battle.new([nil, nil], false, false), "x2").rewriteType(11, 1)
    assert_equal [t(:mv_eff_super)], SpeakCapture.lines
  end

  test "leads a hit's loss with the effectiveness word the text floats over the target" do
    { 2 => [t(:mv_eff_super)], 1 => [t(:mv_eff_weak)], 0 => [] }.each do |effectiveness, word|
      SpeakCapture.clear
      foe = gyarados(70)
      hit(foe, effectiveness)
      PokeAccess::Battle.hp_changed(foe, 80)
      assert_equal [[(word + [gyarados_line(:bt_lose, 10, 87)]).join(". "), false]], SpeakCapture.log,
                   "effectiveness #{effectiveness}"
    end
  end

  test "with the game's percent option, says the share of the total the text paints" do
    share = t(:bt_hp_change_pct, :name => "Gyarados", :verb => t(:bt_lose), :n => "12,5",
                                  :rest => t(:bt_hp_pct, :n => 87))
    { 0 => gyarados_line(:bt_lose, 10, 87), 1 => share }.each do |option, want|
      SpeakCapture.clear
      with_percent_option(option) { PokeAccess::Battle.hp_changed(gyarados(70), 80) }
      assert_equal [want], SpeakCapture.lines, "porcentaje #{option}"
    end
  end

  test "takes a hit's word once: a later loss with no hit behind it, as poison, goes without" do
    foe = gyarados(70)
    hit(foe, 2)
    PokeAccess::Battle.hp_changed(foe, 80)
    SpeakCapture.clear
    foe.hp = 60
    PokeAccess::Battle.hp_changed(foe, 70)
    assert_equal [gyarados_line(:bt_lose, 10, 75)], SpeakCapture.lines
  end

  test "gives a later loss that turn no word when the hit itself took nothing, as against Disguise" do
    foe = gyarados(40)
    hit(foe, 2)
    PokeAccess::Battle.hp_changed(foe, 40)
    foe.hp = 30
    PokeAccess::Battle.hp_changed(foe, 40)
    assert_equal [gyarados_line(:bt_lose, 10, 37)], SpeakCapture.lines, "the poison's loss, with no word"
  end

  test "says a gain with no effectiveness word" do
    foe = gyarados(80)
    hit(foe, 2)
    PokeAccess::Battle.hp_changed(foe, 70)
    assert_equal [gyarados_line(:bt_gain, 10, 100)], SpeakCapture.lines
  end

  test "forgets a hit no loss followed once a new turn's fight menu opens" do
    foe = gyarados(70)
    scene = fight_scene(single_battle, "x2")
    scene.pbDamageAnimation(foe, 2)
    scene.pbFightMenu(0)
    PokeAccess::Battle.hp_changed(foe, 80)
    assert_equal [gyarados_line(:bt_lose, 10, 87)], SpeakCapture.lines
  end

  test "keeps a hit's word for the battler it struck" do
    foe = gyarados(70)
    mine = Battler.new("Chispa", [13])
    mine.hp = 30
    mine.totalhp = 40
    mine.index = 0
    hit(foe, 2)
    PokeAccess::Battle.hp_changed(mine, 40)
    PokeAccess::Battle.hp_changed(foe, 80)
    mine_line = t(:bt_hp_change, :name => "Chispa", :verb => t(:bt_lose), :n => 10,
                                 :rest => t(:bt_hp_exact, :hp => 30, :tot => 40))
    assert_equal [mine_line, "#{t(:mv_eff_super)}. #{gyarados_line(:bt_lose, 10, 87)}"], SpeakCapture.lines
  end

  test "says nothing where the hit points did not change or the old ones are unknown" do
    PokeAccess::Battle.hp_changed(gyarados(70), 70)
    PokeAccess::Battle.hp_changed(gyarados(70), nil)
    assert_nothing_spoken
  end

  test "puts the share in the floating text's form: two decimals at most, none for a whole one" do
    { [20, 80] => "25", [10, 80] => "12,5", [-10, 80] => "12,5", [1, 3] => "33,33", [2, 3] => "66,67",
      [1, 1] => "100", [5, 0] => "0" }.each do |(diff, total), want|
      assert_equal want, PokeAccess::ReminBattle.percent_text(diff, total), "#{diff} of #{total}"
    end
  end

  private

  # A fight menu scene over battle whose effectiveness icon shows the EffectivenessCheck picture file.
  def fight_scene(battle, file, visible = true)
    icon = Icon.new("Graphics/Pictures/EffectivenessCheck/#{file}", visible)
    Scene.new(battle, { "effectivenessIcon" => icon, "fightwindow" => Window.new(0) })
  end

  # A single battle against Gyarados (Water and Flying, types 11 and 2).
  def single_battle
    Battle.new([Battler.new("Chispa", [13]), Battler.new("Gyarados", [11, 2]), nil, nil], false, false)
  end

  # Type ids as the fight menu paints their icons' names, joined.
  def painted_types(*ids)
    ids.map { |id| PBTypes.getName(id) }.join(" ")
  end

  # The fight menu's line for an effectiveness word and the foe it names.
  def foe_line(key, name, *types)
    "#{t(key)}. #{t(:rem_bt_foe_types, :name => name, :t => painted_types(*types))}"
  end

  # Gyarados across the field (index 1) with hp of its 80 hit points.
  def gyarados(hp)
    foe = Battler.new("Gyarados", [11, 2])
    foe.hp = hp
    foe.totalhp = 80
    foe.index = 1
    foe
  end

  # A hit on the battler as the game animates it, with its effectiveness (1 not very, 2 super).
  def hit(battler, effectiveness)
    fight_scene(single_battle, "x1").pbDamageAnimation(battler, effectiveness)
  end

  # Gyarados losing or gaining (verb) n hit points, as the hit points line says it with the share its bar shows left.
  def gyarados_line(verb, n, left_pct)
    t(:bt_hp_change, :name => "Gyarados", :verb => t(verb), :n => n, :rest => t(:bt_hp_pct, :n => left_pct))
  end

  # Runs the block with the game's HP option set, the options put back after.
  def with_percent_option(value)
    was = $PokemonSystem
    $PokemonSystem = SystemOptions.new(value)
    yield
  ensure
    $PokemonSystem = was
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
