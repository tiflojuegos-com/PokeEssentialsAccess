# The DBK Move Info panel's figures are the final ones it draws (through pbGetFinalModifiers), caught from its own
# draw call by alignment: four centred values beside left-aligned labels, so shifted columns and translated labels
# still match; with nothing caught, the move data's.
class DbkMoveinfoFiguresTest < PokeAccessTest
  T = PokeAccess::I18n
  MoveInfo = PokeAccess::DBKMoveInfo
  Move = Struct.new(:name, :power, :accuracy, :priority, :category)

  test "says the move data's power and accuracy when nothing was painted, and a priority only when it has one" do
    with_capture do
      assert_equal [power("90"), acc(100)], MoveInfo.figures(Move.new("Lanzallamas", 90, 100, 0, 0))
      assert_equal [power("40"), acc(100), T.t(:mv_priority, :n => "1")],
                   MoveInfo.figures(Move.new("Ataque Rapido", 40, 100, 1, 0))
      assert_equal [power(T.t(:mv_power_var)), acc(T.t(:mv_acc_perfect))],
                   MoveInfo.figures(Move.new("Desquite", 1, 0, 0, 0))
    end
  end

  test "says the painted figures over the move data's, the added effect's chance included" do
    with_capture do
      MoveInfo.capture_on
      MoveInfo.note_draw(panel("135", "100", "---", "10%"))
      assert_equal [power("135"), acc("100"), T.t(:mv_effect, :n => "10%")], MoveInfo.figures(lanzallamas)
    end
  end

  test "says a painted priority" do
    with_capture do
      MoveInfo.capture_on
      MoveInfo.note_draw(panel("40", "100", "+1", "---"))
      assert_equal [power("40"), acc("100"), T.t(:mv_priority, :n => "+1")], MoveInfo.figures(lanzallamas)
    end
  end

  test "words painted dashes as no damage, never misses, no priority and no added effect" do
    with_capture do
      MoveInfo.capture_on
      MoveInfo.note_draw(panel("---", "---", "---", "---"))
      assert_equal [power(T.t(:mv_power_none)), acc(T.t(:mv_acc_perfect))], MoveInfo.figures(lanzallamas)
    end
  end

  test "words a painted ??? power as variable" do
    with_capture do
      MoveInfo.capture_on
      MoveInfo.note_draw(panel("???", "100", "---", "---"))
      assert_equal [power(T.t(:mv_power_var)), acc("100")], MoveInfo.figures(lanzallamas)
    end
  end

  test "says no power for a status move, painted or not" do
    status = Move.new("Danza Espada", 0, 0, 0, 2)
    with_capture do
      assert_equal [acc(T.t(:mv_acc_perfect))], MoveInfo.figures(status), "from the move data"
      MoveInfo.capture_on
      MoveInfo.note_draw(panel("---", "---", "---", "---"))
      assert_equal [acc(T.t(:mv_acc_perfect))], MoveInfo.figures(status), "painted"
    end
  end

  test "reads an older copy's panel, which centres its power and accuracy labels and paints no priority" do
    with_capture do
      MoveInfo.capture_on
      MoveInfo.note_draw([["Lanzallamas", 10, 8, :left], ["Pow:", 416, 10, :center], ["Acc:", 416, 40, :center],
                          ["Effct:", 282, 40, :left], ["135", 468, 10, :center], ["100", 468, 40, :center],
                          ["10%", 356, 40, :center], ["Z-Power: 175", 10, 128, :left]])
      assert_equal [power("135"), acc("100"), T.t(:mv_effect, :n => "10%")], MoveInfo.figures(lanzallamas)
      assert_equal "Z-Power: 175", MoveInfo.bonus
    end
  end

  test "keeps the last reading through a draw without exactly four centred values" do
    with_capture do
      MoveInfo.capture_on
      MoveInfo.note_draw(panel("135", "100", "---", "---"))
      MoveInfo.note_draw([["algo", 0, 0, :left], ["otra cosa", 1, 1, :left]])
      MoveInfo.note_draw([["1", 0, 0, :center], ["2", 1, 1, :center], ["3", 2, 2, :center]])
      MoveInfo.note_draw(panel("1", "2", "3", "4") + [["5", 9, 9, :center]])
      MoveInfo.note_draw("not rows")
      assert_equal [power("135"), acc("100")], MoveInfo.figures(lanzallamas)
    end
  end

  test "catches the figures from the game's own text painter while the panel draws" do
    with_capture do
      MoveInfo.capture_on
      pbDrawTextPositions(nil, panel("150", "95", "---", "30%"))
      assert_equal [power("150"), acc("95"), T.t(:mv_effect, :n => "30%")], MoveInfo.figures(lanzallamas)
    end
  end

  test "catches nothing once the panel has drawn, and forgets its reading when it opens again" do
    with_capture do
      MoveInfo.capture_on
      MoveInfo.note_draw(panel("135", "100", "---", "---"))
      MoveInfo.capture_off
      MoveInfo.note_draw(panel("150", "95", "---", "---"))
      assert_equal [power("135"), acc("100")], MoveInfo.figures(lanzallamas), "a draw after the panel's"
      MoveInfo.capture_on
      assert_equal [power("90"), acc(100)], MoveInfo.figures(lanzallamas), "the next opening, before it draws"
    end
  end

  private

  # Flamethrower in the move data: 90 power, 100 accuracy, no priority, physical.
  def lanzallamas
    Move.new("Lanzallamas", 90, 100, 0, 0)
  end

  # The panel's draw call: the move's name, then each label left-aligned beside its centred value.
  def panel(pow, acc, pri, eff)
    [["Lanzallamas", 10, 12, :left], ["Pow", 256, 40, :left], [pow, 309, 40, :center], ["Acc", 348, 40, :left],
     [acc, 401, 40, :center], ["Pri", 442, 40, :left], [pri, 484, 40, :center], ["Eff", 428, 12, :left],
     [eff, 484, 12, :center]]
  end

  # The power phrase for a painted or worded value.
  def power(word)
    T.t(:mv_power, :p => word)
  end

  # The accuracy phrase for a painted or worded value.
  def acc(word)
    T.t(:mv_acc, :a => word)
  end

  # Runs the block with the panel's capture emptied and disarmed, then puts back what it held before.
  def with_capture
    saved = [:@painted, :@bonus, :@armed].map { |v| [v, MoveInfo.instance_variable_get(v)] }
    MoveInfo.capture_on
    MoveInfo.capture_off
    yield
  ensure
    saved.each { |v, value| MoveInfo.instance_variable_set(v, value) }
  end
end
