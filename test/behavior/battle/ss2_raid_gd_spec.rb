# DBK Raid Battles: the cheer menu and the boss's barrier. The stand-ins keep the kit's shapes (description(level) by
# the current cheer level, a mode= that does not repaint, the pollers run where pbUpdate would); Battle::Scene is
# shared with other specs, so no initialize on it here.
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

# The raid den's entry and rewards screens: the chosen option shows only in the cursor sprite, which the stand-in
# moves as the kit does (y = 132 + 34 * index).
class RaidCursorSprite
  attr_accessor :y, :visible
  def initialize; @y = 132; @visible = true; end
end

class RaidTextWindow
  attr_accessor :text, :visible
  def initialize; @text = ""; @visible = false; end
end

# A party icon of the entry screen (PokemonIconSprite), which Change Party repoints at the new party.
class RaidPartyIcon
  attr_accessor :pokemon
  def initialize(pk); @pokemon = pk; end
end

class RaidScene
  attr_accessor :script, :reward_script, :party, :new_party, :field

  def initialize(pkmn, rules, save_ok = true)
    @pkmn = pkmn
    @rules = rules
    @save_ok = save_ok
    @sprites = { "cursor" => RaidCursorSprite.new, "itemtext" => RaidTextWindow.new }
    @script = [:use]
    @reward_script = []
    @party = []
    @new_party = []
    @field = [:None, :None, nil]
  end

  def sprite(key); @sprites[key]; end

  def pbEndScene; end

  def pbSavingPrompt(_pkmn, _rules); @save_ok; end

  # As the kit's: the field conditions and the party icons are set up before the texts are drawn.
  def pbStartScene(pkmn, rules)
    return false if !pbSavingPrompt(pkmn, rules)
    @weather, @terrain, @environ = @field
    @party.each_with_index { |pk, i| @sprites["partyicon_#{i}"] = RaidPartyIcon.new(pk) }
    pbDrawTextPositions(nil, [["BASIC DEN", 97, 24], ["Begin Raid", 391, 140],
                              ["Leave Raid", 391, 174], ["Change Party", 391, 208]])
    drawTextEx(nil, 40, 250, 226, 2, "Battle ends after 10 turns.")
    pbRaidEntry
  end

  # :change stands for Change Party returning: the icons are repointed at the party chosen.
  def pbRaidEntry
    index = 0
    @script.each do |step|
      PokeAccess::Keys.run_frame_pollers
      break if step == :use
      if step == :change
        @new_party.each_with_index { |pk, i| @sprites["partyicon_#{i}"].pokemon = pk }
        next
      end
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

  scene2 = Battle::Scene.new
  scene2.raid_setup(SS2RaidBattleStub.new(2, 5), [:use])
  SpeakCapture.clear
  scene2.pbChooseCheer(0)
  lines2 = SpeakCapture.lines.join(" | ")
  match "at level two the level is announced", lines2,
        /#{Regexp.escape(PokeAccess::I18n.t(:ss2_cheer_lvl, :n => 2, :max => 3))}/
  match "and the button carries the description for level two", lines2,
        /Increases potency of the team's moves/

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
  match "the sex sign is passed on as the page paints it",
        lines, /#{Regexp.escape(PokeAccess::Party.gender_glyph(boss))}/
  falsy "and not turned into a word", lines.include?(PokeAccess::I18n.t(:pk_male))
  match "the description is read once the player asks for the box", lines, /restores 20 HP/
  match "and again for the next item while the box is up", lines, /restores 60 HP/
end

# The entry screen shows the boss as a black silhouette: its species is named only on the rewards page.
Suite.define("soulstones 2 raid den: the boss inside is a silhouette, said with the types and rank it shows") do
  t = PokeAccess::I18n
  boss = Poke.build(:name => "Mewtwo", :species => :MEWTWO)
  def boss.types; [:PSYCHIC]; end
  scene = RaidScene.new(boss, { :rank => 5 })

  SpeakCapture.clear
  scene.pbStartScene(boss, {})
  first = SpeakCapture.lines.first.to_s
  falsy "the species the silhouette hides is not said", first.include?(PokeAccess::Data.species_name(:MEWTWO).to_s)
  falsy "nor its name", first.include?("Mewtwo")
  match "a hidden Pokemon is, with the types its icons show and its rank", first,
        /#{Regexp.escape([t.t(:ss2_raid_hidden), t.t(:pc_types, :t => PokeAccess::Data.type_name(:PSYCHIC)),
                          t.t(:ss2_raid_rank, :n => 5)].join(", "))}/
  falsy "no field line where the screen draws no field icons", first.include?(t.t(:ss2_raid_field, :list => "").strip)
end

# Who enters shows only as icons, the ones the confirmation calls "the displayed party"; Change Party repoints them.
Suite.define("soulstones 2 raid den: the party the icons show is said, and again after Change Party") do
  t = PokeAccess::I18n
  boss = Poke.build(:name => "Boss")
  scene = RaidScene.new(boss, { :rank => 3, :loot => [:RARECANDY], :online => true })
  scene.party = [Poke.build(:name => "Chispa"), Poke.build(:name => "Rocoso")]
  scene.new_party = [Poke.build(:name => "Brasa"), scene.party[1]]
  scene.field = [:Rain, :Electric, :Cave]
  scene.script = [2, :change, 2, :use]

  SpeakCapture.clear
  scene.pbStartScene(boss, {})
  first = SpeakCapture.lines.first.to_s
  match "the party icons are named on opening", first, /#{Regexp.escape(t.t(:ss2_raid_party, :list => "Chispa, Rocoso"))}/
  match "with the bonus loot icon", first, /#{Regexp.escape(t.t(:ss2_raid_bonus))}/
  match "and the online one", first, /#{Regexp.escape(t.t(:ss2_raid_online))}/
  field = [PokeAccess::Battle.weather_name(:Rain), t.t(:bt_electric), "Cave"].join(", ")
  match "the field icons, weather, terrain and environment", first,
        /#{Regexp.escape(t.t(:ss2_raid_field, :list => field))}/
  after = t.t(:ss2_raid_party, :list => "Brasa, Rocoso")
  eq "the new party is said once, when Change Party has repointed the icons",
     SpeakCapture.lines.count { |l| l.include?(after) }, 1
  eq "and the party loop lets the screen go", PokeAccess::SS2RaidDen.instance_variable_get(:@entry), nil
end

# The rewards page draws the rank stars and, over a shiny boss, the shiny icon.
Suite.define("soulstones 2 raid den: the rewards page says the shiny icon and the rank stars") do
  t = PokeAccess::I18n
  shiny = Poke.build(:name => "Tester", :shiny => true)
  scene = RaidScene.new(shiny, { :rank => 6 })
  SpeakCapture.clear
  scene.pbRaidRewardsScreen(1)
  lines = SpeakCapture.lines.join(" | ")
  match "a shiny boss is said to be one", lines, /#{Regexp.escape(t.t(:pk_shiny))}/
  match "and the stars are its rank", lines, /#{Regexp.escape(t.t(:ss2_raid_rank, :n => 6))}/

  plain = RaidScene.new(Poke.build(:name => "Tester"), { :rank => 2 })
  SpeakCapture.clear
  plain.pbRaidRewardsScreen(1)
  falsy "a boss that is not shiny draws no shiny icon", SpeakCapture.lines.join(" | ").include?(t.t(:pk_shiny))
end

Suite.define("soulstones 2 raid: a cheer's description waits for full, and the info key keeps it") do
  cheer = GameData::Cheer.get_cheer_for_index(1)
  whole = "Hang tough!, The team takes less damage from moves."
  rows = vb_levels { PokeAccess::SS2Cheer.line(cheer, 1) }
  eq "brief and medium: the shout", rows[0, 2], ["Hang tough!", "Hang tough!"]
  eq "full: and what it does at this level", rows[2], whole
  PokeAccess::Config.verbosity = :brief
  PokeAccess::SS2Cheer.line(cheer, 1)
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps both", PokeAccess::Info.info_text, whole
end
