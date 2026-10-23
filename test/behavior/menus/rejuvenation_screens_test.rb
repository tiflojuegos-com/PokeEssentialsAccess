# Rejuvenation's own screens (games/rejuvenation), each read from what it paints: the level-up stat window, its quest
# journal, the CyberNav's achievements and Move Tutor, the passwords, and the Xen tower's blessings and Luck Swap.
Harness.load_common("rv_common")

# The game's stat window, painted beside the message of a level up or a vitamin.
def pbStatChangeDisplayWindow(_pokemon, _oldstats, _opts = {}); :window; end

# The game's used-items windows, painted beside the message of the party's auto-heal.
def pbUsedItemsDisplay(_message, _useditems); :windows; end

# The CyberNav's achievements: a hidden command window moving over painted buttons, each achievement with its levels.
class PokemonAchievementsScene
  def initialize(win)
    @sprites = { "command_window" => win }
    @achievements = [{ :name => "Catcher", :description => "Catch Pokemon." },
                     { :name => "Battler", :description => "Win battles." }]
    @achievementInternalNames = [:CATCH, :BATTLE]
    @_buttons = [[:CATCH, [10, 50, 100]], [:BATTLE, [5, 10]]]
  end

  def update; nil; end
end

# The pick after a Xen tower floor: a box per blessing, each painting its rank, and an arrow that wraps at three.
class BlessingsScene
  def initialize(blessings, ranks)
    @blessings = blessings
    @index = 0
    @sprites = {}
    ranks.each_with_index do |r, i|
      box = Object.new
      box.instance_variable_set(:@rank, r)
      @sprites["blessing#{i}"] = box
    end
  end

  def changeIndex(val)
    return if @blessings.length <= 1
    @index += val
    @index = 2 if @index < 0
    @index = 0 if @index > 2
  end
end

# The overlay of blessings gained: focused from the keyboard on its first cell, its info window rewritten for the cell
# under the cursor while it has the focus.
class BlessingsOverlay
  attr_accessor :index

  def initialize
    @focused = false
    @index = 0
  end

  def focus
    @focused = true
    @index = 0
    updateInfoWindow
  end

  def updateInfoWindow; nil; end
  def close; @focused = false; end
end

# The Luck Swap: a row of balls, the Pokemon under the arrow named large above it, and the help line each phase paints
# under the row.
class LuckSwapScene
  attr_writer :index

  def initialize(names)
    @names = names
    @length = names.length
    @index = 0
    @mode = :pick
    @party = false
  end

  def getMonDisplay; "<r><fs=45>#{@names.fetch(@index)}</fs></r>"; end
  def pbUpdate; nil; end

  # The pick opening: its title and help painted, then the fade that runs pbUpdate.
  def startLuckponPick
    drawFormattedTextEx(nil, 8, 46, 276, "<fs=45>LUCK SWAP</fs>")
    drawFormattedTextEx(nil, 8, 304, 400, "Choose a MONSTER!")
    pbUpdate
  end

  # The swap opening: the party's row up, its title and help painted, then the fade.
  def startLuckponSwap(_new_pokemon)
    @mode = :swap
    @party = true
    @index = 0
    drawFormattedTextEx(nil, 8, 46, 276, "<fs=45>LUCK SWAP</fs>")
    drawFormattedTextEx(nil, 8, 304, 276, "Choose a MONSTER to swap!")
    pbUpdate
  end

  # A party Pokemon swapped out: the rentals' row comes up, updated before its help is painted.
  def pbSwapChosen(pkmnindex)
    @pkmnindex = pkmnindex
    @mode = :swapPicked
    @party = false
    @index = 0
    pbUpdate
    drawFormattedTextEx(nil, 8, 304, 276, "Choose a MONSTER!")
  end

  # The swap undone: back on the party's row, on the Pokemon that was picked.
  def pbSwapCanceled
    @mode = :swap
    @party = true
    @index = @pkmnindex
    pbUpdate
    drawFormattedTextEx(nil, 8, 304, 276, "Choose a MONSTER to swap!")
  end
end

# The LocationWindows a map shows: a place's sign, and the popup of an achievement's level reached.
class LocationWindow
  def initialize(name, _viewport = nil); @name = name; end
end

# The Move Tutor app of the CyberNav: its entries are moves, or [move, item, quantity] for one still to be paid for,
# listed by name in a command window that pbUpdate updates with the scene's sprites; X and A sort the list by
# rebuilding it.
class Scene_MoveTutor
  def initialize(moves, names)
    @moves = moves
    @names = names
    @sprites = { "commands" => Window_DrawableCommand.new(names) }
  end

  def pbUpdate
    @sprites["commands"].update
    nil
  end

  def refreshMoveList; @sprites["commands"] = Window_DrawableCommand.new(@names); end
end

# The bag, whose pbPartyCanLearnThisMove? gives the tutor's marks.
class PokemonBag; end

# The passwords menu: its rows as the command reader takes them, the bulk passwords' list opening inside the other.
class PasswordEntry
  def entryForPasswords(bulklist)
    rows = bulklist ? ["~ Bulk Speed"] : ["Manual Entry", "> Speedy", "    Hard Mode"]
    inner = bulklist ? [] : entryForPasswords(true)
    inner + rows.map { |r| PokeAccess::Menus.checkbox_row(r) }
  end
end

class RejuvenationScreensTest < PokeAccessTest
  # The profile files of these screens, in the manifest's order.
  PROFILE_FILES = %w[level_up used_items quests achievements blessings luck_swap passwords move_tutor]
  # The quest plugin's readers the profile overrides.
  QUEST_READERS = [:overview, :new_badge?, :other_lines]

  # A Pokemon as the stat window reads it.
  Mon = Struct.new(:stats) do
    def getStats; stats; end
  end
  # A quest of the journal: its stage, where it was found and whether it shows the new badge.
  Quest = Struct.new(:id, :stage, :location, :notify)
  # A quest that also keeps the time it started, which the plugin's page paints and Rejuvenation's does not.
  TimedQuest = Struct.new(:id, :stage, :location, :notify, :time)
  # The player as the achievements read it.
  Holder = Struct.new(:achievements)
  # The player and the party as the Move Tutor reads them.
  Trainer = Struct.new(:party)
  Member = Struct.new(:name)
  # The engine's $cache, whose data provider answers pkmn, moves and abil, and a move's data in it.
  Cache = Struct.new(:pkmn, :moves, :abil)
  MoveData = Struct.new(:move, :type, :maxpp)
  MOVES = { :SURF => MoveData.new(:SURF, :WATER, 15), :CUT => MoveData.new(:CUT, :NORMAL, 30) }
  TYPE_NAMES = { :getTypeName => lambda { |ty| { :WATER => "Water", :NORMAL => "Normal" }[ty].to_s } }
  # The blessings the player gained, and the game's helpers over them; the description in full adds " in full".
  GAINED = { :swift => 1, :sturdy => 3, :keen => 2 }
  BLESSINGS = { :getPlayerBlessings => lambda { GAINED }, :getBlessingRank => lambda { |b| GAINED[b] || 0 },
                :getBlessingName => lambda { |b| b.to_s.capitalize },
                :getBlessingRules => lambda { |b| { :sturdy => ["Only in battle."], :keen => ["", "Only at night."] }[b] || [] },
                :getBlessingDesc => lambda { |b, rank, *full| "#{b} power #{rank}#{full[0] ? ' in full' : ''}" } }
  # A getBlessingName that fails, as for a blessing the game's data lacks.
  NAMELESS = { :getBlessingName => lambda { |b| raise KeyError, "no blessing #{b}" } }

  # The game's $quest_data: the overview follows the stage; Q1 never expires, Q2 at a point the data names, Q3 is
  # blank and has no count of stages.
  class QuestData
    def getName(id); "Quest #{id}"; end
    def getQuestDescription(id, stage); "Overview of #{id} at stage #{stage}"; end
    def getStageDescription(_id, stage); "Task #{stage}"; end
    def getStageLocation(_id, _stage); "Gearen City"; end
    def getMaxStagesForQuest(id); id == :Q3 ? nil : 4; end
    def getQuestGiver(_id); "nil"; end
    def getQuestReward(_id); "Rare Candy"; end
    def getQuestTermination(id); { :Q1 => "", :Q2 => "End of Chapter 5", :Q3 => "nil" }[id]; end
  end

  # The achievements the player holds: Catcher at level 1 of 3, Battler at 2 of 2.
  class Achievements
    def getLevel(k); k == :CATCH ? 1 : 2; end
    def getProgress(k); k == :CATCH ? 12 : 7; end
    def getMilestone(k); k == :CATCH ? 50 : 10; end
  end

  # The achievements' hidden command window, whose cursor moves over the painted buttons.
  class ListWindow
    attr_accessor :index, :active

    def initialize
      @index = 0
      @active = true
    end
  end

  class << self
    # The profile's overrides of the quest plugin's readers and of the checkbox rows, kept aside by load_profiles.
    attr_reader :quest_readers, :checkbox_row
  end

  # Evaluates each profile file once, as boot does. The quest readers and the checkbox row it overrides are kept aside
  # and the plugin's and core's put back, so the other tests of the process keep theirs; the profiles and overrides
  # listed are put back too.
  def self.load_profiles
    ui = PokeAccess::QuestUI
    menus = PokeAccess::Menus.singleton_class
    plugin = QUEST_READERS.map { |m| [m, ui.method(m)] }
    core = menus.instance_method(:checkbox_row)
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    PROFILE_FILES.each do |name|
      path = File.join(Harness::ROOT, "games", "rejuvenation", "#{name}.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
    end
    @quest_readers = QUEST_READERS.map { |m| [m, ui.method(m)] }
    @checkbox_row = menus.instance_method(:checkbox_row)
  ensure
    plugin.each { |m, f| ui.define_singleton_method(m, f) }
    menus.send(:define_method, :checkbox_row, core)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end
  load_profiles

  test "the stat window says nothing as it comes up, then each change and its new value after the message" do
    assert_equal :window, pbStatChangeDisplayWindow(Mon.new([45, 30, 28, 33, 31, 40]), [44, 28, 28, 31, 32, 38],
                                                    :highlight => false), "the window comes up as it would"
    assert_nothing_spoken "the message comes first"
    PokeAccess.say_dialogue("Axew grew to Level 12!")
    gains = [t(:rj_stat_up, :stat => t(:st_hp), :n => 1, :v => 45), t(:rj_stat_up, :stat => t(:st_atk), :n => 2, :v => 30),
             t(:rj_stat_up, :stat => t(:st_spatk), :n => 2, :v => 33),
             t(:rj_stat_down, :stat => t(:st_spdef), :n => 1, :v => 31),
             t(:rj_stat_up, :stat => t(:st_speed), :n => 2, :v => 40)]
    assert_equal [["Axew grew to Level 12!", false], [gains.join(", "), false]], SpeakCapture.log
  end

  test "with no stat changed, the message goes alone" do
    pbStatChangeDisplayWindow(Mon.new([45, 30, 28, 33, 31, 40]), [45, 30, 28, 33, 31, 40])
    PokeAccess.say_dialogue("It won't have any effect.")
    assert_equal [["It won't have any effect.", false]], SpeakCapture.log
  end

  test "the auto-heal's items are said after its message, each with how many were used and how many are left" do
    with_bag(25 => 4, 1 => 0) do
      assert_equal :windows, pbUsedItemsDisplay("Your Pokémon were healed!", [[25, 2], [1, 1]])
      assert_nothing_spoken "the message comes first"
      PokeAccess.say_dialogue("Your Pokémon were healed!")
    end
    items = [t(:rj_used_item, :name => "Repel", :n => 2, :left => 4), t(:rj_used_item, :name => "Pocion", :n => 1, :left => 0)]
    assert_equal [["Your Pokémon were healed!", false], [items.join(", "), false]], SpeakCapture.log
  end

  test "an auto-heal that used nothing leaves its message alone" do
    with_bag({}) { pbUsedItemsDisplay("Your Pokémon were healed!", []) }
    PokeAccess.say_dialogue("Your Pokémon were healed!")
    assert_equal [["Your Pokémon were healed!", false]], SpeakCapture.log
  end

  test "a Pokemon whose stats cannot be read leaves its message alone" do
    assert_equal :window, pbStatChangeDisplayWindow(Object.new, [45, 30, 28, 33, 31, 40])
    PokeAccess.say_dialogue("Riolu grew to Level 9!")
    assert_equal [["Riolu grew to Level 9!", false]], SpeakCapture.log
  end

  test "the quest overview follows the stage, each part after its painted label" do
    with_quests { PokeAccess::QuestUI.detail(Quest.new(:Q1, 2, "Route 2", true), :description) }
    line = ["Quest Q1", t(:quest_overview, :text => "Overview of Q1 at stage 2"), t(:quest_task, :text => "Task 2"),
            t(:quest_location, :text => "Gearen City")].join(". ")
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "the quest's second page says progress, giver, place, expiry and reward, shown while it runs, and no date" do
    with_quests { PokeAccess::QuestUI.detail(TimedQuest.new(:Q1, 2, "Route 2", true, Time.at(0)), :other) }
    line = ["Quest Q1", t(:quest_stage, :n => 2, :tot => 4), t(:quest_giver, :who => t(:quest_unset)),
            t(:quest_where, :where => "Route 2"), t(:rj_quest_expires, :when => t(:rj_quest_never)),
            t(:quest_reward, :what => "Rare Candy")].join(". ")
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "a quest with no count of stages says no progress on its second page" do
    with_quests { PokeAccess::QuestUI.detail(Quest.new(:Q3, 2, "Route 2", true), :other) }
    line = ["Quest Q3", t(:quest_giver, :who => t(:quest_unset)), t(:quest_where, :where => "Route 2"),
            t(:rj_quest_expires, :when => t(:rj_quest_never)), t(:quest_reward, :what => "Rare Candy")].join(". ")
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "a quest's expiry is the point its data names, or never where the data leaves it blank" do
    with_quests do
      { :Q1 => t(:rj_quest_never), :Q2 => "End of Chapter 5", :Q3 => t(:rj_quest_never) }.each do |id, want|
        assert_equal want, PokeAccess::RejuvQuests.expiration(id), "quest #{id}"
      end
    end
  end

  test "a quest's new badge is its notify flag" do
    with_quests do
      { Quest.new(:Q1, 1, "", true) => true, Quest.new(:Q1, 1, "", false) => false, Object.new => false }.each do |q, badge|
        assert_equal badge, PokeAccess::QuestUI.new_badge?(q), "for #{q.inspect}"
      end
    end
  end

  test "the achievements say the focused one as the screen opens, queued" do
    with_achievements { |scene, _win| scene.update }
    line = t(:rj_achievement, :name => "Catcher", :lvl => 1, :max => 3, :desc => "Catch Pokemon.", :prog => 12, :goal => 50)
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "the achievements' hidden window is left to their reader" do
    with_achievements do |scene, win|
      scene.update
      assert_equal true, PokeAccess.dedicated?(win)
    end
  end

  test "the same achievement is not said again while the cursor stays" do
    with_achievements do |scene, _win|
      scene.update
      SpeakCapture.clear
      scene.update
      assert_nothing_spoken
    end
  end

  test "a move in the achievements cuts in with the next one" do
    with_achievements do |scene, win|
      scene.update
      SpeakCapture.clear
      win.index = 1
      scene.update
    end
    line = t(:rj_achievement, :name => "Battler", :lvl => 2, :max => 2, :desc => "Win battles.", :prog => 7, :goal => 10)
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "an achievement the player's data cannot give yet is said once it can, queued" do
    with_achievements do |scene, _win|
      $Trainer = Holder.new(nil)
      scene.update
      assert_nothing_spoken "nothing to say yet"
      $Trainer = Holder.new(Achievements.new)
      scene.update
    end
    line = t(:rj_achievement, :name => "Catcher", :lvl => 1, :max => 3, :desc => "Catch Pokemon.", :prog => 12, :goal => 50)
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "the achievements say nothing while the scene has no command window" do
    with_achievements { PokemonAchievementsScene.new(nil).update }
    assert_nothing_spoken
  end

  test "an achievement's popup on the map says its lines, queued" do
    LocationWindow.new("Achievement Reached!\nTired Feet (Level 1)\nAP earned: 1")
    assert_equal [["Achievement Reached! Tired Feet (Level 1). AP earned: 1", false]], SpeakCapture.log
  end

  test "a place's sign on the map is left to the map's reader" do
    LocationWindow.new("Gearen City")
    assert_nothing_spoken
  end

  test "the blessing pick says the first as it comes up, queued, as one of the arrow's three stops" do
    with_blessings { BlessingsScene.new([:swift, :sturdy], [1, 3]).changeIndex(0) }
    line = t(:rj_blessing, :name => "Swift", :rank => 1, :desc => "swift power 1", :i => 1, :n => 3)
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "the blessing pick says nothing again on the same box" do
    with_blessings do
      scene = BlessingsScene.new([:swift, :sturdy], [1, 3])
      scene.changeIndex(0)
      SpeakCapture.clear
      scene.changeIndex(0)
    end
    assert_nothing_spoken
  end

  test "a move in the blessing pick cuts in with the next" do
    with_blessings do
      scene = BlessingsScene.new([:swift, :sturdy], [1, 3])
      scene.changeIndex(0)
      SpeakCapture.clear
      scene.changeIndex(1)
    end
    line = t(:rj_blessing, :name => "Sturdy", :rank => 3, :desc => "sturdy power 3", :i => 2, :n => 3)
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "with two blessings the pick's third stop is empty and says what confirming there does" do
    with_blessings do
      scene = BlessingsScene.new([:swift, :sturdy], [1, 3])
      scene.changeIndex(1)
      SpeakCapture.clear
      scene.changeIndex(1)
    end
    assert_equal [[t(:rj_blessing_empty, :i => 3, :n => 3), true]], SpeakCapture.log
  end

  test "a lone blessing is one of one" do
    with_blessings { BlessingsScene.new([:swift], [2]).changeIndex(0) }
    line = t(:rj_blessing, :name => "Swift", :rank => 2, :desc => "swift power 2", :i => 1, :n => 1)
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "a blessing the game cannot name is not said in the pick" do
    GameFunctions.with(BLESSINGS.merge(NAMELESS)) { BlessingsScene.new([:swift, :sturdy], [1, 3]).changeIndex(0) }
    assert_nothing_spoken
  end

  test "focused while the game cannot name its blessings, the overlay says how many there are alone" do
    GameFunctions.with(BLESSINGS.merge(NAMELESS)) { BlessingsOverlay.new.focus }
    assert_equal [[t(:rj_blessings_count, :n => 3), false]], SpeakCapture.log
  end

  test "the blessings overlay says nothing while it only shows" do
    with_blessings { BlessingsOverlay.new.updateInfoWindow }
    assert_nothing_spoken
  end

  test "focused, the blessings overlay says how many there are, then the one under its cursor, queued" do
    with_blessings { BlessingsOverlay.new.focus }
    assert_equal [["#{t(:rj_blessings_count, :n => 3)}. #{swift_in_full}", false]], SpeakCapture.log
  end

  test "a move in the blessings overlay says the next with its rules, cutting in, blank rules left out" do
    { 1 => "#{t(:rj_blessing, :name => 'Sturdy', :rank => 3, :desc => 'sturdy power 3 in full', :i => 2, :n => 3)}. Only in battle.",
      2 => "#{t(:rj_blessing, :name => 'Keen', :rank => 2, :desc => 'keen power 2 in full', :i => 3, :n => 3)}. Only at night." }.each do |i, line|
      with_blessings do
        ov = BlessingsOverlay.new
        ov.focus
        SpeakCapture.clear
        ov.index = i
        ov.updateInfoWindow
      end
      assert_equal [[line, true]], SpeakCapture.log, "cell #{i}"
    end
  end

  test "an empty cell of the overlay's last row is said as empty" do
    with_blessings do
      ov = BlessingsOverlay.new
      ov.focus
      SpeakCapture.clear
      ov.index = 5
      ov.updateInfoWindow
    end
    assert_equal [[t(:row_empty), true]], SpeakCapture.log
  end

  test "focused again, the blessings overlay says how many there are and its first again" do
    with_blessings do
      ov = BlessingsOverlay.new
      ov.focus
      ov.close
      SpeakCapture.clear
      ov.focus
    end
    assert_equal [["#{t(:rj_blessings_count, :n => 3)}. #{swift_in_full}", false]], SpeakCapture.log
  end

  test "the Luck Swap names the Pokemon under the arrow with its place, queued as the row comes up" do
    LuckSwapScene.new(["Eevee", "Riolu", "Axew"]).pbUpdate
    assert_equal [["Eevee, #{t(:list_pos, :i => 1, :n => 3)}", false]], SpeakCapture.log
  end

  test "the Luck Swap says nothing again while the arrow stays" do
    scene = LuckSwapScene.new(["Eevee", "Riolu", "Axew"])
    scene.pbUpdate
    SpeakCapture.clear
    scene.pbUpdate
    assert_nothing_spoken
  end

  test "a move in the Luck Swap cuts in with the next Pokemon" do
    scene = LuckSwapScene.new(["Eevee", "Riolu", "Axew"])
    scene.pbUpdate
    SpeakCapture.clear
    scene.index = 2
    scene.pbUpdate
    assert_equal [["Axew, #{t(:list_pos, :i => 3, :n => 3)}", true]], SpeakCapture.log
  end

  test "a ball of the Luck Swap that names no Pokemon says nothing, a blank name or one the screen cannot give" do
    { "a blank name" => 0, "a ball past the list" => 3 }.each do |what, index|
      scene = LuckSwapScene.new(["", "Riolu"])
      scene.index = index
      scene.pbUpdate
      assert_nothing_spoken what
    end
  end

  test "the Luck Swap's pick and swap open with the help they paint and the first Pokemon, once and queued" do
    { lambda { |s| s.startLuckponPick } => "Choose a MONSTER!",
      lambda { |s| s.startLuckponSwap([]) } => "Choose a MONSTER to swap!" }.each do |opening, help|
      SpeakCapture.clear
      opening.call(LuckSwapScene.new(["Eevee", "Riolu", "Axew"]))
      assert_equal [["#{help} Eevee, #{t(:list_pos, :i => 1, :n => 3)}", false]], SpeakCapture.log, help
    end
  end

  test "a Pokemon swapped out or the swap undone brings the other row with its help, cutting in" do
    scene = LuckSwapScene.new(["Eevee", "Riolu", "Axew"])
    scene.startLuckponSwap([])
    scene.index = 1
    scene.pbUpdate
    SpeakCapture.clear
    scene.pbSwapChosen(1)
    assert_equal [["Choose a MONSTER! Eevee, #{t(:list_pos, :i => 1, :n => 3)}", true]], SpeakCapture.log, "swapped out"
    SpeakCapture.clear
    scene.pbSwapCanceled
    assert_equal [["Choose a MONSTER to swap! Riolu, #{t(:list_pos, :i => 2, :n => 3)}", true]], SpeakCapture.log, "undone"
  end

  test "the Luck Swap row's first frame after a phase does not repeat it, and a move then cuts in" do
    scene = LuckSwapScene.new(["Eevee", "Riolu", "Axew"])
    scene.startLuckponPick
    SpeakCapture.clear
    scene.pbUpdate
    assert_nothing_spoken "the phase said it"
    scene.index = 1
    scene.pbUpdate
    assert_equal [["Riolu, #{t(:list_pos, :i => 2, :n => 3)}", true]], SpeakCapture.log
  end

  test "each password is said with its state, partly on for a bulk one listed inside, the other rows as painted" do
    rows = with_password_rows { PasswordEntry.new.entryForPasswords(false) }
    assert_equal ["Bulk Speed, #{t(:rj_pw_partly)}", "Manual Entry", "Speedy, #{t(:val_on)}", "Hard Mode, #{t(:val_off)}"], rows
  end

  test "outside the password lists a row keeps its marks, also once a list has closed" do
    with_password_rows do
      assert_equal "~ Bulk Speed", PokeAccess::Menus.checkbox_row("~ Bulk Speed"), "before any list"
      PasswordEntry.new.entryForPasswords(false)
      assert_equal "> Speedy", PokeAccess::Menus.checkbox_row("> Speedy"), "after the lists closed"
    end
  end

  test "the Move Tutor says a move's type and PP and that nobody can learn it, queued behind its name" do
    with_tutor([:CUT, :SURF], :CUT => [0, 0, 0]) { |scene| scene.pbUpdate }
    line = [t(:mv_type, :t => "Normal"), t(:mv_pp, :pp => 30, :tot => 30), t(:tut_nobody)].join(". ")
    assert_equal [["Cut", false], [line, false]], SpeakCapture.log
  end

  test "the Move Tutor says a move still to be paid for after its PP, then who can learn it and who knows it" do
    with_tutor([:CUT, [:SURF, :HEARTSCALE, 2]], :SURF => [1, 2, 0]) do |scene|
      list(scene).index = 1
      scene.pbUpdate
    end
    line = [t(:mv_type, :t => "Water"), t(:mv_pp, :pp => 15, :tot => 15), t(:rv_tutor_paid),
            t(:tut_can_list, :names => "Lapras"), t(:tut_knows_list, :names => "Vaporeon")].join(". ")
    assert_equal [["Surf", false], [line, false]], SpeakCapture.log
  end

  test "the Move Tutor says nothing again while the cursor stays on a move" do
    with_tutor([:CUT], :CUT => [0, 0, 0]) do |scene|
      scene.pbUpdate
      SpeakCapture.clear
      scene.pbUpdate
    end
    assert_nothing_spoken
  end

  test "the Move Tutor says nothing while its list does not have the cursor, as while the app fades in" do
    with_tutor([:CUT], :CUT => [0, 0, 0]) do |scene|
      list(scene).active = false
      scene.pbUpdate
    end
    assert_nothing_spoken
  end

  test "X sorts the Move Tutor's list by name and A by type, each said as it is rebuilt" do
    { Input::X => t(:rj_tutor_by_name), Input::A => t(:rj_tutor_by_type) }.each do |key, sort|
      SpeakCapture.clear
      with_tutor([:CUT], {}) { |scene| pressing(key) { scene.refreshMoveList } }
      assert_equal [[sort, true]], SpeakCapture.log, "key #{key}"
    end
  end

  test "a move bought rebuilds the Move Tutor's list with no sort to say" do
    with_tutor([:CUT], {}) { |scene| scene.refreshMoveList }
    assert_nothing_spoken
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # Runs the block with a bag holding quantities (item => count), the bag there before put back after.
  def with_bag(quantities)
    had = $PokemonBag
    bag = Object.new
    bag.define_singleton_method(:pbQuantity) { |item| quantities.fetch(item, 0) }
    $PokemonBag = bag
    yield
  ensure
    $PokemonBag = had
  end

  # Swift's line in the overlay, in full, the first of three.
  def swift_in_full
    t(:rj_blessing, :name => "Swift", :rank => 1, :desc => "swift power 1 in full", :i => 1, :n => 3)
  end

  # Runs the block with the profile's quest readers in place of the plugin's, the game's $quest_data and Q1 running,
  # all put back after.
  def with_quests
    ui = PokeAccess::QuestUI
    plugin = QUEST_READERS.map { |m| [m, ui.method(m)] }
    had = $quest_data
    self.class.quest_readers.each { |m, f| ui.define_singleton_method(m, f) }
    $quest_data = QuestData.new
    GameFunctions.with(:getActiveQuests => lambda { [:Q1] }) { yield }
  ensure
    $quest_data = had
    plugin.each { |m, f| ui.define_singleton_method(m, f) }
  end

  # Runs the block on the achievements scene and its hidden window, the player holding the achievements, put back after.
  def with_achievements
    had = $Trainer
    $Trainer = Holder.new(Achievements.new)
    win = ListWindow.new
    yield PokemonAchievementsScene.new(win), win
  ensure
    $Trainer = had
  end

  # Runs the block with the game's blessing helpers in place.
  def with_blessings(&blk)
    GameFunctions.with(BLESSINGS, &blk)
  end

  # The block's value with the profile's checkbox rows in place of core's, put back after.
  def with_password_rows
    menus = PokeAccess::Menus.singleton_class
    core = menus.instance_method(:checkbox_row)
    menus.send(:define_method, :checkbox_row, self.class.checkbox_row)
    yield
  ensure
    menus.send(:define_method, :checkbox_row, core)
  end

  # Runs the block on the Move Tutor app listing moves by their names, with the engine's data provider naming types
  # through the game's getTypeName, a party of Lapras, Vaporeon and Pidgey, and the bag giving the marks for each move
  # (1 can learn it, 2 knows it, 0 cannot); $cache, $Trainer and the bag's answer are put back after.
  def with_tutor(moves, marks)
    had_cache = $cache
    had_trainer = $Trainer
    $cache = Cache.new({}, MOVES, {})
    $Trainer = Trainer.new([Member.new("Lapras"), Member.new("Vaporeon"), Member.new("Pidgey")])
    names = moves.map { |m| (m.is_a?(Array) ? m[0] : m).to_s.capitalize }
    with_learn_marks(marks) do
      Harness.with_provider(PokeAccess::DataRV) do
        GameFunctions.with(TYPE_NAMES) { yield Scene_MoveTutor.new(moves, names) }
      end
    end
  ensure
    $cache = had_cache
    $Trainer = had_trainer
  end

  # Runs the block with PokemonBag.pbPartyCanLearnThisMove? answering marks, a move left out unable for all; the
  # answer there was before is put back, or none.
  def with_learn_marks(marks)
    meta = PokemonBag.singleton_class
    had = meta.method_defined?(:pbPartyCanLearnThisMove?) ? PokemonBag.method(:pbPartyCanLearnThisMove?) : nil
    PokemonBag.define_singleton_method(:pbPartyCanLearnThisMove?) { |move| marks.fetch(move, [0, 0, 0]) }
    yield
  ensure
    had ? PokemonBag.define_singleton_method(:pbPartyCanLearnThisMove?, had) : meta.send(:remove_method, :pbPartyCanLearnThisMove?)
  end

  # The Move Tutor's list of moves.
  def list(scene)
    scene.instance_variable_get(:@sprites)["commands"]
  end

  # Runs the block with Input answering true for the given keys only, put back after.
  def pressing(*keys)
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| keys.include?(k) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end
end
