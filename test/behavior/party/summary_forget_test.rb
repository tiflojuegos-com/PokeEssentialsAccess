# The gen-6 move-to-forget scene and the summary's move detail (core/party/gen6/summary_g6.rb): the prompt for a new
# move, the one an item that restores PP asks under its own question, the selection back on the first move when the
# loop asks again, and the Pokemon's own types the detail draws above the moves.
class SummaryForgetTest < PokeAccessTest
  T = PokeAccess::I18n
  Move = Struct.new(:id, :pp, :totalpp)

  test "learning a move says the move, that one is to be forgotten, and the current moves" do
    pk = pika
    PokemonSummary.new(PokemonSummaryScene.new).pbStartForgetScreen([pk], 0, 80)
    assert_equal [[detail(pk, 33), true], [forget_list(80), false]], SpeakCapture.log
  end

  test "the move deleter, with no move to learn, still asks which move to forget" do
    pk = pika
    PokemonSummary.new(PokemonSummaryScene.new).pbStartForgetScreen([pk], 0, 0)
    assert_equal [forget_list(0), false], SpeakCapture.log.last
  end

  test "an Ether's move choice says the moves with their PP after its question, and nothing of forgetting" do
    pk = pika
    PokemonSummary.new(PokemonSummaryScene.new).pbStartChooseMoveScreen([pk], 0, "Restore which move?")
    assert_equal [[detail(pk, 33), true], [pp_list, false]], SpeakCapture.log
  end

  test "asked again after a refused HM, says the selection back on the first move" do
    pk = pika
    scene = PokemonSummaryScene.new
    scene.instance_variable_set(:@forget_picks, [1, 0])
    screen = PokemonSummary.new(scene)
    screen.hm_slots = [1]
    screen.pbStartForgetScreen([pk], 0, 80)
    again = PokeAccess.sentences([forget_list(80), "#{T.t(:sm_position, :n => 1)}, Mov33"])
    assert_equal [[forget_list(80), false], [again, false]], SpeakCapture.log[1..-1]
  end

  test "asked again after B under an Ether's question, says the selection back on the first move and keeps it on the info key" do
    pk = pika
    scene = PokemonSummaryScene.new
    scene.instance_variable_set(:@forget_picks, [-1, 1])
    PokemonSummary.new(scene).pbStartChooseMoveScreen([pk], 0, "Restore which move?")
    again = PokeAccess.sentences([pp_list, "#{T.t(:sm_position, :n => 1)}, Mov33"])
    assert_equal [again, false], SpeakCapture.log.last
    assert_equal PokeAccess::Info.move_info(pk.moves[0]), PokeAccess::Info.info_text
  end

  test "the move-to-forget scene says the Pokemon's types before its first detail only" do
    pk = typed(pika)
    scene = PokemonSummaryScene.new
    scene.pbStartForgetScene([pk], 0, 80)
    scene.drawSelectedMove(pk, 80, 85)
    assert_equal [[typed_detail(pk, 33), true], [detail(pk, 85), true]], SpeakCapture.log
  end

  test "the summary's move cursor says the Pokemon's types before its first detail each time it opens" do
    pk = typed(pika)
    scene = PokemonSummaryScene.new
    scene.pbStartScene([pk], 0)
    SpeakCapture.clear
    2.times do
      scene.pbMoveSelection
      scene.drawSelectedMove(pk, 0, 33)
      scene.drawSelectedMove(pk, 0, 85)
    end
    once = [[typed_detail(pk, 33), true], [detail(pk, 85), true]]
    assert_equal once + once, SpeakCapture.log
  end

  test "a Pokemon whose types the data does not know has its first detail said alone" do
    pk = pika
    PokemonSummaryScene.new.pbStartForgetScene([pk], 0, 80)
    assert_equal [[detail(pk, 33), true]], SpeakCapture.log
  end

  private

  # A Pokemon knowing moves 33 (3 of 35 PP) and 85 (15 of 15).
  def pika
    Poke.build(:name => "Pika", :moves => [Move.new(33, 3, 35), Move.new(85, 15, 15)])
  end

  # pk with the gen-6 type numbers 3 and 4, as the data names them.
  def typed(pk)
    def pk.type1; 3; end
    def pk.type2; 4; end
    pk
  end

  # A move's detail as the summary's move cursor reads it.
  def detail(pk, id)
    PokeAccess::Info.move_by_id_info(pk, id, :summary_move)
  end

  # The first detail of a typed Pokemon: its types, then the move.
  def typed_detail(pk, id)
    PokeAccess.sentences([T.t(:sum_type, :t => "Tipo3 Tipo4"), detail(pk, id)])
  end

  # The forget prompt of pika: the move to learn (none for 0), that one is to be forgotten, and its moves by position.
  def forget_list(learn)
    head = learn == 0 ? "" : "#{T.t(:sm_learn, :move => "Mov#{learn}")}. "
    "#{head}#{T.t(:sm_choose_forget)}. #{T.t(:sm_moves, :list => "#{pos(1, 'Mov33')}, #{pos(2, 'Mov85')}")}"
  end

  # pika's moves by position, each with its PP.
  def pp_list
    T.t(:sm_moves, :list => "#{pos(1, 'Mov33')}, #{T.t(:mv_pp, :pp => 3, :tot => 35)}, " \
                            "#{pos(2, 'Mov85')}, #{T.t(:mv_pp, :pp => 15, :tot => 15)}")
  end

  # A move by its position.
  def pos(n, name)
    T.t(:sm_move_pos, :n => n, :name => name)
  end
end
