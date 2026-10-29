# The modern relearner's rows (UIV21.move_from_entry) as the screen paints them: the row's label, said from medium, and
# the move's figures as they are for the Pokemon it is for.
class RelearnerShownGdTest < PokeAccessTest
  test "a row says its label, then the move's name, type, category, power, accuracy and description" do
    t = PokeAccess::I18n
    assert_equal ["Nv. 12", "MoveRETURN", t.t(:mv_type, :t => "TypeTYPE1"), t.t(:cat_physical), t.t(:mv_power, :p => 40),
                  t.t(:mv_acc, :a => 100), "descRETURN"].join(". "), row([:RETURN, "Nv. 12"])
  end

  test "a move is said with each figure the screen shows for the Pokemon" do
    t = PokeAccess::I18n
    plain = row([:RETURN, "Nv. 12"])
    pk = Poke.build(:name => "Pika")
    {
      :display_power => [102, " 40.", " 102."],
      :display_accuracy => [50, " 100.", " 50."],
      :display_type => [:DARK, "TypeTYPE1", "TypeDARK"],
      :display_category => [1, t.t(:cat_physical), t.t(:cat_special)]
    }.each do |meth, (value, from, to)|
      with_shown(meth, value) do
        assert_equal plain.sub(from, to), row([:RETURN, "Nv. 12"], pk), "#{meth} for the Pokemon"
      end
    end
  end

  test "without the Pokemon a move keeps its own figures" do
    plain = row([:RETURN, "Nv. 12"])
    with_shown(:display_power, 102) do
      with_shown(:display_type, :DARK) do
        assert_equal plain, row([:RETURN, "Nv. 12"])
      end
    end
  end

  test "a row's label is said from medium on, and the info key keeps the whole row at every level" do
    whole = row([:RETURN, "Nv. 12"])
    said = vb_levels { [row([:RETURN, "Nv. 12"]), PokeAccess::Info.info_text] }
    assert_equal [GameData::Move.get(:RETURN).name, whole], said[0], "brief: the move's name alone"
    assert_equal [true, true], said[1..2].map { |line, _| line.start_with?("Nv. 12. ") }, "medium and full: the label first"
    assert_equal [whole, whole, whole], said.map { |_, info| info }, "the info key"
  end

  test "a move given without a label is said by its figures alone" do
    bare = row([:RETURN, "Nv. 12"]).sub("Nv. 12. ", "")
    assert_equal bare, row(:RETURN), "a move id"
    assert_equal bare, row(Struct.new(:id).new(:RETURN)), "a move object"
  end

  test "no entry, or a move the game's data does not know, is no row" do
    assert_nil row(nil), "no entry"
    with_unknown_move(:GHOSTMOVE) { assert_nil row([:GHOSTMOVE, "Nv. 3"]), "an unknown move" }
  end

  private

  # The relearner's spoken row for a [move, label] entry, for pk or for the move's plain data.
  def row(entry, pk = nil)
    PokeAccess::UIV21.move_from_entry(entry, pk)
  end

  # Runs the block with GameData::Move answering meth (one of the display_* the screen asks) with value.
  def with_shown(meth, value)
    GameData::Move.send(:define_method, meth) { |_pk| value }
    yield
  ensure
    GameData::Move.send(:remove_method, meth)
  end

  # Runs the block with the game's move data raising for id, as the real GameData::Move.get does for an unknown move.
  def with_unknown_move(id)
    real = GameData::Move.method(:get)
    GameData::Move.define_singleton_method(:get) { |i| i == id ? raise(ArgumentError, "unknown move #{i}") : real.call(i) }
    yield
  ensure
    GameData::Move.define_singleton_method(:get, real)
  end
end
