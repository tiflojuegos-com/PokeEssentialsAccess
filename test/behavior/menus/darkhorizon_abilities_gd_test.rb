# Dark Horizon's Trainer Abilities (games/darkhorizon/trainer_abilities.rb): the opening led by the painted title and
# level, the bar's progress and an ability ready to unlock; the focused slot by the lines it paints with its place,
# Cancel below; the reel of abilities on offer the same way, led by its own title.

# The screen as the game runs it: pbStartScene paints the title and level, then runs pbLevelUpUpdate; every frame
# pbTrainerAbilityChoiceUpdate paints the focused slot's lines (@sel past ten is Cancel, which paints nothing);
# pbLevelUpSelection paints the reel's title and runs its loop (the block), whose frames paint the reel's ability.
class TrainerAbility
  def initialize(slots, opts = {})
    @slots = slots
    @sel = 1
    @shadowLevel = opts.fetch(:level, 1)
    @shadowExp = opts.fetch(:exp, 40)
    @levelUp = opts.fetch(:level_up, false)
    @data = opts.fetch(:offer, [])
    @selLevelUp = 1
  end

  def pbStartScene
    pbDrawTextPositions(nil, [["Trainer Abilities", 256, 25], ["Lv: #{@shadowLevel}", 139, 78]])
    pbLevelUpUpdate
    :started
  end

  def pbLevelUpUpdate; :overlay; end

  # An unlock as pbChooseSkill runs it: the level repainted one up, the bar emptied, then pbLevelUpUpdate.
  def unlock
    pbLevelUpLvlUpdate
    @shadowExp = 0
    @levelUp = false
    pbLevelUpUpdate
  end

  def pbLevelUpLvlUpdate
    @shadowLevel += 1
    pbDrawTextPositions(nil, [["Trainer Abilities", 256, 25], ["Lv: #{@shadowLevel}", 139, 78]])
  end

  def pbTrainerAbilityChoiceUpdate
    return :cancel if @sel > 10
    paint(@slots[@sel - 1])
    :slot
  end

  def pbLevelUpSelection
    pbDrawTextPositions(nil, [["Choose an Ability", 256, 25]])
    yield self if block_given?
    :chosen
  end

  def pbTrainerAbilityChoiceUpdateLevelUp
    paint(@data[@selLevelUp - 1])
    :reel
  end

  def pbEndScene; :closed; end

  def paint(lines)
    pbDrawTextPositions(nil, lines.each_with_index.map { |l, i| [l, 40, 268 + 30 * i] })
  end
end

# The profile's shared helpers (constants.rb's module), loaded once and without the profile's settings.
unless defined?(PokeAccess::DarkHorizon)
  constants = File.join(Harness::ROOT, "games", "darkhorizon", "constants.rb")
  src = Harness.source(constants)
  part = src[/^module PokeAccess\r?\n.*?^end\r?\n/m]
  eval(part, TOPLEVEL_BINDING, constants, src[0, src.index(part)].count("\n") + 1)
end

trainer_abilities = File.join(Harness::ROOT, "games", "darkhorizon", "trainer_abilities.rb")
eval(Harness.source(trainer_abilities), TOPLEVEL_BINDING, trainer_abilities)

class DarkhorizonAbilitiesGdTest < PokeAccessTest
  # Two slots: an ability the game draws on two lines, and a locked one.
  SLOTS = [["Pure Heart", "Shadow Pokémon empty their Heart Gauge", "faster than normal."],
           ["???", "Ability locked", ""]].freeze
  # The reel's offer.
  OFFER = [["Snag Expert", "Shadow Pokémon are easier to snag.", ""],
           ["Shooting Star", "Shadow Pokémon have an increased", "Shiny rate."]].freeze

  test "opens with the painted title and level and the bar's progress, then the first slot with the keys, queued" do
    screen = TrainerAbility.new(SLOTS)
    screen.pbStartScene
    screen.pbTrainerAbilityChoiceUpdate
    slot = "Pure Heart, #{list_place(1, 5)}. Shadow Pokémon empty their Heart Gauge faster than normal."
    assert_equal [["Trainer Abilities. Lv: 1. #{t(:dh_ta_progress, :n => 40)}", false],
                  ["#{slot} #{t(:dh_ta_keys)}", false]], SpeakCapture.log
  end

  test "an unlock says the level it repaints and the emptied bar, queued, without the title" do
    screen = TrainerAbility.new(SLOTS, :exp => 100, :level_up => true)
    screen.pbStartScene
    SpeakCapture.clear
    screen.unlock
    assert_equal [["Lv: 2. #{t(:dh_ta_progress, :n => 0)}", false]], SpeakCapture.log
  end

  test "a level ready to unlock is said in the opening" do
    TrainerAbility.new(SLOTS, :exp => 100, :level_up => true).pbStartScene
    assert_spoken(/#{Regexp.escape(t(:dh_ta_unlock_ready))}\z/)
  end

  test "the next slot cuts in, a locked one named by its line, and the same slot again says nothing" do
    screen = TrainerAbility.new(SLOTS)
    screen.pbTrainerAbilityChoiceUpdate
    SpeakCapture.clear
    screen.instance_variable_set(:@sel, 2)
    2.times { screen.pbTrainerAbilityChoiceUpdate }
    assert_equal [["Ability locked, #{list_place(2, 5)}", true]], SpeakCapture.log
  end

  test "below the row is Cancel" do
    screen = TrainerAbility.new(SLOTS)
    screen.pbTrainerAbilityChoiceUpdate
    SpeakCapture.clear
    screen.instance_variable_set(:@sel, 11)
    screen.pbTrainerAbilityChoiceUpdate
    assert_equal [[t(:pc_cancel), true]], SpeakCapture.log
  end

  test "the reel is led by its own title and its keys, then each ability on offer cuts in" do
    screen = TrainerAbility.new(SLOTS, :offer => OFFER)
    screen.pbLevelUpSelection do |s|
      s.pbTrainerAbilityChoiceUpdateLevelUp
      s.instance_variable_set(:@selLevelUp, 2)
      s.pbTrainerAbilityChoiceUpdateLevelUp
    end
    keys = t(:dh_ta_reel_keys, :key => "C")
    assert_equal [["Choose an Ability. Snag Expert, #{list_place(1, 2)}. Shadow Pokémon are easier to snag. #{keys}", false],
                  ["Shooting Star, #{list_place(2, 2)}. Shadow Pokémon have an increased Shiny rate.", true]],
                 SpeakCapture.log
  end

  test "once the reel closes the slot under the cursor is said again, queued" do
    screen = TrainerAbility.new(SLOTS, :offer => OFFER)
    screen.pbTrainerAbilityChoiceUpdate
    screen.pbLevelUpSelection { |s| s.pbTrainerAbilityChoiceUpdateLevelUp }
    SpeakCapture.clear
    screen.pbTrainerAbilityChoiceUpdate
    assert_equal [["Pure Heart, #{list_place(1, 5)}. Shadow Pokémon empty their Heart Gauge faster than normal.", false]],
                 SpeakCapture.log
  end

  test "a second reel in the same screen starts afresh" do
    screen = TrainerAbility.new(SLOTS, :offer => OFFER)
    screen.pbLevelUpSelection { |s| s.pbTrainerAbilityChoiceUpdateLevelUp }
    SpeakCapture.clear
    screen.pbLevelUpSelection { |s| s.pbTrainerAbilityChoiceUpdateLevelUp }
    assert_spoken_once(/\AChoose an Ability\. Snag Expert/)
  end

  test "keeps the screen's own returns, and closing it drops the slot from the info key" do
    screen = TrainerAbility.new(SLOTS, :offer => OFFER)
    got = [screen.pbStartScene, screen.pbTrainerAbilityChoiceUpdate, screen.pbLevelUpSelection,
           screen.pbTrainerAbilityChoiceUpdateLevelUp]
    assert_equal [:started, :slot, :chosen, :reel], got
    screen.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
