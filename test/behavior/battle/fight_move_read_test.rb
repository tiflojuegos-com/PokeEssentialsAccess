# Battle.read_fight_move, the move-list reader shared by both gen-6 fight-menu shapes (stock setIndex, and the
# Infinite Fusion fork's index= and setIndexAndMode): what it says of the focused move, once per change.
class FightMoveReadTest < PokeAccessTest
  T = PokeAccess::I18n
  Battle = PokeAccess::Battle

  test "names the move under the cursor with its category and pp" do
    Battle.read_fight_move(fight_display([fake_move("Ember")], 0))
    assert_equal [[["Ember", T.t(:cat_special), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". "), true]], SpeakCapture.log
  end

  test "says the name and pp at brief, the type from medium and the category in full" do
    disp = fight_display([typed_move("Placaje", 0, 0)], 0)
    lines = vb_levels do
      PokeAccess::Cursor.reset(disp, :fight_move)
      SpeakCapture.clear
      Battle.read_fight_move(disp)
      SpeakCapture.last
    end
    pp = T.t(:mv_pp, :pp => 35, :tot => 35)
    type = T.t(:mv_type, :t => "Tipo0")
    assert_equal ["Placaje. #{pp}", "Placaje. #{type}. #{pp}", "Placaje. #{type}. #{T.t(:cat_physical)}. #{pp}"], lines
  end

  test "says the same slot once, however often it is redrawn" do
    disp = fight_display([fake_move("Ember")], 0)
    Battle.read_fight_move(disp)
    SpeakCapture.clear
    Battle.read_fight_move(disp)
    assert_nothing_spoken
  end

  test "reads the move the cursor moves to" do
    disp = fight_display([fake_move("Ember"), fake_move("Growl", 2, 30, 40)], 0)
    Battle.read_fight_move(disp)
    SpeakCapture.clear
    disp.instance_variable_set(:@index, 1)
    Battle.read_fight_move(disp)
    assert_equal [[["Growl", T.t(:cat_status), T.t(:mv_pp, :pp => 30, :tot => 40)].join(". "), true]], SpeakCapture.log
  end

  test "hands the info key the move under the cursor" do
    Battle.read_fight_move(fight_display([fake_move("Ember"), fake_move("Growl", 2, 30, 40)], 1))
    assert_equal ["Growl", T.t(:mv_type, :t => "Tipo0"), T.t(:cat_status), T.t(:mv_power, :p => "42"),
                  T.t(:mv_acc, :a => 100), T.t(:mv_pp, :pp => 30, :tot => 40)].join(". "),
                 PokeAccess::Info.info_text
  end

  test "passes over an empty slot and keeps the last move read as the one heard" do
    disp = fight_display([fake_move("Ember"), fake_move("", 0, 0, 0), fake_move("Tackle", 3)], 0)
    Battle.read_fight_move(disp)
    SpeakCapture.clear
    disp.instance_variable_set(:@index, 1)
    Battle.read_fight_move(disp)
    assert_nothing_spoken "the empty slot"
    disp.instance_variable_set(:@index, 0)
    Battle.read_fight_move(disp)
    assert_nothing_spoken "back on the move last heard"
    disp.instance_variable_set(:@index, 2)
    Battle.read_fight_move(disp)
    assert_equal ["Tackle", T.t(:cat_physical), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". "), SpeakCapture.last,
                 "the next real move"
  end

  test "queues the opening read and interrupts on navigation" do
    Battle.read_fight_move(fight_display([fake_move("Ember")], 0), false)
    Battle.read_fight_move(fight_display([fake_move("Ember")], 0))
    line = ["Ember", T.t(:cat_special), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". ")
    assert_equal [[line, false], [line, true]], SpeakCapture.log
  end

  test "reads a move with no pp count without one" do
    Battle.read_fight_move(fight_display([Struct.new(:name, :id).new("Ember", 1)], 0))
    assert_equal [[["Ember", T.t(:cat_special)].join(". "), true]], SpeakCapture.log
  end

  test "leaves out the pp of a move whose total is 0, in its line and on the info key, as its button paints none" do
    Battle.read_fight_move(fight_display([fake_move("Ember", 1, 0, 0)], 0))
    assert_equal [[["Ember", T.t(:cat_special)].join(". "), true]], SpeakCapture.log
    assert_match(/\AEmber\. /, PokeAccess::Info.info_text.to_s)
    refute_match(/PP/, PokeAccess::Info.info_text.to_s)
  end

  test "leaves out a type the game gives no name" do
    unnamed = Object.new
    def unnamed.type_name(_id); ""; end
    def unnamed.method_missing(name, *args); PokeAccess::DataG6.send(name, *args); end
    def unnamed.respond_to_missing?(name, priv = false); PokeAccess::DataG6.respond_to?(name, priv); end
    Harness.with_provider(unnamed) { Battle.read_fight_move(fight_display([typed_move("Placaje", 0, 0)], 0)) }
    assert_equal [[["Placaje", T.t(:cat_physical), T.t(:mv_pp, :pp => 35, :tot => 35)].join(". "), true]],
                 SpeakCapture.log
  end

  test "reads a move the Reborn engine names by a symbol" do
    move = Struct.new(:move, :name, :type, :category, :pp, :totalpp).new(:TACKLE, "Placaje", 0, 0, 35, 35)
    Battle.read_fight_move(fight_display([move], 0))
    line = ["Placaje", T.t(:mv_type, :t => "Tipo0"), T.t(:cat_physical), T.t(:mv_pp, :pp => 35, :tot => 35)]
    assert_equal line.join(". "), SpeakCapture.last
  end

  test "says nothing for a display with no battler or a move list that raises" do
    Battle.read_fight_move(fight_display(nil, 0))
    broken = Object.new
    def broken.moves; raise "no moves yet"; end
    disp = Object.new
    disp.instance_variable_set(:@battler, broken)
    disp.instance_variable_set(:@index, 0)
    Battle.read_fight_move(disp)
    assert_nothing_spoken
  end

  private

  # The part of a fight display the reader touches: @battler with its move list (no battler for nil), and @index.
  def fight_display(moves, index)
    d = Object.new
    d.instance_variable_set(:@battler, moves && Struct.new(:moves).new(moves))
    d.instance_variable_set(:@index, index)
    d
  end

  # A gen-6 battle move with a name, id and pp, and neither type nor category of its own (the move data's go).
  def fake_move(name, id = 1, pp = 15, total = 15)
    Struct.new(:name, :id, :pp, :totalpp).new(name, id, pp, total)
  end

  # A battle move with its own type and category numbers and 35 pp.
  def typed_move(name, type, category)
    Struct.new(:name, :id, :type, :category, :pp, :totalpp).new(name, 7, type, category, 35, 35)
  end
end
