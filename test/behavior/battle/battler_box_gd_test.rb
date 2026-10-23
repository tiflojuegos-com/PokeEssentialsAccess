# The HP and info keys on a battler (the sign and level its databox draws, its status, marks, stat changes, types) and
# the sign other screens draw for a Pokemon; in the gamedata pass, which loads the Deluxe Battle Kit readers.
class BattlerBoxGdTest < PokeAccessTest
  MALE = "\xE2\x99\x82"
  FEMALE = "\xE2\x99\x80"

  # Every method a box profile can override, on the Battle module and on the Deluxe Battle Kit panel.
  SEAMS = [[PokeAccess::Battle, [:shown_sex, :shown_level, :shown_hp]], [PokeAccess::DBKBattlerInfo, [:panel_level]]]

  # A battler as the databox sees it: Zorua, level 30, 50 of 100 HP, its own gender and the one it is shown with.
  class Battler
    attr_reader :index, :name, :level, :hp, :totalhp, :gender, :displayGender, :battle, :status, :pokemon

    def initialize(index, gender, shown, battle, status = :NONE)
      @index = index
      @gender = gender
      @displayGender = shown
      @battle = battle
      @status = status
      @name = "Zorua"
      @level = 30
      @hp = 50
      @totalhp = 100
      @pokemon = true
    end
  end

  # An Awakening boss, given lives (variable 189): its box draws an icon for each one past the current bar.
  class Boss < Battler
    attr_accessor :lives
  end

  # A v19+ battler, which tells whether it opposes another slot's side.
  class SidedBattler < Battler
    def opposes?(other = 0); (index & 1) != (other & 1); end
  end

  # A gen-6 battler, which has no displayGender: its own sex is the one drawn.
  OwnSexBattler = Struct.new(:index, :name, :level, :hp, :totalhp, :gender, :status, :pokemon)

  # A battler with no level to read, whose state the HP key cannot build.
  Levelless = Struct.new(:index, :name, :hp, :totalhp, :pokemon)

  # A battler with no index to read, so no side.
  Unplaced = Struct.new(:name, :level, :hp, :totalhp, :gender, :status, :pokemon)

  # A battle over its battlers, for the HP key.
  SideBattle = Struct.new(:battlers)

  # Reminiscencia's game options, whose porcentaje 1 shows HP as a percentage.
  GameSystem = Struct.new(:porcentaje)

  # Awakening's scene, whose bar breaks as a boss loses a life; the hook binds to it by name.
  class BreakScene
    def pbBreakBar(_battler); :flashed; end
  end

  class << self
    # The seams as they stand, by [module, name].
    def seam_methods
      SEAMS.flat_map { |mod, names| names.map { |n| [[mod, n], mod.method(n)] } }.to_h
    end

    # Puts the seams back as they stood.
    def put_back(seams)
      seams.each { |(mod, n), m| mod.define_singleton_method(n, m) }
    end

    # The seams a profile's box file overrides, as it overrides them: the file is evaluated once, over the seams as
    # they stand then (and with Awakening's scene under its name, for the boss box's bar-break hook), which are put
    # back after.
    def profile_overrides(path)
      @profiles ||= {}
      return @profiles[path] if @profiles.key?(path)
      before = seam_methods
      scene = !Object.const_defined?(:PokeBattle_Scene)
      Object.const_set(:PokeBattle_Scene, BreakScene) if scene
      file = File.join(Harness::ROOT, "games", path)
      verbose = $VERBOSE
      begin
        $VERBOSE = nil
        eval(Harness.source(file), TOPLEVEL_BINDING, file)
        @profiles[path] = seam_methods.reject { |key, m| before[key] == m }
      ensure
        $VERBOSE = verbose
        put_back(before)
        Object.send(:remove_const, :PokeBattle_Scene) if scene && Object.const_defined?(:PokeBattle_Scene)
      end
    end
  end

  test "a plain box says the sign it shows and the level" do
    foe = Battler.new(1, 0, 1, battle_with("dataBox_1" => Object.new))
    assert_equal state("Zorua #{FEMALE}", 30, hp(true)), PokeAccess::Battle.battler_state(foe, true),
                 "a foe under Illusion says the sign of the one it imitates"
  end

  test "the sign said is the shown sex's, the battler's own where none is shown, and none for no sex" do
    gen6 = OwnSexBattler.new(0, "Zorua", 30, 50, 100, 0, 0, true)
    { "a genderless battler" => [Battler.new(0, 2, 2, battle_with({})), "Zorua"],
      "a battler with no displayGender" => [gen6, "Zorua #{MALE}"] }.each do |what, (b, name)|
      assert_equal state(name, 30, hp(false)), PokeAccess::Battle.battler_state(b, false), what
    end
  end

  test "the player's own battler's HP is exact unless asked otherwise" do
    mine = Battler.new(0, 0, 0, battle_with({}))
    assert_equal state("Zorua #{MALE}", 30, hp(false)), PokeAccess::Battle.battler_state(mine)
  end

  test "no battler has no state" do
    assert_nil PokeAccess::Battle.battler_state(nil)
  end

  test "a Deluxe Battle Kit styled box on the player's side says the real sign and the level" do
    mine = Battler.new(0, 0, 1, battle_with("dataBox_0" => styled(:Long)))
    assert_equal state("Zorua #{MALE}", 30, hp(false)), PokeAccess::Battle.battler_state(mine, false),
                 "the sign of the Pokemon itself, not the one Illusion shows"
  end

  test "a Deluxe Battle Kit styled box on the foe's side says the name alone" do
    battle = battle_with("dataBox_1" => styled(:Long))
    assert_equal bare("Zorua", hp(true)), PokeAccess::Battle.battler_state(Battler.new(1, 0, 1, battle), true)
  end

  test "Relict's styled foe box says the real sign and the level, and a plain box stays the core's" do
    with_profile("relict/styled_box.rb") do
      battle = battle_with("dataBox_1" => styled(:Long), "dataBox_3" => Object.new)
      { "the styled box" => [Battler.new(1, 0, 1, battle), "Zorua #{MALE}"],
        "the styled box of a genderless foe" => [Battler.new(1, 2, 1, battle), "Zorua"],
        "the plain box" => [Battler.new(3, 0, 1, battle), "Zorua #{FEMALE}"] }.each do |what, (foe, name)|
        assert_equal state(name, 30, hp(true)), PokeAccess::Battle.battler_state(foe, true), what
      end
    end
  end

  test "Soulstones 2's raid box says a foe's name, its level only in the Basic style, and the player's own sign" do
    with_raid_box do |raid|
      battle = battle_with("dataBox_0" => styled(:Long, raid), "dataBox_1" => styled(:Long, raid),
                           "dataBox_2" => styled(:Long), "dataBox_3" => styled(:Basic, raid))
      { 1 => bare("Zorua", hp(true)), 3 => state("Zorua", 30, hp(true)), 0 => state("Zorua #{MALE}", 30, hp(false)),
        2 => state("Zorua #{FEMALE}", 30, hp(false)) }.each do |index, line|
        assert_equal line, PokeAccess::Battle.battler_state(Battler.new(index, 0, 1, battle), index.odd?),
                     "the box of slot #{index}"
      end
    end
  end

  test "in an Awakening boss battle the box draws no sign, and no level for a foe" do
    with_profile("awakening/boss_box.rb") do
      $game_switches[200] = true
      battle = battle_with({})
      assert_equal bare("Zorua", hp(true)), PokeAccess::Battle.battler_state(Battler.new(1, 0, 0, battle), true),
                   "the boss"
      assert_equal state("Zorua", 30, hp(false)), PokeAccess::Battle.battler_state(Battler.new(0, 1, 1, battle), false),
                   "the player's own"
    end
  end

  test "outside an Awakening boss battle the box is the plain one" do
    with_profile("awakening/boss_box.rb") do
      $game_switches[200] = false
      foe = Battler.new(1, 0, 0, battle_with({}))
      assert_equal state("Zorua #{MALE}", 30, hp(true)), PokeAccess::Battle.battler_state(foe, true)
    end
  end

  test "with the game's switches unreadable the Awakening box is the plain one" do
    with_profile("awakening/boss_box.rb") do
      without_switches do
        foe = Battler.new(1, 0, 0, battle_with({}))
        assert_equal state("Zorua #{MALE}", 30, hp(true)), PokeAccess::Battle.battler_state(foe, true)
      end
    end
  end

  test "in an Awakening boss battle a battler whose side cannot be read keeps its level" do
    with_profile("awakening/boss_box.rb") do
      $game_switches[200] = true
      unplaced = Unplaced.new("Zorua", 30, 50, 100, 0, :NONE, true)
      assert_equal state("Zorua", 30, hp(false)), PokeAccess::Battle.battler_state(unplaced, false)
    end
  end

  test "an Awakening boss's HP says its spare life icons, none on its last life" do
    with_profile("awakening/boss_box.rb") do
      $game_switches[200] = true
      boss = Boss.new(1, 0, 0, battle_with({}))
      { 3 => "#{hp(true)}, #{t(:awk_lives, :n => 2)}", 2 => "#{hp(true)}, #{t(:awk_lives, :n => 1)}", 1 => hp(true),
        nil => hp(true) }.each do |lives, line|
        boss.lives = lives
        assert_equal bare("Zorua", line), PokeAccess::Battle.battler_state(boss, true), "with #{lives.inspect} lives"
      end
    end
  end

  test "an Awakening boss's bar breaking says the life lost and the icons left, or that it is the last" do
    with_profile("awakening/boss_box.rb") do
      boss = Boss.new(1, 0, 0, battle_with({}))
      boss.lives = 2
      SpeakCapture.clear
      assert_equal :flashed, BreakScene.new.pbBreakBar(boss), "the scene's own break runs"
      assert_equal [[t(:awk_life_lost, :name => "Zorua", :rest => t(:awk_lives_left, :n => 1)), false]], SpeakCapture.log,
                   "one icon left"
      boss.lives = 1
      SpeakCapture.clear
      BreakScene.new.pbBreakBar(boss)
      assert_equal [[t(:awk_life_lost, :name => "Zorua", :rest => t(:awk_lives_last)), false]], SpeakCapture.log,
                   "the last life"
    end
  end

  test "Reminiscencia's box says every battler's HP as painted, exact or with its option a percentage, and no level" do
    with_profile("reminiscencia/battle_box.rb") do
      foe = Battler.new(1, 0, 0, battle_with({}))
      { 0 => hp(false), 1 => hp(true) }.each do |option, line|
        with_system(GameSystem.new(option)) do
          assert_equal bare("Zorua #{MALE}", line), PokeAccess::Battle.battler_state(foe, true),
                       "with porcentaje at #{option}"
        end
      end
    end
  end

  test "Reminiscencia's box says the exact HP when the game's options lack its choice" do
    with_profile("reminiscencia/battle_box.rb") do
      with_system(Object.new) do
        foe = Battler.new(1, 0, 0, battle_with({}))
        assert_equal bare("Zorua #{MALE}", hp(false)), PokeAccess::Battle.battler_state(foe, true)
      end
    end
  end

  test "Royal's Zacian battle says the foe's level as the unknown its box paints, the player's own kept" do
    with_profile("royal/zacian_battle.rb") do
      $game_switches[84] = true
      battle = battle_with({})
      unknown = state("Zorua #{MALE}", t(:bt_level_unknown), hp(true))
      foes = { "the foe" => SidedBattler.new(1, 0, 0, battle), "a foe with no opposes?" => Battler.new(1, 0, 0, battle) }
      foes.each { |what, foe| assert_equal unknown, PokeAccess::Battle.battler_state(foe, true), what }
      assert_equal state("Zorua #{MALE}", 30, hp(false)),
                   PokeAccess::Battle.battler_state(SidedBattler.new(0, 0, 0, battle), false), "the player's own"
    end
  end

  test "in Royal's Zacian battle a battler whose side cannot be read keeps its level" do
    with_profile("royal/zacian_battle.rb") do
      $game_switches[84] = true
      unplaced = Unplaced.new("Zorua", 30, 50, 100, 0, :NONE, true)
      assert_equal state("Zorua #{MALE}", 30, hp(false)), PokeAccess::Battle.battler_state(unplaced, false)
    end
  end

  test "with the game's switches unreadable Royal's box is the plain one" do
    with_profile("royal/zacian_battle.rb") do
      without_switches do
        foe = Battler.new(1, 0, 0, battle_with({}))
        assert_equal state("Zorua #{MALE}", 30, hp(true)), PokeAccess::Battle.battler_state(foe, true)
      end
    end
  end

  test "Royal's battler panel paints the unknown level only in the Zacian battle" do
    with_profile("royal/zacian_battle.rb") do
      foe = Battler.new(1, 0, 0, battle_with({}))
      { true => :unknown, false => 30 }.each do |on, level|
        $game_switches[84] = on
        assert_equal level, PokeAccess::DBKBattlerInfo.panel_level(foe), "with the switch #{on ? 'on' : 'off'}"
      end
    end
  end

  test "Infinite Fusion's no-levels mode says no level for anyone" do
    with_no_levels_switch do
      with_profile("infinitefusion_common/no_levels.rb") do
        mine = Battler.new(0, 0, 0, battle_with({}))
        { true => bare("Zorua #{MALE}", hp(false)), false => state("Zorua #{MALE}", 30, hp(false)) }.each do |on, line|
          $game_switches[774] = on
          assert_equal line, PokeAccess::Battle.battler_state(mine, false), "with the mode #{on ? 'on' : 'off'}"
        end
      end
    end
  end

  test "with the game's switches unreadable Infinite Fusion says the level" do
    with_no_levels_switch do
      with_profile("infinitefusion_common/no_levels.rb") do
        without_switches do
          mine = Battler.new(0, 0, 0, battle_with({}))
          assert_equal state("Zorua #{MALE}", 30, hp(false)), PokeAccess::Battle.battler_state(mine, false)
        end
      end
    end
  end

  test "a battler's status follows its HP, by its name" do
    tails = { :BURN => ", StatusBURN", :NONE => "", 1 => ", #{t(:st_sleep)}", 3 => ", #{t(:st_burn)}", 0 => "", 9 => "" }
    tails.each do |status, tail|
      foe = Battler.new(1, 0, 1, battle_with({}), status)
      assert_equal state("Zorua #{FEMALE}", 30, hp(true)) + tail, PokeAccess::Battle.battler_state(foe, true),
                   "status #{status.inspect}"
    end
  end

  test "a status the game names blank adds nothing" do
    blank = Object.new
    def blank.status_name(_status); ""; end
    foe = Battler.new(1, 0, 1, battle_with({}), :NAMELESS)
    Harness.with_provider(blank, 30) do
      assert_equal state("Zorua #{FEMALE}", 30, hp(true)), PokeAccess::Battle.battler_state(foe, true)
    end
  end

  test "the marks its box drew follow, from the medium verbosity" do
    foe = Battler.new(1, 0, 1, battle_with({}))
    foe.instance_variable_set(:@pa_marks, [t(:bt_mark_mega), t(:pk_shiny)])
    plain = state("Zorua #{FEMALE}", 30, hp(true))
    marked = "#{plain}, #{t(:bt_mark_mega)}, #{t(:pk_shiny)}"
    assert_equal [plain, marked, marked], vb_levels { PokeAccess::Battle.battler_state(foe, true) }
  end

  test "its stat changes close the line, kept by stat or by stat index" do
    { { :ATTACK => 1, :DEFENSE => 0, :SPEED => -2, :EVASION => nil } => "StatATTACK +1, StatSPEED -2",
      [nil, 1, 0, -2] => "Stat1 +1, Stat3 -2" }.each do |stages, list|
      foe = Battler.new(1, 0, 1, battle_with({}))
      foe.instance_variable_set(:@stages, stages)
      assert_equal state("Zorua #{FEMALE}", 30, hp(true)) + t(:bt_changes, :list => list),
                   PokeAccess::Battle.battler_state(foe, true), "stages #{stages.inspect}"
    end
  end

  test "the HP key says each active battler of the asked side, in slot order" do
    battle = battle_with({})
    mine = Battler.new(0, 0, 0, battle)
    partner = Battler.new(2, 1, 1, battle)
    foe = Battler.new(1, 0, 0, battle)
    PokeAccess::Battle.set_battle(SideBattle.new([mine, foe, partner, nil]))
    { false => [state("Zorua #{MALE}", 30, hp(false)), state("Zorua #{FEMALE}", 30, hp(false))].join(". "),
      true => state("Zorua #{MALE}", 30, hp(true)) }.each do |foes, line|
      SpeakCapture.clear
      PokeAccess::Battle.announce_hp(foes)
      assert_equal [[line, true]], SpeakCapture.log, foes ? "the foes" : "the player's side"
    end
  end

  test "the HP key leaves out an empty slot and a battler it cannot read, and says when no one is left" do
    empty = OwnSexBattler.new(1, "Zorua", 30, 50, 100, 0, 0, nil)
    unreadable = Levelless.new(3, "Zorua", 50, 100, true)
    PokeAccess::Battle.set_battle(SideBattle.new([nil, empty, Battler.new(2, 0, 0, battle_with({})), unreadable]))
    PokeAccess::Battle.announce_hp(true)
    assert_equal [[t(:bt_no_pokemon), true]], SpeakCapture.log
  end

  test "the HP key with no battle says the party: each member's name and HP, and its ailment or that it fainted" do
    team = [Poke.build(:name => "Pikachu", :hp => 35, :totalhp => 40),
            Poke.build(:name => "Charmander", :hp => 20, :totalhp => 39, :status => :POISON),
            Poke.build(:name => "Bulba", :hp => 0, :totalhp => 44, :status => :POISON)]
    with_party(team) { PokeAccess::Battle.announce_hp(false) }
    said = [member("Pikachu", 35, 40), "#{member("Charmander", 20, 39)}, #{GameData::Status.get(:POISON).name}",
            "#{member("Bulba", 0, 44)}, #{t(:pk_fainted)}"].join(". ")
    assert_equal [[said, true]], SpeakCapture.log
  end

  test "the HP key with no battle and no one in the party says there is no Pokemon" do
    with_party([]) { PokeAccess::Battle.announce_hp(true) }
    assert_equal [[t(:pty_none), true]], SpeakCapture.log
  end

  test "a foe's types are the ones it is shown with" do
    disguise = typed_poke("Pikachu", [:ELECTRIC])
    zoroark = typed_poke("Zoroark", [:DARK])
    curse = lambda { |third| third ? [:WATER, :GRASS] : [:WATER] }
    { "under Illusion" => [answering(:effects => { PBEffects::Illusion => disguise }, :pokemon => zoroark),
                           ["TypeELECTRIC"]],
      "an Illusion kept as a flag" => [answering(:effects => { PBEffects::Illusion => true }, :pbTypes => [:WATER]),
                                       ["TypeWATER"]],
      "a third type a move added" => [answering(:effects => {}, :pbTypes => curse), ["TypeWATER", "TypeGRASS"]],
      "a gen-6 battler's two types" => [answering(:type1 => :FIRE, :type2 => :FLYING), ["TypeFIRE", "TypeFLYING"]],
      "a gen-6 battler's one type, kept twice" => [answering(:type1 => :FIRE, :type2 => :FIRE), ["TypeFIRE"]],
      "no battle types" => [answering(:pokemon => zoroark), ["TypeDARK"]] }.each do |what, (battler, types)|
      assert_equal types, PokeAccess::Battle.shown_types(battler), what
    end
  end

  test "the summary's first page and the info key's sheet say the name with the sign drawn" do
    pk = Poke.build(:name => "Chispa", :gender => 1)
    head = t(:sum_data_of, :name => "Chispa #{FEMALE}", :level => 25)
    { "the summary" => PokeAccess::SummaryGameData.info_text(pk),
      "the info key" => PokeAccess::Info.summary_text(pk) }.each do |what, text|
      assert_equal head, text.to_s[0, head.length], "#{what}: #{text}"
    end
  end

  test "the at-a-glance line says the sign drawn" do
    pk = Poke.build(:name => "Chispa", :gender => 1)
    glance = t(:pk_glance, :name => "Chispa", :level => 25, :hp => 40, :tot => 40)
    assert_equal "#{glance} #{FEMALE}.", PokeAccess::Info.pokemon_info(pk)
  end

  test "Better Summary's ability page says the sign it paints, then the item line" do
    pk = Poke.build(:name => "Chispa", :gender => 1)
    assert_equal [FEMALE, t(:sum_item, :i => t(:bs_no_item))], PokeAccess::BetterSummary.extras(pk)
  end

  test "the Deluxe Battle Kit panel names a battler as it draws it" do
    zoroark = Poke.build(:name => "Zoroark", :gender => 0)
    absol = Poke.build(:name => "Absol", :gender => 1)
    panels = { "a foe, as the Pokemon it displays" => [panel_battler(true, false, zoroark, absol), ["Absol", FEMALE]],
               "a raid boss, with no sign" => [panel_battler(true, true, zoroark, absol), ["Absol"]],
               "the player's own, as it is" => [panel_battler(false, false, zoroark, absol), ["Zoroark", MALE]] }
    panels.each do |what, (b, want)|
      assert_equal want, PokeAccess::DBKBattlerInfo.identity_parts(b), what
    end
  end

  test "the battler selection grid names each slot as it draws it" do
    zoroark = Poke.build(:name => "Zoroark", :gender => 0)
    absol = Poke.build(:name => "Absol", :gender => 1)
    { false => "Absol #{FEMALE}", true => "Absol" }.each do |raid, foe_line|
      scene = Object.new
      sides = { :allSameSideBattlers => [panel_battler(false, raid, zoroark, absol)],
                :allOtherSideBattlers => [panel_battler(true, raid, zoroark, absol)], :pbGetOwnerFromBattlerIndex => nil }
      scene.instance_variable_set(:@battle, answering(sides))
      assert_equal "Zoroark #{MALE}", PokeAccess::DBKSelectors.battler_text(scene, 0, 0), "the player's own slot"
      assert_equal foe_line, PokeAccess::DBKSelectors.battler_text(scene, 1, 0),
                   raid ? "a raid boss's slot" : "a foe's slot"
    end
  end

  test "the Deluxe Battle Kit panel says the stat changes with no stop stranded before them" do
    foe = answering(:lastMoveUsed => nil)
    foe.instance_variable_set(:@stages, { :ATTACK => -1 })
    assert_equal [t(:bt_changes, :list => "StatATTACK -1").sub(/\A\.\s*/, "")],
                 PokeAccess::DBKBattlerInfo.detail_parts(foe, false)
  end

  private

  # The HP key's line for a battler with its level.
  def state(name, level, hp)
    t(:bt_state, :name => name, :level => level, :hp => hp)
  end

  # The HP key's line for a battler whose box draws no level.
  def bare(name, hp)
    t(:bt_state_nolevel, :name => name, :hp => hp)
  end

  # Zorua's 50 of 100 HP as said: a percentage for a foe, exact for the player's own.
  def hp(as_percent)
    as_percent ? t(:bt_hp_pct, :n => 50) : t(:bt_hp_exact, :hp => 50, :tot => 100)
  end

  # A battle whose scene holds the given databoxes under the names the scene keeps them by.
  def battle_with(boxes)
    scene = Object.new
    scene.instance_variable_set(:@sprites, boxes)
    answering(:scene => scene)
  end

  # A databox a Deluxe Battle Kit battle rule styled, of the given class.
  def styled(id, klass = Object)
    box = klass.new
    box.instance_variable_set(:@style, Struct.new(:id).new(id))
    box
  end

  # An object answering each given method with its value; a Proc is called with the arguments.
  def answering(methods)
    o = Object.new
    methods.each do |name, value|
      o.define_singleton_method(name) { |*args| value.respond_to?(:call) ? value.call(*args) : value }
    end
    o
  end

  # A Pokemon with these modern types.
  def typed_poke(name, types)
    pk = Poke.build(:name => name)
    pk.define_singleton_method(:types) { types }
    pk
  end

  # A battler as the Deluxe Battle Kit's panel and grid read it: the Pokemon it is and the one it displays.
  def panel_battler(foe, raid, real, shown)
    answering(:name => shown.name, :opposes? => foe, :isRaidBoss? => raid, :pokemon => real, :displayPokemon => shown)
  end

  # Runs the block with a profile's battle-box overrides on the seams, which are put back after.
  def with_profile(path)
    seams = self.class.seam_methods
    self.class.put_back(self.class.profile_overrides(path))
    yield
  ensure
    self.class.put_back(seams) if seams
  end

  # Runs the block with Soulstones 2's raid box class and its profile over the core's sex and level, a game without
  # the Deluxe Battle Kit, whose override answers every styled box alike; yields the raid box class.
  def with_raid_box
    made = !Battle::Scene.const_defined?(:RaidPokemonDataBox)
    Battle::Scene.const_set(:RaidPokemonDataBox, Class.new) if made
    chained = [:shown_sex, :shown_level].map { |n| [n, PokeAccess::Battle.method(n)] }.to_h
    chained.each_key { |n| PokeAccess::Battle.define_singleton_method(n, core_form(n)) }
    with_profile("soulstones2/styled_box.rb") { yield Battle::Scene::RaidPokemonDataBox }
  ensure
    chained.each { |n, m| PokeAccess::Battle.define_singleton_method(n, m) } if chained
    Battle::Scene.send(:remove_const, :RaidPokemonDataBox) if made
  end

  # The Battle module's own form of a method, under every override stacked on it: the first override keeps it under
  # the lowest numbered alias.
  def core_form(name)
    meta = (class << PokeAccess::Battle; self; end)
    first = meta.instance_methods.map { |m| m.to_s }.grep(/\A#{name}__pa_override_\d+\z/).min_by { |m| m[/\d+\z/].to_i }
    PokeAccess::Battle.method(first || name)
  end

  # Runs the block with the game's switches unreadable, put back after.
  def without_switches
    saved = $game_switches
    $game_switches = nil
    yield
  ensure
    $game_switches = saved
  end

  # Runs the block with these game options as $PokemonSystem, put back after.
  def with_system(system)
    saved = $PokemonSystem
    $PokemonSystem = system
    yield
  ensure
    $PokemonSystem = saved
  end

  # A party member's name and HP, as the party screen words them without the level.
  def member(name, hp, tot)
    t(:pty_member_nolv, :name => name, :sex => "", :hp => hp, :tot => tot)
  end

  # Runs the block with the player's party as these members, put back after.
  def with_party(members)
    saved = $player
    $player = Struct.new(:party).new(members)
    yield
  ensure
    $player = saved
  end

  # Runs the block with Infinite Fusion's switch number for the no-levels mode defined.
  def with_no_levels_switch
    made = !Object.const_defined?(:SWITCH_NO_LEVELS_MODE)
    Object.const_set(:SWITCH_NO_LEVELS_MODE, 774) if made
    yield
  ensure
    Object.send(:remove_const, :SWITCH_NO_LEVELS_MODE) if made
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
