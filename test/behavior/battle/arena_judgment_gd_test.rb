# The Battle Arena's judgment on the GameData engine (core/battle/arena_judgment.rb): each repaint of the judgment box
# that judges a category says that category's marks for both sides, led by the label the box paints, right after the
# referee's line that judges it. The file's hook section is evaluated again over the stand-in below so its hook binds.

# The stock box (Battle::Scene#updateJudgment) as far as its text goes: the names and VS, the three categories down
# the middle column, then the totals beside the judgment row.
class Battle::Scene
  def updateJudgment(_window, phase, battler1, battler2, ratings1, ratings2)
    total1 = (0...phase).inject(0) { |sum, i| sum + ratings1[i] }
    total2 = (0...phase).inject(0) { |sum, i| sum + ratings2[i] }
    pbDrawTextPositions(nil, [[battler1.name, 64, 6], ["VS", 144, 6], [battler2.name, 224, 6], ["Mente", 144, 54],
                              ["Habilidad", 144, 86], ["Cuerpo", 144, 118], [total1.to_s, 64, 166],
                              ["Juicio", 144, 166], [total2.to_s, 224, 166]])
    :painted
  end
end

arena = File.join(Harness::ROOT, "core", "battle", "arena_judgment.rb")
source = Harness.source(arena)
module_end = source.index("\n", source.index(/^end\s*$/)) + 1
eval(source[module_end..-1], TOPLEVEL_BINDING, arena, source[0, module_end].count("\n") + 1)

class ArenaJudgmentGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  Fighter = Struct.new(:name)
  LINES = ["ÁRBITRO: ¡Juzgando la categoría 1, Mente!", "ÁRBITRO: ¡Juzgando la categoría 2, Habilidad!",
           "ÁRBITRO: ¡Juzgando la categoría 3, Cuerpo!"].freeze

  test "each category's marks follow the referee's line that judges it, led by the label the box paints" do
    judging([2, 1, 0], [0, 1, 2]) { |i| PokeAccess.say_dialogue(LINES[i]) }
    assert_equal [[LINES[0], false], ["Mente: #{win('Pikachu')}, #{lose('Onix')}", false],
                  [LINES[1], false], ["Habilidad: #{I18n.t(:arena_tie)}", false],
                  [LINES[2], false], ["Cuerpo: #{lose('Pikachu')}, #{win('Onix')}", false]], SpeakCapture.log
  end

  test "the box's first paint, before any category is judged, adds nothing to the next line" do
    scene.updateJudgment(nil, 0, pikachu, onix, [2, 1, 0], [0, 1, 2])
    PokeAccess.say_dialogue("ÁRBITRO: ¡Se acabó!")
    assert_equal [["ÁRBITRO: ¡Se acabó!", false]], SpeakCapture.log
  ensure
    PokeAccess.after_next_line(nil)
  end

  test "the box keeps its own result" do
    assert_equal :painted, scene.updateJudgment(nil, 1, pikachu, onix, [1, 1, 1], [0, 0, 0])
  ensure
    PokeAccess.after_next_line(nil)
  end

  private

  # The box painted for each judged category in turn, the block then run with the category's index as the line the
  # referee says after that repaint; a mark still promised when it ends is dropped.
  def judging(ratings1, ratings2)
    box = scene
    box.updateJudgment(nil, 0, pikachu, onix, ratings1, ratings2)
    3.times do |i|
      box.updateJudgment(nil, i + 1, pikachu, onix, ratings1, ratings2)
      yield i
    end
  ensure
    PokeAccess.after_next_line(nil)
  end

  def scene
    Battle::Scene.new
  end

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
