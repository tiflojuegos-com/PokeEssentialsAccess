# DBK Raid Battles: the cheer menu and the boss's barrier, the two things a raid draws and never writes.
#
# The classes below reproduce the kit's own shapes, not the reader's wishes. GameData::Cheer really does
# keep the shout and the description apart -- cheer_text is the word on the button, description(level) is a
# four-entry array indexed by the CURRENT cheer level, and entry 0 of every one of them says the cheer needs
# a higher level. CheerMenu really does fill @cheers inside refresh, and really does shadow MenuBase's mode=
# with an attr_accessor, so setting the mode does NOT repaint. pbChooseCheer is the kit's own loop with its
# input reads replaced by a scripted list of cursor positions: what the real one calls each iteration is
# pbUpdate, which reaches Input.update and from there every frame poller, so the stand-in calls the pollers
# in that same place.
#
# Battle::Scene is shared with the other battle specs, which build it with Battle::Scene.new, so nothing
# here may define an initialize on it.
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
  # The kit's pbInitSprites builds the window once, when the battle scene is built.
  def raid_setup(battle, script)
    @battle = battle
    @sprites = { "cheerWindow" => Battle::Scene::CheerMenu.new }
    @script = script
  end

  def pbChooseCheer(mode = 0)
    cw = @sprites["cheerWindow"]
    cw.index = 0
    cw.mode = mode
    cw.cheerLvl = @battle.cheerLevel[0][0]
    cw.refresh
    ret = -1
    @script.each do |step|
      PokeAccess::Keys.run_frame_pollers
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

class SS2RaidBattleStub
  attr_reader :cheerLevel, :raidRules

  def initialize(level, shield_max)
    @cheerLevel = [[level], [0]]
    @raidRules = { :shield_hp => shield_max }
  end
end

class SS2RaidBattlerStub
  attr_reader :shieldHP

  def initialize(hp, opposes)
    @shieldHP = hp
    @opposes = opposes
  end

  def opposes?; @opposes; end
end

# The raid den: the screen the portal opens and the page that closes it. Its three options live in a local
# variable of pbRaidEntry's loop and the only trace of the choice is where the loop put the cursor sprite,
# so the stand-in moves that sprite exactly as the kit does (y = 132 + 34 * index). The painting is the
# kit's own two calls, in its own order, with the option labels between the den's name and the rules line.
class RaidCursorSprite
  attr_accessor :y, :visible
  def initialize; @y = 132; @visible = true; end
end

class RaidTextWindow
  attr_accessor :text, :visible
  def initialize; @text = ""; @visible = false; end
end

class RaidScene
  attr_accessor :script, :reward_script

  def initialize(pkmn, rules, save_ok = true)
    @pkmn = pkmn
    @rules = rules
    @save_ok = save_ok
    @sprites = { "cursor" => RaidCursorSprite.new, "itemtext" => RaidTextWindow.new }
    @script = [:use]
    @reward_script = []
  end

  def sprite(key); @sprites[key]; end

  def pbEndScene; end

  def pbSavingPrompt(_pkmn, _rules); @save_ok; end

  def pbStartScene(pkmn, rules)
    return false if !pbSavingPrompt(pkmn, rules)
    pbDrawTextPositions(nil, [["BASIC DEN", 97, 24], ["Begin Raid", 391, 140],
                              ["Leave Raid", 391, 174], ["Change Party", 391, 208]])
    drawTextEx(nil, 40, 250, 226, 2, "Battle ends after 10 turns.")
    pbRaidEntry
  end

  def pbRaidEntry
    index = 0
    @script.each do |step|
      PokeAccess::Keys.run_frame_pollers
      break if step == :use
      index = step
      @sprites["cursor"].y = 132 + 34 * index
    end
    0
  end

  def pbRaidRewardsScreen(_outcome)
    @sprites["itemtext"].text = "A potion that restores 20 HP."
    pbDrawTextPositions(nil, [["View", 316, 290], ["\xe2\x99\x82", 96, 78], ["You caught Tester!", 377, 24],
                              ["Lv. 70", 32, 78], ["Abil: Pressure", 32, 290], ["Next", 438, 290]])
    @reward_script.each do |step|
      PokeAccess::Keys.run_frame_pollers
      case step
      when :toggle then @sprites["itemtext"].visible = !@sprites["itemtext"].visible
      when :next   then @sprites["itemtext"].text = "A super potion that restores 60 HP."
      end
    end
    PokeAccess::Keys.run_frame_pollers
  end
end

require File.expand_path("../../../games/soulstones2/raid_cheer", File.dirname(__FILE__))
require File.expand_path("../../../games/soulstones2/raid_den", File.dirname(__FILE__))

Suite.define("soulstones 2 raid: the cheer menu says the level once and each button with what it does now") do
  scene = Battle::Scene.new
  scene.raid_setup(SS2RaidBattleStub.new(0, 5), [1, 2, :use])

  SpeakCapture.clear
  eq "the loop returns the button the player confirmed", scene.pbChooseCheer(0), 2
  lines = SpeakCapture.lines.join(" | ")
  match "the cheer level opens the menu", lines,
        /#{Regexp.escape(PokeAccess::I18n.t(:ss2_cheer_lvl, :n => 0, :max => 3))}/
  match "the focused button says its shout", lines, /Go all-out!/
  match "and what it does at THIS level, which at zero is nothing yet", lines,
        /Requires Cheer Lv\.1 or higher/
  match "moving reads the next button", lines, /Hang tough!/
  match "and the one after it", lines, /Heal up!/
  truthy "the level comes first, since it is what the buttons mean",
         lines.index(PokeAccess::I18n.t(:ss2_cheer_lvl, :n => 0, :max => 3)) < lines.index("Go all-out!")

  # The level is the whole screen: the same button is a different thing two rounds later. A reader that took
  # description(0) for granted would sound identical here, which is why this is a second open.
  scene2 = Battle::Scene.new
  scene2.raid_setup(SS2RaidBattleStub.new(2, 5), [:use])
  SpeakCapture.clear
  scene2.pbChooseCheer(0)
  lines2 = SpeakCapture.lines.join(" | ")
  match "at level two the level is announced", lines2,
        /#{Regexp.escape(PokeAccess::I18n.t(:ss2_cheer_lvl, :n => 2, :max => 3))}/
  match "and the button carries the description for level two", lines2,
        /Increases potency of the team's moves/

  # The poll runs forty times a second and the cursor stands still between presses.
  scene3 = Battle::Scene.new
  scene3.raid_setup(SS2RaidBattleStub.new(1, 5), [1, 1, :use])
  SpeakCapture.clear
  scene3.pbChooseCheer(0)
  eq "a button under the cursor for many frames is read once",
     SpeakCapture.lines.join(" | ").scan(/Hang tough!/).length, 1

  SpeakCapture.clear
  PokeAccess::Keys.run_frame_pollers
  silent "and with the menu closed the poll says nothing at all"
end

Suite.define("soulstones 2 raid: the barrier is counted while it stands and left to the game when it breaks") do
  scene = Battle::Scene.new
  scene.raid_setup(SS2RaidBattleStub.new(0, 5), [])

  SpeakCapture.clear
  scene.pbAnimateRaidShield(SS2RaidBattlerStub.new(3, true), 4)
  spoke "the bars left are said", /#{Regexp.escape(PokeAccess::I18n.t(:ss2_raid_shield, :n => 3, :max => 5))}/

  SpeakCapture.clear
  scene.pbAnimateRaidShield(SS2RaidBattlerStub.new(0, true), 1)
  silent "a broken barrier is left to the game's own message"

  SpeakCapture.clear
  scene.pbAnimateRaidShield(SS2RaidBattlerStub.new(3, false), 4)
  silent "and the player's own side has no raid barrier to count"
end

Suite.define("soulstones 2 raid den: the entry screen reads what it painted and its cursor names the option") do
  boss = Poke.build(:name => "Tester", :gender => 0)
  scene = RaidScene.new(boss, { :rank => 4, :size => 3 })
  scene.script = [1, 2, :use]

  SpeakCapture.clear
  scene.pbStartScene(boss, { :rank => 4 })
  lines = SpeakCapture.lines.join(" | ")
  match "the den names itself", lines, /BASIC DEN/
  match "the rank of the boss inside is said", lines,
        /#{Regexp.escape(PokeAccess::I18n.t(:ss2_raid_rank, :n => 4))}/
  match "and the rules of the raid, which the screen writes out", lines, /Battle ends after 10 turns/
  match "the first option is read where the cursor starts", lines, /Begin Raid/
  match "and each one the cursor moves to", lines, /Leave Raid/
  match "including the one whose wording depends on the raid size", lines, /Change Party/

  # A prompt answered no never paints the screen, so nothing may be left armed to swallow the next one.
  scene2 = RaidScene.new(boss, { :rank => 1 }, false)
  SpeakCapture.clear
  eq "a refused saving prompt opens nothing", scene2.pbStartScene(boss, { :rank => 1 }), false
  silent "and says nothing"
end

Suite.define("soulstones 2 raid den: the rewards page says the outcome, and the description only when shown") do
  boss = Poke.build(:name => "Tester", :gender => 0)
  scene = RaidScene.new(boss, { :rank => 4 })
  scene.reward_script = [:toggle, nil, :next, :toggle]

  SpeakCapture.clear
  scene.pbRaidRewardsScreen(4)
  lines = SpeakCapture.lines.join(" | ")
  match "the outcome leads", lines, /You caught Tester!/
  match "with the level catching it revealed", lines, /Lv\. 70/
  match "and the ability", lines, /Abil: Pressure/
  match "the sex glyph is replaced by the word for it",
        lines, /#{Regexp.escape(PokeAccess::Party.gender_word(boss))}/
  truthy "and the glyph itself never reaches the voice", !lines.include?("â")
  match "the description is read once the player asks for the box", lines, /restores 20 HP/
  match "and again for the next item while the box is up", lines, /restores 60 HP/
end
