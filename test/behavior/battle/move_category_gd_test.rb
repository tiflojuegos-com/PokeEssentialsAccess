# The move line on the modern screens: the damage category, painted as an icon beside the type, said as one word right
# after it (GameData::Move's stub answers category 0, physical, and type TYPE1), and the line for data that tells less.
class MoveCategoryGdTest < PokeAccessTest
  T = PokeAccess::I18n

  test "the summary's move detail says it after the type" do
    move = Struct.new(:id, :name, :pp, :total_pp).new(:THUNDERBOLT, "Rayo", 15, 10)
    assert_equal stub_line("Rayo", T.t(:mv_pp, :pp => 15, :tot => 10), "descTHUNDERBOLT"),
                 PokeAccess::SummaryGameData.move_detail(Poke.build(:name => "Pika"), move)
  end

  test "a move reminder row says it after the type, behind the row's level" do
    assert_equal "Nv. 12. #{stub_line("MoveTHUNDERBOLT", "descTHUNDERBOLT")}",
                 PokeAccess::UIV21.move_from_entry([:THUNDERBOLT, "Nv. 12"])
  end

  test "a move looked up by id says it after the type" do
    assert_equal stub_line("MoveTHUNDERBOLT", "descTHUNDERBOLT"), PokeAccess::MoveInfo.by_id(:THUNDERBOLT)
  end

  test "a move looked up by id says the type from medium and the category only in full" do
    typed = "MoveTACKLE. #{T.t(:mv_type, :t => "TypeTYPE1")}"
    assert_equal ["MoveTACKLE", typed, stub_line("MoveTACKLE", "descTACKLE")],
                 vb_levels { PokeAccess::MoveInfo.by_id(:TACKLE, :learn_move) }
  end

  test "a move id the data does not know has no line" do
    assert_nil with_move_data(:GONE, nil) { PokeAccess::MoveInfo.by_id(:GONE) }
  end

  test "a move whose data has neither power nor accuracy says no damage and never misses" do
    bare = Struct.new(:name, :type, :category, :description).new("Forcejeo", :TYPE1, 0, "")
    line = with_move_data(:STRUGGLE, bare) { PokeAccess::MoveInfo.by_id(:STRUGGLE) }
    assert_equal ["Forcejeo", T.t(:mv_type, :t => "TypeTYPE1"), T.t(:cat_physical),
                  T.t(:mv_power, :p => T.t(:mv_power_none)), T.t(:mv_acc, :a => T.t(:mv_acc_perfect))].join(". "), line
  end

  private

  # Runs the block with GameData::Move answering data for id, and as before for any other, then puts it back.
  def with_move_data(id, data)
    original = GameData::Move.method(:get)
    GameData::Move.define_singleton_method(:get) { |asked| asked == id ? data : original.call(asked) }
    yield
  ensure
    GameData::Move.define_singleton_method(:get, original) if original
  end

  # A stub move's line: its name, type TYPE1, the physical word, power 40 and accuracy 100, then the tail parts.
  def stub_line(name, *tail)
    ([name, T.t(:mv_type, :t => "TypeTYPE1"), T.t(:cat_physical), T.t(:mv_power, :p => "40"), T.t(:mv_acc, :a => 100)] +
     tail).join(". ")
  end
end
