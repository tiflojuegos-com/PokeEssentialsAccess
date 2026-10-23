# FL's Type Quiz (plugins/fl_type_quiz.rb) on the GameData engine, where the quiz's type symbols name their types through
# GameData::Type with no number between: the question's types, the focused answer and a wrong pick's result with the right
# answer, over stand-ins that call their methods in the order the script does.
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
    def initialize(question)
      @question = question
      @questions_total = 3
    end

    def start_scene
      @questions_count = 1
      @questions_right = 0
      @index = 0
      next_question
    end

    def next_question
      @answer_label = ""
      refresh
      @index = 2
      update_cursor
    end

    def refresh
      rows = [["Correct: #{@questions_right}", 32, 118], [@answer_label, 256, 118, 2],
              ["Question: #{@questions_count}/#{@questions_total}", 480, 118, true]]
      pbDrawTextPositions(nil, rows)
    end

    def update_cursor
      @arrow_y = 152 + @index * 40
    end

    def pick_wrong
      @answer_label = "Wrong!"
      @index = @question.result
      update_cursor
      refresh
    end
  end
end
type_quiz_path = File.join(Harness::ROOT, "plugins", "fl_type_quiz.rb")
eval(Harness.source(type_quiz_path), TOPLEVEL_BINDING, type_quiz_path)

class FlTypeQuizGdTest < PokeAccessTest
  STRINGS = { "tquiz_matchup" => "Movimiento %{attack} contra Pokémon %{defense}",
              "tquiz_right" => "Respuesta correcta: %{answer}" }

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @saved = STRINGS.keys.map { |k| [k, table[k]] }
    STRINGS.each { |k, v| table[k] = v }
  end

  def teardown
    table = PokeAccess::I18n.table(:es)
    (@saved || []).each { |k, v| v.nil? ? table.delete(k) : table[k] = v }
    super
  end

  test "names the question's types through GameData and says the answer the cursor starts on, queued" do
    TypeQuiz::Scene.new(TypeQuiz::Question.new(:FIRE, :WATER, :GRASS, 3)).start_scene
    assert_equal [["Movimiento TypeFIRE contra Pokémon TypeWATER/TypeGRASS. Normal, 3 de 6", false]], SpeakCapture.log
  end

  test "names a defender with a single type once" do
    TypeQuiz::Scene.new(TypeQuiz::Question.new(:FIRE, :WATER, :WATER, 3)).start_scene
    assert_equal ["Movimiento TypeFIRE contra Pokémon TypeWATER. Normal, 3 de 6"], SpeakCapture.lines
  end

  test "says a type the data names with nothing, or cannot name, by its symbol" do
    unnamed = Object.new
    def unnamed.type_name(id); id == :WATER ? "" : nil; end
    Harness.with_provider(unnamed, 30) do
      TypeQuiz::Scene.new(TypeQuiz::Question.new(:FIRE, :WATER, :GRASS, 3)).start_scene
    end
    assert_equal ["Movimiento FIRE contra Pokémon WATER/GRASS. Normal, 3 de 6"], SpeakCapture.lines
  end

  test "keeps the question and the painted status line on the info key" do
    TypeQuiz::Scene.new(TypeQuiz::Question.new(:FIRE, :WATER, :GRASS, 3)).start_scene
    assert_equal "Movimiento TypeFIRE contra Pokémon TypeWATER/TypeGRASS. Correct: 0. Question: 1/3",
                 PokeAccess::Info.info_text
  end

  test "says a wrong pick's result with the right answer the screen points at, once" do
    scene = TypeQuiz::Scene.new(TypeQuiz::Question.new(:FIRE, :WATER, :GRASS, 3))
    scene.start_scene
    SpeakCapture.clear
    scene.pick_wrong
    assert_equal [["Wrong! Respuesta correcta: 1/2", true]], SpeakCapture.log
  end
end
