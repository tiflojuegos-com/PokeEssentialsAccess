# PokéLiberty's Unown notebook (plugins/bloc_unown.rb, BlocUnownScene): the letter under the cursor, or that its form
# is unseen (a blank cell), and the word written with Unown icons, said as each key changes it.
class BlocUnownTest < PokeAccessTest
  def setup
    super
    @saved_vars = $game_variables
    Object.const_set(:UNOWN_SHAPE, "ABCDEFGHIJKLMNOPQRSTUVWXYZ?!") unless Object.const_defined?(:UNOWN_SHAPE)
    Object.const_set(:UNOWN_WORD_VARIABLE, 69) unless Object.const_defined?(:UNOWN_WORD_VARIABLE)
    $game_variables = { 69 => "AB" }
  end

  def teardown
    $game_variables = @saved_vars
    super
  end

  test "the opening cell is said queued with the word, then each move interrupting" do
    scene = notebook(1, [1])
    PokeAccess::BlocUnown.moved(scene)
    first = SpeakCapture.log.first
    assert_equal false, first[1], "the opening is queued"
    assert first[0].index("B") == 0 && first[0].include?(PokeAccess::I18n.t(:unown_word, :word => "AB")), first[0]
    SpeakCapture.clear
    scene.instance_variable_set(:@selIdx, 27)
    PokeAccess::BlocUnown.moved(scene)
    unseen = PokeAccess::I18n.t(:unown_unseen, :letter => PokeAccess::I18n.t(:unown_exclaim))
    assert_equal [[unseen, true]], SpeakCapture.log, "an unseen form's blank cell, the mark by name"
  end

  test "a move that did not change the cell says nothing" do
    scene = notebook(0, [0])
    PokeAccess::BlocUnown.moved(scene)
    SpeakCapture.clear
    PokeAccess::BlocUnown.moved(scene)
    assert_nothing_spoken
  end

  test "an edit says the word it leaves, marks by name, and an edit that changed nothing is silent" do
    scene = notebook(0, [0])
    $game_variables[69] = "AB?"
    PokeAccess::BlocUnown.edited(scene, "AB")
    assert_equal [PokeAccess::I18n.t(:unown_word, :word => "AB #{PokeAccess::I18n.t(:unown_question)}")], SpeakCapture.lines
    SpeakCapture.clear
    PokeAccess::BlocUnown.edited(scene, "AB?")
    assert_nothing_spoken
    $game_variables[69] = ""
    PokeAccess::BlocUnown.edited(scene, "AB?")
    assert_equal [PokeAccess::I18n.t(:unown_word_empty)], SpeakCapture.lines
  end

  private

  # A notebook with its cursor on idx and the forms seen at the given cells.
  def notebook(idx, seen)
    sprites = {}
    seen.each { |i| sprites["form#{i}"] = Object.new }
    World.stub_scene(:@selIdx => idx, :@sprites => sprites)
  end
end
