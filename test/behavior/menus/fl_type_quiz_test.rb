# FL's Type Quiz (plugins/fl_type_quiz.rb) over the gen-6 stand-ins of its scene and question, which call their methods in
# the order the script does: next_question repaints and moves the cursor, a wrong pick moves it again to the right answer
# and repaints. Each question says its types, which the game paints only as pictures, and the focused answer; a cursor step
# the answer; a pick the result, once; the status line stays on the info key.
module TypeQuiz
  class Question
    ANSWERS = ["4x", "2x", "Normal", "1/2", "1/4", "Immune"]
    attr_reader :attack_type, :defense1_type, :defense2_type, :result

    def initialize(attack, defense1, defense2, result)
      @attack_type = attack
      @defense1_type = defense1
      @defense2_type = defense2
      @result = result
    end
  end

  class Scene
    attr_accessor :show_right, :scrambled

    def initialize(questions)
      @queue = questions
      @questions_total = 3
      @show_right = true
    end

    def start_scene
      @questions_count = 0
      @questions_right = 0
      @index = 0
      @sprites = {}
      next_question
    end

    def next_question
      @questions_count += 1
      return if finished?
      @question = @queue.shift
      @answer_label = ""
      refresh
      @index = 2
      update_cursor
    end

    def refresh
      rows = [["Correct: #{@questions_right}", 32, 118], [@answer_label, 256, 118, 2],
              ["Question: #{@questions_count}/#{@questions_total}", 480, 118, true]]
      Question::ANSWERS.each_with_index { |answer, i| rows.push([answer, 64, 158 + i * 40]) }
      rows.reverse! if @scrambled
      drawTextEx(nil, nil, 118, 0, 1, "Stray text") if @scrambled
      pbDrawTextPositions(nil, rows)
    end

    def update_cursor
      @arrow_y = 152 + @index * 40
    end

    def move_to(index)
      @index = index
      update_cursor
    end

    def on_choose
      if @question.result == @index
        @answer_label = "Correct!"
        @questions_right += 1
      else
        @answer_label = "Wrong!"
        if @show_right
          @index = @question.result
          update_cursor
          refresh
        end
      end
      refresh
      :chosen
    end

    def finished?
      @questions_count > @questions_total
    end

    def end_scene
      :ended
    end
  end
end
type_quiz_path = File.join(Harness::ROOT, "plugins", "fl_type_quiz.rb")
eval(Harness.source(type_quiz_path), TOPLEVEL_BINDING, type_quiz_path)

class FlTypeQuizTest < PokeAccessTest
  STRINGS = { "tquiz_matchup" => "Movimiento %{attack} contra Pokémon %{defense}",
              "tquiz_right" => "Respuesta correcta: %{answer}" }
  TYPE_IDS = { :FIRE => 10, :WATER => 11, :GRASS => 12 }
  MATCHUP = "Movimiento Tipo10 contra Pokémon Tipo11/Tipo12"

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @saved = STRINGS.keys.map { |k| [k, table[k]] }
    STRINGS.each { |k, v| table[k] = v }
    TYPE_IDS.each { |name, id| PBTypes.const_set(name, id) }
  end

  def teardown
    TYPE_IDS.each_key { |name| PBTypes.send(:remove_const, name) if PBTypes.const_defined?(name) }
    table = PokeAccess::I18n.table(:es)
    (@saved || []).each { |k, v| v.nil? ? table.delete(k) : table[k] = v }
    super
  end

  test "says a new question's types and the answer the cursor starts on, queued" do
    quiz(fire_water_grass)
    assert_equal [["#{MATCHUP}. Normal, 3 de 6", false]], SpeakCapture.log
  end

  test "says one type for a defender with a single type" do
    quiz(TypeQuiz::Question.new(:FIRE, :WATER, :WATER, 3))
    assert_equal ["Movimiento Tipo10 contra Pokémon Tipo11. Normal, 3 de 6"], SpeakCapture.lines
  end

  test "says a type the gen-6 tables lack as the game's own getID takes it, the number 0, which the screen paints too" do
    quiz(TypeQuiz::Question.new(:FAIRY, :WATER, :GRASS, 3))
    assert_equal ["Movimiento Tipo0 contra Pokémon Tipo11/Tipo12. Normal, 3 de 6"], SpeakCapture.lines
  end

  test "keeps the question and the painted status line on the info key" do
    quiz(fire_water_grass)
    assert_equal "#{MATCHUP}. Correct: 0. Question: 1/3", PokeAccess::Info.info_text
  end

  test "keeps the status line in screen order whatever the order it was painted in, less a text with no position" do
    scene = TypeQuiz::Scene.new([fire_water_grass])
    scene.scrambled = true
    scene.start_scene
    assert_equal "#{MATCHUP}. Correct: 0. Question: 1/3", PokeAccess::Info.info_text
  end

  test "says the answer under the cursor with its place, cutting in, at each step" do
    scene = quiz(fire_water_grass)
    SpeakCapture.clear
    [4, 0].each { |i| scene.move_to(i) }
    assert_equal [["1/4, 5 de 6", true], ["4x, 1 de 6", true]], SpeakCapture.log
  end

  test "says nothing for a cursor outside the list of answers" do
    scene = quiz(fire_water_grass)
    SpeakCapture.clear
    [9, -1].each { |i| scene.move_to(i) }
    assert_nothing_spoken
  end

  test "says a right pick's result as the screen paints it, once, cutting in" do
    scene = quiz(fire_water_grass)
    scene.move_to(3)
    SpeakCapture.clear
    scene.on_choose
    assert_equal [["Correct!", true]], SpeakCapture.log
  end

  test "keeps the score of a right pick on the info key, without the result between its numbers" do
    scene = quiz(fire_water_grass)
    scene.move_to(3)
    scene.on_choose
    assert_equal "#{MATCHUP}. Correct: 1. Question: 1/3", PokeAccess::Info.info_text
  end

  test "says a wrong pick's result with the right answer the screen then points at, once" do
    scene = quiz(fire_water_grass)
    scene.move_to(0)
    SpeakCapture.clear
    scene.on_choose
    assert_equal [["Wrong! Respuesta correcta: 1/2", true]], SpeakCapture.log
  end

  test "says only the result of a wrong pick when the screen does not point at the right answer" do
    scene = quiz(fire_water_grass)
    scene.show_right = false
    scene.move_to(0)
    SpeakCapture.clear
    scene.on_choose
    assert_equal [["Wrong!", true]], SpeakCapture.log
  end

  test "says the next question queued, after a result it does not repeat" do
    scene = quiz(fire_water_grass, TypeQuiz::Question.new(:GRASS, :FIRE, :FIRE, 1))
    scene.move_to(3)
    scene.on_choose
    SpeakCapture.clear
    scene.next_question
    assert_equal [["Movimiento Tipo12 contra Pokémon Tipo10. Normal, 3 de 6", false]], SpeakCapture.log
  end

  test "says the last question like the others" do
    scene = quiz(fire_water_grass, fire_water_grass, TypeQuiz::Question.new(:GRASS, :FIRE, :FIRE, 1))
    2.times { scene.next_question }
    assert_equal [["Movimiento Tipo12 contra Pokémon Tipo10. Normal, 3 de 6", false]], SpeakCapture.log[-1..-1]
  end

  test "says a result again when the next question ends the same way" do
    scene = quiz(fire_water_grass, TypeQuiz::Question.new(:GRASS, :FIRE, :FIRE, 3), fire_water_grass)
    2.times do
      scene.move_to(3)
      scene.on_choose
      scene.next_question
    end
    assert_equal 2, SpeakCapture.lines.count { |l| l == "Correct!" }
  end

  test "says nothing for the call past the last question, whose end is a message of the game's" do
    scene = quiz(fire_water_grass)
    scene.instance_variable_set(:@questions_total, 1)
    SpeakCapture.clear
    scene.next_question
    assert_nothing_spoken
  end

  test "takes the question off the info key when the screen closes" do
    scene = quiz(fire_water_grass)
    assert_equal :ended, scene.end_scene
    assert_nil PokeAccess::Info.info_text
  end

  test "forgets the results it said when the screen closes" do
    scene = quiz(fire_water_grass)
    scene.move_to(3)
    scene.on_choose
    scene.end_scene
    SpeakCapture.clear
    scene.refresh
    assert_equal [["Correct!", true]], SpeakCapture.log
  end

  test "hands back what the scene's own methods answer" do
    scene = TypeQuiz::Scene.new([fire_water_grass])
    assert_equal 232, scene.start_scene, "next_question ends on the cursor's arrow"
    assert_equal 312, scene.move_to(4)
    assert_kind_of Array, scene.refresh
    assert_equal :chosen, scene.on_choose
  end

  private

  def fire_water_grass
    TypeQuiz::Question.new(:FIRE, :WATER, :GRASS, 3)
  end

  # The screen opened over the questions, which the stand-in deals out in order.
  def quiz(*questions)
    scene = TypeQuiz::Scene.new(questions)
    scene.start_scene
    scene
  end
end
