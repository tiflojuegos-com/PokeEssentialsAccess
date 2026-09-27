# Rejuvenation's own screens (games/rejuvenation): the stat window of a level up or a vitamin, its edited copy of the
# Modern Quest System, the achievements and the Move Tutor app of the CyberNav, the passwords and the Xen tower's
# blessings and Luck Swap. Each profile file is loaded once; the quest reader's methods are put back after the suite
# that swaps them.
module RejuvScreensSpec
  Mon = Struct.new(:stats)
  Mon.send(:define_method, :getStats) { stats }
  Quest = Struct.new(:id, :stage, :location, :notify)
  Holder = Struct.new(:achievements)
  MoveData = Struct.new(:move, :type, :maxpp)
  Member = Struct.new(:name)
  Trainer = Struct.new(:party)
  TutorCache = Struct.new(:moves)

  class QuestData
    def getName(id); "Quest #{id}"; end
    def getQuestDescription(id, stage); "Overview of #{id} at stage #{stage}"; end
    def getStageDescription(_id, stage); "Task #{stage}"; end
    def getStageLocation(_id, _stage); "Gearen City"; end
    def getMaxStagesForQuest(_id); 4; end
    def getQuestGiver(_id); "nil"; end
    def getQuestReward(_id); "Rare Candy"; end
    def getQuestTermination(id); id == :Q1 ? "" : "End of Chapter 5"; end
  end

  class Achievements
    def getLevel(k); k == :CATCH ? 1 : 2; end
    def getProgress(k); k == :CATCH ? 12 : 7; end
    def getMilestone(k); k == :CATCH ? 50 : 10; end
  end

  class Window
    attr_accessor :index, :active
    def initialize; @index = 0; @active = true; end
  end

  def self.load_profile(name)
    @loaded ||= {}
    return if @loaded[name]
    load File.expand_path("../../../games/rejuvenation/#{name}.rb", File.dirname(__FILE__))
    @loaded[name] = true
  end

  def self.t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # Runs the block with Input answering true for the given keys only.
  def self.pressing(*keys)
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| keys.include?(k) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end
end

def pbStatChangeDisplayWindow(_pokemon, _oldstats, _opts = {}); :window; end

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

def getBlessingName(b); b.to_s.capitalize; end
def getBlessingDesc(b, rank); "#{b} power #{rank}"; end

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

# The overlay of blessings gained: its info window is rewritten for the cell under the cursor while it has the focus.
class BlessingsOverlay
  attr_accessor :index
  def initialize; @focused = false; @index = 0; end
  def focus; @focused = true; updateInfoWindow; end
  def updateInfoWindow; nil; end
  def close; @focused = false; end
end

class LuckSwapScene
  attr_writer :index
  def initialize(names)
    @names = names
    @length = names.length
    @index = 0
    @mode = :pick
    @party = false
  end

  def getMonDisplay; "<r><fs=45>#{@names[@index]}</fs></r>"; end
  def pbUpdate; nil; end

  # The pick opening: its title and help painted, then the fade that runs pbUpdate.
  def startLuckponPick
    drawFormattedTextEx(nil, 8, 46, 276, "<fs=45>LUCK SWAP</fs>")
    drawFormattedTextEx(nil, 8, 304, 400, "Choose a MONSTER!")
    pbUpdate
  end

  # A party Pokemon swapped out: the rentals' row comes up, updated before its help is painted.
  def pbSwapChosen(_pkmnindex)
    @mode = :swapPicked
    @index = 0
    pbUpdate
    drawFormattedTextEx(nil, 8, 304, 276, "Choose a MONSTER!")
  end
end

# The two LocationWindows a map shows: a place's sign, and the popup of an achievement's level reached.
class LocationWindow
  def initialize(name, _viewport = nil); @name = name; end
end

# The Move Tutor app of the CyberNav: its entries are moves, or [move, item, quantity] for one still to be paid for;
# X and A sort the list by rebuilding it.
class Scene_MoveTutor
  def initialize(moves)
    @moves = moves
    @sprites = { "commands" => RejuvScreensSpec::Window.new }
  end

  def pbUpdate; nil; end
  def refreshMoveList; @sprites["commands"] = RejuvScreensSpec::Window.new; end
end

class PokemonBag
  def self.pbPartyCanLearnThisMove?(move)
    move == :SURF ? [1, 2, 0] : [0, 0, 0]
  end
end

# The passwords menu: its rows as the command reader takes them, the bulk passwords' list opening inside the other.
class PasswordEntry
  def entryForPasswords(bulklist)
    rows = bulklist ? ["~ Bulk Speed"] : ["Manual Entry", "> Speedy", "    Hard Mode"]
    inner = bulklist ? [] : entryForPasswords(true)
    inner + rows.map { |r| PokeAccess::Menus.checkbox_row(r) }
  end
end

Suite.define("rejuvenation: the stat window's changes follow the message they come with") do
  RejuvScreensSpec.load_profile("level_up")
  s = RejuvScreensSpec
  SpeakCapture.clear
  eq "the window still comes up", pbStatChangeDisplayWindow(s::Mon.new([45, 30, 28, 33, 31, 40]),
                                                            [42, 28, 28, 31, 32, 38], :highlight => false), :window
  silent "nothing is said as it comes up: the message comes first"
  PokeAccess.say_dialogue("Axew grew to Level 12!")
  gains = [s.t(:rj_stat_up, :stat => s.t(:st_hp), :n => 3, :v => 45),
           s.t(:rj_stat_up, :stat => s.t(:st_atk), :n => 2, :v => 30),
           s.t(:rj_stat_up, :stat => s.t(:st_spatk), :n => 2, :v => 33),
           s.t(:rj_stat_down, :stat => s.t(:st_spdef), :n => 1, :v => 31),
           s.t(:rj_stat_up, :stat => s.t(:st_speed), :n => 2, :v => 40)]
  eq "then each stat that changed, a fall with its minus, and the value it paints now", SpeakCapture.lines,
     ["Axew grew to Level 12!", gains.join(", ")]
  match "the new value is in the line", gains[0], /45/

  SpeakCapture.clear
  pbStatChangeDisplayWindow(s::Mon.new([45, 30, 28, 33, 31, 40]), [45, 30, 28, 33, 31, 40])
  PokeAccess.say_dialogue("It won't have any effect.")
  eq "with nothing changed, the message goes alone", SpeakCapture.lines, ["It won't have any effect."]
end

Suite.define("rejuvenation: its quest journal reads as its edited copy paints it") do
  ui = PokeAccess::QuestUI
  plugin = [:overview, :new_badge?, :other_lines].map { |m| [m, ui.method(m)] }
  had = $quest_data
  begin
    RejuvScreensSpec.load_profile("quests")
    s = RejuvScreensSpec
    $quest_data = s::QuestData.new
    ui.detail(s::Quest.new(:Q1, 2, "Route 2", true), :description)
    eq "the overview follows the stage, each part after its painted label", SpeakCapture.lines,
       [["Quest Q1", s.t(:quest_overview, :text => "Overview of Q1 at stage 2"), s.t(:quest_task, :text => "Task 2"),
         s.t(:quest_location, :text => "Gearen City")].join(". ")]

    SpeakCapture.clear
    ui.detail(s::Quest.new(:Q1, 2, "Route 2", true), :other)
    eq "page two: progress, giver, place, expiry and the reward, shown while the quest runs", SpeakCapture.lines,
       [["Quest Q1", s.t(:quest_stage, :n => 2, :tot => 4), s.t(:quest_giver, :who => s.t(:quest_unset)),
         s.t(:quest_where, :where => "Route 2"), s.t(:rj_quest_expires, :when => s.t(:rj_quest_never)),
         s.t(:quest_reward, :what => "Rare Candy")].join(". ")]
    eq "an expiry the data names is said as named", PokeAccess::RejuvQuests.expiration(:Q2), "End of Chapter 5"

    truthy "the new badge is the quest's notify flag", ui.new_badge?(s::Quest.new(:Q1, 1, "", true))
    falsy "and off once seen", ui.new_badge?(s::Quest.new(:Q1, 1, "", false))
  ensure
    $quest_data = had
    plugin.each { |m, f| ui.define_singleton_method(m, f) }
  end
end

Suite.define("rejuvenation: achievements say the focused one as painted") do
  had = $Trainer
  begin
    RejuvScreensSpec.load_profile("achievements")
    s = RejuvScreensSpec
    $Trainer = s::Holder.new(s::Achievements.new)
    win = s::Window.new
    scene = PokemonAchievementsScene.new(win)
    SpeakCapture.clear
    scene.update
    first = s.t(:rj_achievement, :name => "Catcher", :lvl => 1, :max => 3, :desc => "Catch Pokemon.",
                                 :prog => 12, :goal => 50)
    eq "the first as the screen opens, queued", SpeakCapture.log, [[first, false]]
    truthy "its hidden window is left to this reader", PokeAccess.dedicated?(win)
    SpeakCapture.clear
    scene.update
    silent "nothing again while the cursor stays"
    win.index = 1
    scene.update
    second = s.t(:rj_achievement, :name => "Battler", :lvl => 2, :max => 2, :desc => "Win battles.",
                                  :prog => 7, :goal => 10)
    eq "a move cuts in with the next one", SpeakCapture.log, [[second, true]]
  ensure
    $Trainer = had
  end
end

Suite.define("rejuvenation: the blessing pick says the blessing under the arrow, and its empty third stop") do
  RejuvScreensSpec.load_profile("blessings")
  s = RejuvScreensSpec
  scene = BlessingsScene.new([:swift, :sturdy], [1, 3])
  SpeakCapture.clear
  scene.changeIndex(0)
  first = s.t(:rj_blessing, :name => "Swift", :rank => 1, :desc => "swift power 1", :i => 1, :n => 3)
  eq "the first as the pick comes up, queued, out of the arrow's three stops", SpeakCapture.log, [[first, false]]
  SpeakCapture.clear
  scene.changeIndex(0)
  silent "nothing again on the same box"
  scene.changeIndex(1)
  second = s.t(:rj_blessing, :name => "Sturdy", :rank => 3, :desc => "sturdy power 3", :i => 2, :n => 3)
  eq "a move cuts in with the next", SpeakCapture.log, [[second, true]]
  SpeakCapture.clear
  scene.changeIndex(1)
  eq "with two blessings the arrow stops at a third, empty place, which says what confirming there does",
     SpeakCapture.lines, [s.t(:rj_blessing_empty, :i => 3, :n => 3)]
  SpeakCapture.clear
  one = BlessingsScene.new([:swift], [2])
  one.changeIndex(0)
  eq "a lone blessing is one of one", SpeakCapture.lines,
     [s.t(:rj_blessing, :name => "Swift", :rank => 2, :desc => "swift power 2", :i => 1, :n => 1)]
end

Suite.define("rejuvenation: the blessings overlay says how many there are and the one under its cursor") do
  RejuvScreensSpec.load_profile("blessings")
  s = RejuvScreensSpec
  gained = { :swift => 1, :sturdy => 3 }
  fns = { :getPlayerBlessings => lambda { gained }, :getBlessingRank => lambda { |b| gained[b] || 0 },
          :getBlessingRules => lambda { |b| b == :sturdy ? ["Only in battle."] : [] },
          :getBlessingDesc => lambda { |b, rank, *ext| "#{b} power #{rank}#{ext[0] ? ' in full' : ''}" } }
  GameFunctions.with(fns) do
    ov = BlessingsOverlay.new
    SpeakCapture.clear
    ov.updateInfoWindow
    silent "nothing while the overlay only shows"
    ov.focus
    swift = s.t(:rj_blessing, :name => "Swift", :rank => 1, :desc => "swift power 1 in full", :i => 1, :n => 2)
    eq "on focus, how many and the first, queued", SpeakCapture.log,
       [[PokeAccess.sentences([s.t(:rj_blessings_count, :n => 2), swift]), false]]
    SpeakCapture.clear
    ov.index = 1
    ov.updateInfoWindow
    sturdy = s.t(:rj_blessing, :name => "Sturdy", :rank => 3, :desc => "sturdy power 3 in full", :i => 2, :n => 2)
    eq "a move says the next with its rules, cutting in", SpeakCapture.log, [["#{sturdy}. Only in battle.", true]]
    SpeakCapture.clear
    ov.index = 5
    ov.updateInfoWindow
    eq "an empty cell of the last row is empty", SpeakCapture.lines, [s.t(:row_empty)]
  end
end

Suite.define("rejuvenation: the Luck Swap names the Pokemon under the arrow") do
  RejuvScreensSpec.load_profile("luck_swap")
  s = RejuvScreensSpec
  scene = LuckSwapScene.new(["Eevee", "Riolu", "Axew"])
  SpeakCapture.clear
  scene.pbUpdate
  eq "the first as the row comes up, without its size tags, queued", SpeakCapture.log,
     [["Eevee, #{s.t(:list_pos, :i => 1, :n => 3)}", false]]
  SpeakCapture.clear
  scene.pbUpdate
  silent "nothing again while the arrow stays"
  scene.index = 2
  scene.pbUpdate
  eq "a move cuts in with the next", SpeakCapture.log, [["Axew, #{s.t(:list_pos, :i => 3, :n => 3)}", true]]
end

Suite.define("rejuvenation: the Luck Swap says the help that tells which row is up") do
  RejuvScreensSpec.load_profile("luck_swap")
  s = RejuvScreensSpec
  scene = LuckSwapScene.new(["Eevee", "Riolu", "Axew"])
  SpeakCapture.clear
  scene.startLuckponPick
  eq "the pick opens with its help and the first Pokemon, once and queued", SpeakCapture.log,
     [["Choose a MONSTER! Eevee, #{s.t(:list_pos, :i => 1, :n => 3)}", false]]
  SpeakCapture.clear
  scene.index = 1
  scene.pbUpdate
  SpeakCapture.clear
  scene.pbSwapChosen(1)
  eq "a party Pokemon swapped out brings the rentals' row with its help, cutting in", SpeakCapture.log,
     [["Choose a MONSTER! Eevee, #{s.t(:list_pos, :i => 1, :n => 3)}", true]]
  SpeakCapture.clear
  scene.pbUpdate
  silent "and the row's first frame does not repeat it"
end

Suite.define("rejuvenation: an achievement's popup on the map is said, a place's sign is left alone") do
  RejuvScreensSpec.load_profile("achievements")
  SpeakCapture.clear
  LocationWindow.new("Achievement Reached!\nTired Feet (Level 1)\nAP earned: 1")
  eq "its lines, queued", SpeakCapture.log, [["Achievement Reached! Tired Feet (Level 1). AP earned: 1", false]]
  SpeakCapture.clear
  LocationWindow.new("Gearen City")
  silent "a place's sign is the map's own business"
end

Suite.define("rejuvenation: each password is said with its state, partly on included") do
  RejuvScreensSpec.load_profile("passwords")
  s = RejuvScreensSpec
  eq "on, partly on (a bulk one, listed inside) and off; the other rows as painted", PasswordEntry.new.entryForPasswords(false),
     ["Bulk Speed, #{s.t(:rj_pw_partly)}", "Manual Entry", "Speedy, #{s.t(:val_on)}", "Hard Mode, #{s.t(:val_off)}"]
  eq "outside the lists a row keeps its marks", PokeAccess::Menus.checkbox_row("~ Bulk Speed"), "~ Bulk Speed"
end

Suite.define("rejuvenation: the Move Tutor app says a move still to be paid for, and the sort X or A made") do
  RejuvScreensSpec.load_profile("move_tutor")
  s = RejuvScreensSpec
  had_cache = $cache
  had_trainer = $Trainer
  begin
    $cache = s::TutorCache.new({ :SURF => s::MoveData.new(:SURF, :WATER, 15), :CUT => s::MoveData.new(:CUT, :NORMAL, 30) })
    $Trainer = s::Trainer.new([s::Member.new("Lapras"), s::Member.new("Vaporeon"), s::Member.new("Pidgey")])
    type = lambda { |ty| n = PokeAccess::Data.type_name(ty); n ? s.t(:mv_type, :t => n) : nil }
    scene = Scene_MoveTutor.new([:CUT, [:SURF, :HEARTSCALE, 2]])
    SpeakCapture.clear
    scene.pbUpdate
    cut = [type.call(:NORMAL), s.t(:mv_pp, :pp => 30, :tot => 30), s.t(:tut_nobody)].compact
    eq "a move bought: its type, its PP and who can learn it, queued behind its name", SpeakCapture.log,
       [[PokeAccess.sentences(cut), false]]
    SpeakCapture.clear
    scene.instance_variable_get(:@sprites)["commands"].index = 1
    scene.pbUpdate
    surf = [type.call(:WATER), s.t(:mv_pp, :pp => 15, :tot => 15), s.t(:rv_tutor_paid),
            s.t(:tut_can_list, :names => "Lapras"), s.t(:tut_knows_list, :names => "Vaporeon")].compact
    eq "a move still to be paid for, its name painted grey, says so after its PP", SpeakCapture.lines,
       [PokeAccess.sentences(surf)]
    SpeakCapture.clear
    s.pressing(Input::X) { scene.refreshMoveList }
    eq "X sorts the list by name and says so", SpeakCapture.lines, [s.t(:rj_tutor_by_name)]
    SpeakCapture.clear
    s.pressing(Input::A) { scene.refreshMoveList }
    eq "A by type", SpeakCapture.lines, [s.t(:rj_tutor_by_type)]
    SpeakCapture.clear
    scene.refreshMoveList
    silent "a move bought rebuilds the list with no sort to say"
  ensure
    $cache = had_cache
    $Trainer = had_trainer
  end
end
