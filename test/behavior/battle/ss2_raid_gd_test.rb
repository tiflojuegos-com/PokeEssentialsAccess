# Soulstones 2's edited DBK Raid Battles, read from its profile: in battle the cheer menu and the boss's barrier, on
# the overworld the den's entry screen and its rewards page.
module GameData
  class Cheer
    attr_reader :id, :command_index

    def initialize(id, name, index, text, desc)
      @id = id
      @real_name = name
      @command_index = index
      @cheer_text = text
      @description = desc
    end

    def name; @real_name; end
    def cheer_text; @cheer_text; end
    def description(level); @description ? @description[level] : ""; end

    DATA = [
      new(:Offense, "Offense Cheer", 0, "Go all-out!",
          ["Requires Cheer Lv.1 or higher.", "The team deals more damage with moves.",
           "Increases potency of the team's moves.", "The team's moves may pierce protections."]),
      new(:Defense, "Defense Cheer", 1, "Hang tough!",
          ["Requires Cheer Lv.1 or higher.", "The team takes less damage from moves.",
           "The team is immune to move effects.", "The team endures damage from moves."]),
      new(:Healing, "Healing Cheer", 2, "Heal up!",
          ["Requires Cheer Lv.1 or higher.", "Heals some of the team's HP.",
           "Heals the team's HP & cures status.", "Grants the team a wish & fully heals."]),
      new(:Counter, "Counter Cheer", 3, "Turn the tables!",
          ["Requires Cheer Lv.1 or higher.", "Reverses stat changes of both teams.",
           "Swaps the field effects on both sides.", "Removes and applies Heal Block to teams."])
    ]

    def self.get_cheer_for_index(index, _mode = 0)
      DATA.find { |c| c.command_index == index }
    end
  end
end

# The 2x2 cheer window: the cheers for the menu's mode, the cursor index and the side's cheer level.
class Battle::Scene::CheerMenu < Battle::Scene::MenuBase
  attr_reader :cheers
  attr_accessor :mode, :cheerLvl

  MAX_CHEERS = 4

  def initialize
    super
    @cheers = []
    @mode = 0
    @cheerLvl = 0
    refresh
  end

  def refresh
    @cheers.clear
    MAX_CHEERS.times { |i| @cheers.push(GameData::Cheer.get_cheer_for_index(i, @mode)) }
  end
end

class Battle::Scene
  # The kit's pbInitSprites, which builds the window once with the battle scene, kept out of initialize as other tests
  # share the class; script is the cursor's path through the menu, :use confirming.
  def raid_setup(battle, script)
    @battle = battle
    @sprites = { "cheerWindow" => Battle::Scene::CheerMenu.new }
    @script = script
  end

  # The kit's loop: the window is filled for the mode and the side's level, then runs a frame per step.
  def pbChooseCheer(mode = 0)
    cw = @sprites["cheerWindow"]
    cw.index = 0
    cw.mode = mode
    cw.cheerLvl = @battle.cheerLevel[0][0]
    cw.refresh
    ret = -1
    @script.each do |step|
      PokeAccess::Frame.run_pollers
      if step == :use
        ret = cw.index
        break
      end
      cw.index = step
    end
    ret
  end

  def pbAnimateRaidShield(battler, oldHP = 0)
    return if !battler.opposes? || (battler.shieldHP <= 0 && oldHP == 0)
    :animated
  end
end

# The den's entry and rewards screens: the chosen option shows only in the cursor sprite, which the stand-in moves as
# the kit does (y = 132 + 34 * index); the item description box; the party icons Change Party repoints.
class RaidScene
  CursorSprite = Struct.new(:y, :visible)
  TextWindow = Struct.new(:text, :visible)
  PartyIcon = Struct.new(:pokemon)

  attr_accessor :script, :reward_script, :party, :new_party, :field, :frames_before_paint, :prompt_choices

  def initialize(pkmn, rules, save_ok = true)
    @pkmn = pkmn
    @rules = rules
    @save_ok = save_ok
    @sprites = { "cursor" => CursorSprite.new(132, true), "itemtext" => TextWindow.new("", false) }
    @script = [:use]
    @reward_script = []
    @party = []
    @new_party = []
    @field = [:None, :None, nil]
  end

  def sprite(key); @sprites[key]; end

  def pbEndScene; end

  # The kit asks before entering (pbConfirmMessage): with prompt_choices, a command window shows them with its cursor
  # on the first.
  def pbSavingPrompt(_pkmn, _rules)
    Window_CommandPokemon.new(@prompt_choices).update if @prompt_choices
    @save_ok
  end

  # As the kit's: the field conditions and the party icons are set up before the texts are drawn.
  def pbStartScene(pkmn, rules)
    return false if !pbSavingPrompt(pkmn, rules)
    @weather, @terrain, @environ = @field
    @party.each_with_index { |pk, i| @sprites["partyicon_#{i}"] = PartyIcon.new(pk) }
    pbDrawTextPositions(nil, [["BASIC DEN", 97, 24], ["Begin Raid", 391, 140],
                              ["Leave Raid", 391, 174], ["Change Party", 391, 208]])
    drawTextEx(nil, 40, 250, 226, 2, "Battle ends after 10 turns.")
    pbRaidEntry
  end

  # A frame per step of script: an index moves the cursor, :change stands for Change Party returning (the icons
  # repointed at the party chosen), :battle for the raid battle the kit runs inside this loop once it has disposed of
  # the screen's sprites, :use confirms.
  def pbRaidEntry
    index = 0
    @script.each do |step|
      PokeAccess::Frame.run_pollers
      break if step == :use
      if step == :change
        @new_party.each_with_index { |pk, i| @sprites["partyicon_#{i}"].pokemon = pk }
        next
      end
      if step == :battle
        @sprites.clear
        next
      end
      index = step
      @sprites["cursor"].y = 132 + 34 * index
    end
    0
  end

  # As the kit's for a caught boss, rows in its paint order; frames_before_paint frames run before it paints, and a
  # frame per step of reward_script after (:toggle shows or hides the description box, :next moves to the next item).
  def pbRaidRewardsScreen(_outcome)
    @frames_before_paint.to_i.times { PokeAccess::Frame.run_pollers }
    @sprites["itemtext"].text = "A potion that restores 20 HP."
    pbDrawTextPositions(nil, [["View", 316, 290], ["♂", 96, 78], ["You caught Tester!", 377, 24],
                              ["Lv. 70", 32, 78], ["Abil: Pressure", 32, 290], ["Next", 438, 290]])
    @reward_script.each do |step|
      PokeAccess::Frame.run_pollers
      case step
      when :toggle then @sprites["itemtext"].visible = !@sprites["itemtext"].visible
      when :next   then @sprites["itemtext"].text = "A super potion that restores 60 HP."
      end
    end
    PokeAccess::Frame.run_pollers
  end
end

eval(Harness.source(File.join(Harness::ROOT, "games/soulstones2/raid_cheer.rb")), TOPLEVEL_BINDING,
     File.join(Harness::ROOT, "games/soulstones2/raid_cheer.rb"))
eval(Harness.source(File.join(Harness::ROOT, "games/soulstones2/raid_den.rb")), TOPLEVEL_BINDING,
     File.join(Harness::ROOT, "games/soulstones2/raid_den.rb"))

class Ss2RaidGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  MALE = "♂"
  LOCKED = "Requires Cheer Lv.1 or higher."
  RULES_TEXT = "Battle ends after 10 turns."
  POTION = "A potion that restores 20 HP."
  SUPER_POTION = "A super potion that restores 60 HP."
  # A raid battle as the cheer menu and the barrier read it: the sides' cheer levels and the raid's rules.
  RaidBattle = Struct.new(:cheerLevel, :raidRules)
  # A battler with a barrier of shieldHP bars, standing on the foe's side or not.
  ShieldedBattler = Struct.new(:shieldHP, :foe) do
    def opposes?; foe; end
  end

  test "says the cheer level as the menu opens, then each button the cursor lands on, the first queued" do
    cheer_scene(0, [1, 2, :use]).pbChooseCheer(0)
    assert_equal [[level_line(0), false], ["Go all-out!, #{LOCKED}", false], ["Hang tough!, #{LOCKED}", true],
                  ["Heal up!, #{LOCKED}", true]], SpeakCapture.log
  end

  test "hands the game the button the player confirmed" do
    assert_equal 2, cheer_scene(0, [1, 2, :use]).pbChooseCheer(0)
  end

  test "gives each button the description of the cheer level the battle holds" do
    { 0 => LOCKED, 1 => "The team deals more damage with moves.", 2 => "Increases potency of the team's moves.",
      3 => "The team's moves may pierce protections." }.each do |level, desc|
      SpeakCapture.clear
      cheer_scene(level, [:use]).pbChooseCheer(0)
      assert_equal [[level_line(level), false], ["Go all-out!, #{desc}", false]], SpeakCapture.log, "level #{level}"
    end
  end

  test "reads a button under the cursor for many frames once" do
    cheer_scene(1, [1, 1, :use]).pbChooseCheer(0)
    assert_equal [[level_line(1), false], ["Go all-out!, The team deals more damage with moves.", false],
                  ["Hang tough!, The team takes less damage from moves.", true]], SpeakCapture.log
  end

  test "says nothing from the poll once the menu has closed" do
    cheer_scene(0, [:use]).pbChooseCheer(0)
    SpeakCapture.clear
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
  end

  test "says a cheer's description only at full verbosity" do
    rows = vb_levels { PokeAccess::SS2Cheer.line(GameData::Cheer.get_cheer_for_index(1), 1) }
    assert_equal ["Hang tough!", "Hang tough!", "Hang tough!, The team takes less damage from moves."], rows
  end

  test "keeps the shout and the description for the info key whatever the verbosity" do
    PokeAccess::Config.verbosity = :brief
    PokeAccess::SS2Cheer.line(GameData::Cheer.get_cheer_for_index(1), 1)
    whole = "Hang tough!, The team takes less damage from moves."
    assert_equal [whole, whole], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "reads the kit's placeholder button, which has no shout, by its name" do
    assert_equal "None", PokeAccess::SS2Cheer.line(GameData::Cheer.new(:None, "None", -1, "", nil), 0)
  end

  test "says no cheer level for a scene without a battle, or a battle that holds none" do
    { "no battle" => Battle::Scene.new, "no level held" => cheer_scene(nil, []) }.each do |label, scene|
      assert_nil PokeAccess::SS2Cheer.level_text(scene), label
    end
  end

  test "says the bars left when the barrier animates, queued, only while it stands on the foe's side" do
    {
      "three bars of five" => [5, ShieldedBattler.new(3, true), [[bars_line(3, 5), false]]],
      "the last bar of five" => [5, ShieldedBattler.new(1, true), [[bars_line(1, 5), false]]],
      "a one-bar barrier" => [1, ShieldedBattler.new(1, true), [[bars_line(1, 1), false]]],
      "a broken barrier" => [5, ShieldedBattler.new(0, true), []],
      "the player's side" => [5, ShieldedBattler.new(3, false), []],
      "a raid with no shield size" => [nil, ShieldedBattler.new(3, true), []]
    }.each do |label, (max, battler, log)|
      SpeakCapture.clear
      cheer_scene(0, [], max).pbAnimateRaidShield(battler, 4)
      assert_equal log, SpeakCapture.log, label
    end
  end

  test "gives no barrier count for a battler that does not say its side" do
    assert_nil PokeAccess::SS2Cheer.shield_text(cheer_scene(0, []), Struct.new(:shieldHP).new(3))
  end

  test "says the entry screen as painted with the boss inside, then the option under the cursor as it moves" do
    scene = RaidScene.new(Poke.build(:name => "Tester"), { :rank => 4, :size => 3 })
    scene.script = [1, 2, :use]
    scene.pbStartScene(nil, nil)
    assert_equal [[entry_line(boss_part(4)), false], ["Begin Raid", false], ["Leave Raid", true],
                  ["Change Party", true]], SpeakCapture.log
  end

  test "says nothing when the saving prompt is refused" do
    RaidScene.new(Poke.build(:name => "Tester"), { :rank => 1 }, false).pbStartScene(nil, nil)
    assert_nothing_spoken
  end

  test "leaves the saving prompt's own question to be read while it runs" do
    scene = RaidScene.new(Poke.build(:name => "Tester"), { :rank => 1 }, false)
    scene.prompt_choices = ["Yes", "No"]
    scene.pbStartScene(nil, nil)
    assert_equal [["Yes", false]], SpeakCapture.log
  end

  test "says the boss as a silhouette with the types its icons show and its rank, never its species" do
    {
      [[], 5] => boss_part(5),
      [[:PSYCHIC], 5] => [I18n.t(:ss2_raid_hidden), I18n.t(:pc_types, :t => "TypePSYCHIC"),
                          I18n.t(:ss2_raid_rank, :n => 5)].join(", "),
      [[:PSYCHIC, :FIGHTING], 5] => [I18n.t(:ss2_raid_hidden), I18n.t(:pc_types, :t => "TypePSYCHIC TypeFIGHTING"),
                                     I18n.t(:ss2_raid_rank, :n => 5)].join(", "),
      [[:PSYCHIC], nil] => [I18n.t(:ss2_raid_hidden), I18n.t(:pc_types, :t => "TypePSYCHIC")].join(", ")
    }.each do |(types, rank), boss|
      SpeakCapture.clear
      mewtwo = Poke.build(:name => "Mewtwo", :species => :MEWTWO)
      mewtwo.define_singleton_method(:types) { types }
      RaidScene.new(mewtwo, rank ? { :rank => rank } : {}).pbStartScene(nil, nil)
      assert_equal [[entry_line(boss), false], ["Begin Raid", false]], SpeakCapture.log,
                   "types #{types.inspect}, rank #{rank.inspect}"
    end
  end

  test "leaves out the boss of a den that holds none, and the rank and icons of rules it cannot read" do
    {
      "no boss inside" => [nil, { :rank => 3, :online => true }, entry_line(nil, I18n.t(:ss2_raid_online))],
      "rules that are no table" => [Poke.build(:name => "Boss"), nil, entry_line(I18n.t(:ss2_raid_hidden))]
    }.each do |label, (boss, rules, line)|
      SpeakCapture.clear
      RaidScene.new(boss, rules).pbStartScene(nil, nil)
      assert_equal [[line, false], ["Begin Raid", false]], SpeakCapture.log, label
    end
  end

  test "names the bonus loot and online icons it draws" do
    {
      { :loot => [:RARECANDY] } => [I18n.t(:ss2_raid_bonus)],
      { :online => true } => [I18n.t(:ss2_raid_online)],
      { :loot => [:RARECANDY], :online => true } => [I18n.t(:ss2_raid_bonus), I18n.t(:ss2_raid_online)]
    }.each do |extra, icons|
      SpeakCapture.clear
      RaidScene.new(Poke.build(:name => "Boss"), { :rank => 3 }.merge(extra)).pbStartScene(nil, nil)
      assert_equal [[entry_line(boss_part(3), *icons), false], ["Begin Raid", false]], SpeakCapture.log,
                   "with #{extra.inspect}"
    end
  end

  test "names the field icons it draws, leaving out a blank one and a field that is the den's own" do
    with_raid_data({ :Basic => :Cave }, { :Forest => "Bosque", :Graveyard => "" }, { :Spores => "Esporas" }) do
      {
        "a field unlike the den's" => [[:Rain, :Electric, :Cave], [I18n.t(:w_rain), I18n.t(:bt_electric), "Cave"]],
        "the den's own field" => [[:None, :None, :Cave], nil],
        "another environment, by the game's name" => [[:None, :None, :Forest], ["Bosque"]],
        "an environment the game names blank" => [[:None, :None, :Graveyard], ["Graveyard"]],
        "a weather the battle has no word for, by the game's name" => [[:Spores, :None, :Cave], ["Esporas", "Cave"]],
        "no environment" => [[:Rain, :None, nil], [I18n.t(:w_rain)]],
        "blank icons alone" => [[:None, :None, :None], nil]
      }.each do |label, (field, names)|
        SpeakCapture.clear
        den_entry(field)
        icons = names ? [I18n.t(:ss2_raid_field, :list => names.join(", "))] : []
        assert_equal [[entry_line(boss_part(1), *icons), false], ["Begin Raid", false]], SpeakCapture.log, label
      end
    end
  end

  test "names the fog a den takes from the map in the mod's words" do
    with_raid_data({ :Basic => :Cave }, {}) { den_entry([:Fog, :None, :Cave]) }
    field = I18n.t(:ss2_raid_field, :list => [I18n.t(:w_fog), "Cave"].join(", "))
    assert_equal [[entry_line(boss_part(1), field), false], ["Begin Raid", false]], SpeakCapture.log
  end

  test "says the party its icons show on opening, and again once Change Party repoints them" do
    scene = RaidScene.new(Poke.build(:name => "Boss"), { :rank => 3 })
    rocoso = Poke.build(:name => "Rocoso")
    scene.party = [Poke.build(:name => "Chispa"), rocoso]
    scene.new_party = [Poke.build(:name => "Brasa"), rocoso]
    scene.script = [2, :change, 2, :use]
    scene.pbStartScene(nil, nil)
    opening = entry_line(boss_part(3)) + ", " + I18n.t(:ss2_raid_party, :list => "Chispa, Rocoso")
    assert_equal [[opening, false], ["Begin Raid", false], ["Change Party", true],
                  [I18n.t(:ss2_raid_party, :list => "Brasa, Rocoso"), true]], SpeakCapture.log
  end

  test "lets the entry screen go when its loop ends, so a party change after it says nothing" do
    scene = RaidScene.new(Poke.build(:name => "Boss"), { :rank => 3 })
    scene.party = [Poke.build(:name => "Chispa")]
    scene.pbStartScene(nil, nil)
    SpeakCapture.clear
    scene.sprite("partyicon_0").pokemon = Poke.build(:name => "Brasa")
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
  end

  test "says nothing more while the raid battle runs inside the entry loop with the screen's sprites gone" do
    scene = RaidScene.new(Poke.build(:name => "Boss"), { :rank => 3 })
    scene.party = [Poke.build(:name => "Chispa")]
    scene.script = [:battle, :battle, :use]
    scene.pbStartScene(nil, nil)
    opening = entry_line(boss_part(3)) + ", " + I18n.t(:ss2_raid_party, :list => "Chispa")
    assert_equal [[opening, false], ["Begin Raid", false]], SpeakCapture.log
  end

  test "names no option while the cursor sits outside the three" do
    scene = RaidScene.new(Poke.build(:name => "Tester"), { :rank => 4 })
    scene.script = [-1, 3, :use]
    scene.pbStartScene(nil, nil)
    assert_equal [[entry_line(boss_part(4)), false], ["Begin Raid", false]], SpeakCapture.log
  end

  test "says the rewards page once painted: each row with a letter, digit or sex sign, the shiny icon and the stars" do
    {
      "a boss of rank 4" => [Poke.build(:name => "Tester", :gender => 0), 4, [I18n.t(:ss2_raid_rank, :n => 4)]],
      "a shiny boss of rank 6" => [Poke.build(:name => "Tester", :gender => 0, :shiny => true), 6,
                                   [I18n.t(:pk_shiny), I18n.t(:ss2_raid_rank, :n => 6)]],
      "a boss of no rank" => [Poke.build(:name => "Tester", :gender => 0), nil, []]
    }.each do |label, (boss, rank, icons)|
      SpeakCapture.clear
      RaidScene.new(boss, rank ? { :rank => rank } : {}).pbRaidRewardsScreen(4)
      assert_equal [[(painted_rewards + icons).sort, false]], spoken_parts, label
    end
  end

  test "says the rewards page's outcome first, as the page reads" do
    RaidScene.new(Poke.build(:name => "Tester", :gender => 0), { :rank => 4 }).pbRaidRewardsScreen(4)
    assert_equal "You caught Tester!", SpeakCapture.log[0][0].split(", ").first
  end

  test "waits for the rewards page's paint before saying it" do
    scene = RaidScene.new(Poke.build(:name => "Tester", :gender => 0), { :rank => 4 })
    scene.frames_before_paint = 1
    scene.pbRaidRewardsScreen(4)
    assert_equal [[(painted_rewards + [I18n.t(:ss2_raid_rank, :n => 4)]).sort, false]], spoken_parts
  end

  test "says an item's description only while its box is shown, and the next item's while it stays up" do
    rewards([:toggle, nil, :next, :toggle])
    assert_equal [[POTION, false], [SUPER_POTION, false]], SpeakCapture.log.drop(1)
  end

  test "says the description again when its box is hidden and shown again on the same item" do
    rewards([:toggle, nil, :toggle, nil, :toggle, nil])
    assert_equal [[POTION, false], [POTION, false]], SpeakCapture.log.drop(1)
  end

  private

  # A battle scene in a raid whose player side holds the given cheer level and whose barrier is max bars, with the
  # cheer menu's cursor following script.
  def cheer_scene(level, script, max = 5)
    scene = Battle::Scene.new
    scene.raid_setup(RaidBattle.new([[level], [0]], { :shield_hp => max }), script)
    scene
  end

  # The cheer level as the menu says it on opening.
  def level_line(level)
    I18n.t(:ss2_cheer_lvl, :n => level, :max => 3)
  end

  # The bars left on the barrier, as its animation says them.
  def bars_line(left, max)
    I18n.t(:ss2_raid_shield, :n => left, :max => max)
  end

  # The boss as the entry screen shows it without type icons: a silhouette and its rank.
  def boss_part(rank)
    [I18n.t(:ss2_raid_hidden), I18n.t(:ss2_raid_rank, :n => rank)].join(", ")
  end

  # The entry screen's opening line: the den's name, the boss (nil: none), the icons given and the raid's rules.
  def entry_line(boss, *icons)
    (["BASIC DEN", boss] + icons + [RULES_TEXT]).compact.join(", ")
  end

  # The rows the rewards page paints for a caught boss.
  def painted_rewards
    ["View", MALE, "You caught Tester!", "Lv. 70", "Abil: Pressure", "Next"]
  end

  # The spoken log with each line split into its comma-separated parts, sorted, beside its interrupt flag.
  def spoken_parts
    SpeakCapture.log.map { |text, interrupt| [text.split(", ").sort, interrupt] }
  end

  # Runs the rewards page of a rank 4 boss with the description box driven by script.
  def rewards(script)
    scene = RaidScene.new(Poke.build(:name => "Tester", :gender => 0), { :rank => 4 })
    scene.reward_script = script
    scene.pbRaidRewardsScreen(4)
  end

  # Opens the entry screen of a rank 1 basic den with a boss inside, under field: [weather, terrain, environment].
  def den_entry(field)
    scene = RaidScene.new(Poke.build(:name => "Boss"), { :rank => 1, :style => :Basic })
    scene.field = field
    scene.pbStartScene(nil, nil)
  end

  # Runs the block with the kit's raid styles (each style's own battle environment), the game's environment names and
  # its weathers in place, taken out after; a weather's name is its id, as Soulstones 2 registers it, unless given.
  def with_raid_data(environs, names, weathers = {})
    style = Struct.new(:battle_environ)
    environment = Struct.new(:name)
    weather = Struct.new(:real_name)
    raid_type = Class.new
    raid_type.define_singleton_method(:get) { |s| style.new(environs[s]) }
    environments = Class.new
    environments.define_singleton_method(:get) { |e| environment.new(names[e]) }
    weather_data = Class.new
    weather_data.define_singleton_method(:get) { |w| weather.new(weathers.fetch(w, w.to_s)) }
    with_const(GameData, :RaidType, raid_type) do
      with_const(GameData, :Environment, environments) { with_const(GameData, :Weather, weather_data) { yield } }
    end
  end

  # Runs the block with mod::name set to value, put back as it was (or removed) after.
  def with_const(mod, name, value)
    had = mod.const_defined?(name, false)
    was = mod.const_get(name) if had
    mod.send(:remove_const, name) if had
    mod.const_set(name, value)
    yield
  ensure
    mod.send(:remove_const, name) if mod.const_defined?(name, false)
    mod.const_set(name, was) if had
  end
end
