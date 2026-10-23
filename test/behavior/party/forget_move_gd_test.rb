# The modern forget-a-move screen draws the move being learned as a fifth row under the four: opening it says that
# move first, as the gen-6 reader does, then the prompt and the moves page, queued; an Ether's choice says the moves
# alone.
class ForgetMoveGdTest < PokeAccessTest
  T = PokeAccess::I18n
  Move = Struct.new(:id, :name, :pp, :total_pp, :type)
  MOVES = [[:TACKLE, "Placaje", 35, 35, :NORMAL], [:GROWL, "Gruñido", 40, 40, :NORMAL], [:EMBER, "Ascuas", 20, 25, :FIRE],
           [:BITE, "Mordisco", 25, 25, :DARK]].freeze

  test "names the move being learned, then the prompt and the four moves, queued" do
    assert_equal [["#{T.t(:sm_learn, :move => 'MoveTHUNDERBOLT')}. #{T.t(:sm_choose_forget)}. #{moves_page}", false]],
                 opened(four_moves, :THUNDERBOLT)
  end

  test "says the prompt and the moves alone when no move is named to learn" do
    assert_equal [["#{T.t(:sm_choose_forget)}. #{moves_page}", false]], opened(four_moves, nil)
  end

  test "an Ether's move choice says only the moves with their PP after its question, nothing of forgetting" do
    pk = four_moves
    scene = PokemonSummary_Scene.new(pk)
    SpeakCapture.clear
    PokemonSummaryScreen.new(scene).pbStartChooseMoveScreen([pk], 0, "Restore which move?")
    assert_equal [[moves_page, false]], SpeakCapture.log
  end

  test "says the prompt and the moves alone when the data names the move to learn with nothing" do
    blank = Object.new
    def blank.move_name(_id); ""; end
    log = Harness.with_provider(blank, 30) { opened(four_moves, :NAMELESS) }
    assert_equal [["#{T.t(:sm_choose_forget)}. #{moves_page(false)}", false]], log
  end

  private

  # Pika knowing the four MOVES, each with its PP.
  def four_moves
    Poke.build(:name => "Pika", :moves => MOVES.map { |m| Move.new(*m) })
  end

  # The moves page of four_moves: each move's painted name, its type as the engine names it ("Type<id>", left out
  # with typed false, for data that names no type) and its PP.
  def moves_page(typed = true)
    rows = MOVES.map do |_id, name, pp, tot, type|
      [name, typed ? T.t(:mv_type, :t => "Type#{type}") : nil, T.t(:mv_pp, :pp => pp, :tot => tot)].compact.join(". ")
    end
    T.t(:sm_moves, :list => rows.join(", "))
  end

  # What opening the forget screen over pk's summary says, to learn move.
  def opened(pk, move)
    scene = PokemonSummary_Scene.new(pk)
    SpeakCapture.clear
    scene.pbChooseMoveToForget(move)
    SpeakCapture.log.dup
  end
end
