# The Battle Arena's judgment on the gen-6 engine (core/battle/arena_judgment.rb), where the box is
# PokeBattle_Scene#updateJudgment: the stand-in below holds that name only while the file's hook section is evaluated
# again, so the hook binds to it and no other test sees a battle scene. Also the marks of a box painted in another
# shape.

# The gen-6 box as far as its text goes: the names and VS on the top row, Mind, Skill and Body down the middle column,
# then the totals beside the judgment row.
class ArenaJudgmentG6Scene
  def updateJudgment(_window, phase, battler1, battler2, ratings1, ratings2)
    total1 = (0...phase).inject(0) { |sum, i| sum + ratings1[i] }
    total2 = (0...phase).inject(0) { |sum, i| sum + ratings2[i] }
    pbDrawTextPositions(nil, [[battler1.name, 64, 0], ["VS", 144, 0], [battler2.name, 224, 0], ["Mind", 144, 48],
                              ["Skill", 144, 80], ["Body", 144, 112], [total1.to_s, 64, 160], ["Judgment", 144, 160],
                              [total2.to_s, 224, 160]])
    :painted
  end
end

arena_made = !Object.const_defined?(:PokeBattle_Scene)
Object.const_set(:PokeBattle_Scene, ArenaJudgmentG6Scene) if arena_made
begin
  arena = File.join(Harness::ROOT, "core", "battle", "arena_judgment.rb")
  source = Harness.source(arena)
  module_end = source.index("\n", source.index(/^end\s*$/)) + 1
  eval(source[module_end..-1], TOPLEVEL_BINDING, arena, source[0, module_end].count("\n") + 1)
ensure
  Object.send(:remove_const, :PokeBattle_Scene) if arena_made
end

class ArenaJudgmentTest < PokeAccessTest
  I18n = PokeAccess::I18n
  Judgment = PokeAccess::ArenaJudgment
  Fighter = Struct.new(:name)

  test "each category's marks follow the referee's line that judges it, led by the gen-6 box's label" do
    lines = ["REFEREE: Judging category 1, Mind!", "REFEREE: Judging category 2, Skill!",
             "REFEREE: Judging category 3, Body!"]
    box = ArenaJudgmentG6Scene.new
    box.updateJudgment(nil, 0, pikachu, onix, [0, 2, 1], [0, 1, 2])
    lines.each_with_index do |line, i|
      box.updateJudgment(nil, i + 1, pikachu, onix, [0, 2, 1], [0, 1, 2])
      PokeAccess.say_dialogue(line)
    end
    assert_equal [[lines[0], false], ["Mind: #{I18n.t(:arena_tie)}", false],
                  [lines[1], false], ["Skill: #{win('Pikachu')}, #{lose('Onix')}", false],
                  [lines[2], false], ["Body: #{lose('Pikachu')}, #{win('Onix')}", false]], SpeakCapture.log
  ensure
    PokeAccess.after_next_line(nil)
  end

  test "a box that paints no category column gives the marks without a label" do
    assert_nil Judgment.labels(nil)
    assert_nil Judgment.labels([["Pikachu", :positions, 64, 0], ["Onix", :positions, 224, 0]])
    rows = [["Pikachu", :positions, 64, 0], ["VS", :positions, 144, 0], ["Onix", :positions, 224, 0],
            ["3", :positions, 64, 160], ["1", :positions, 224, 160]]
    assert_nil Judgment.labels(rows), "a middle column without the three categories"
    assert_equal "#{lose('Pikachu')}, #{win('Onix')}", Judgment.result(0, nil, pikachu, onix, [0], [2])
  end

  test "a phase past the three categories, or none, promises nothing" do
    [0, 4, nil].each do |phase|
      Judgment.judged([nil, phase, pikachu, onix, [1, 1, 1], [0, 0, 0]], [])
      PokeAccess.say_dialogue("REFEREE: Phase #{phase.inspect}!")
    end
    assert_equal ["REFEREE: Phase 0!", "REFEREE: Phase 4!", "REFEREE: Phase nil!"], SpeakCapture.lines
  end

  private

  def pikachu
    Fighter.new("Pikachu")
  end

  def onix
    Fighter.new("Onix")
  end

  def win(name)
    I18n.t(:arena_win, :name => name)
  end

  def lose(name)
    I18n.t(:arena_lose, :name => name)
  end
end
