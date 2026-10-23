# The info key says the focused thing's sheet; with Ctrl, the focused row whole with the windows that belong to it,
# where the screen published one, else the same sheet; Shift goes before both. A battle's sheets go when it ends, and
# a ready line when its screen closes.
class InfoKeyTest < PokeAccessTest
  Info = PokeAccess::Info
  SHEET = "Poción. Restaura 20 PS."
  ROW = "Poción: 3, registrado"

  test "T says the focused thing's sheet" do
    Info.set_info(:text, SHEET, ROW)
    assert_equal [[SHEET, true]], pressing
  end

  test "Ctrl+T says the focused row whole" do
    Info.set_info(:text, SHEET, ROW)
    assert_equal [[ROW, true]], pressing(:ctrl)
  end

  test "Ctrl+T says the row with the windows that belong to it, in the order they came" do
    Info.set_info(:text, SHEET, ROW)
    Info.add_to_row("En la mochila: 3", :qty)
    Info.add_to_row("Registrado en el botón Y", :reg)
    assert_equal [["#{ROW}. En la mochila: 3. Registrado en el botón Y", true]], pressing(:ctrl)
  end

  test "a slot's new window replaces its old one" do
    Info.set_info(:text, SHEET, ROW)
    Info.add_to_row("En la mochila: 3", :qty)
    Info.add_to_row("En la mochila: 4", :qty)
    assert_equal [["#{ROW}. En la mochila: 4", true]], pressing(:ctrl)
  end

  test "a window given again keeps its place" do
    Info.set_info(:text, SHEET, ROW)
    Info.add_to_row("En la mochila: 3", :qty)
    Info.add_to_row("Registrado en el botón Y", :reg)
    Info.add_to_row("En la mochila: 3", :qty)
    assert_equal [["#{ROW}. En la mochila: 3. Registrado en el botón Y", true]], pressing(:ctrl)
  end

  test "a blank window leaves its slot as it was" do
    Info.set_info(:text, SHEET, ROW)
    Info.add_to_row("En la mochila: 3", :qty)
    Info.add_to_row("   ", :qty)
    Info.add_to_row(nil, :qty)
    assert_equal [["#{ROW}. En la mochila: 3", true]], pressing(:ctrl)
  end

  test "a new focus drops the last row's windows" do
    Info.set_info(:text, SHEET, ROW)
    Info.add_to_row("En la mochila: 3", :qty)
    Info.set_info(:text, "Antídoto. Cura el envenenamiento.", "Antídoto: 1")
    assert_equal [["Antídoto: 1", true]], pressing(:ctrl)
  end

  test "Ctrl+T on a screen with no row, or a blank one, says the sheet" do
    { nil => "no row", "   " => "a blank row" }.each do |row, what|
      Info.set_info(:text, "Una línea sin fila", row)
      assert_equal [["Una línea sin fila", true]], pressing(:ctrl), "for #{what}"
    end
  end

  test "Shift+T says the last dialogue, even with Ctrl held on a row" do
    Info.set_info(:text, SHEET, ROW)
    said = with_last_dialogue("Bienvenido a Ciudad Luz.") { pressing(:ctrl, :shift) }
    assert_equal [["Bienvenido a Ciudad Luz.", true]], said
  end

  test "with nothing published, the key says nothing" do
    assert_equal [], pressing
  end

  test "as the battle ends, the key lets go of a ready line or a move and keeps a trainer's sheet" do
    assert_equal [[["Placaje", true]], []], said_around(:text, "Placaje") { $game_temp.in_battle = false }
    { :move => [Object.new, false], :trainer => [nil, true] }.each do |kind, (data, kept)|
      before, after = said_around(kind, data) { $game_temp.in_battle = false }
      refute_empty before, "the #{kind}'s sheet is said in battle"
      assert_equal(kept ? before : [], after, "the #{kind} after it")
    end
  end

  test "a ready line goes as the screen that published it closes, and a trainer's sheet stays" do
    assert_equal [[["Una pantalla", true]], []], said_around(:text, "Una pantalla") { Info.clear_text }
    before, after = said_around(:trainer, nil) { Info.clear_text }
    refute_empty before, "the trainer's sheet is said while the screen is open"
    assert_equal before, after, "the trainer's sheet after the screen closes"
  end

  private

  # What the info key says with the given modifiers held (:ctrl, :shift), as [text, interrupt] pairs.
  def pressing(*held)
    SpeakCapture.clear
    with_modifiers(held) { PokeAccess::Keys.info_key }
    SpeakCapture.log.dup
  end

  # What the info key says on the sheet of kind and data before the block and after it, as two [text, interrupt] lists.
  def said_around(kind, data)
    Info.set_info(kind, data)
    before = pressing
    yield
    [before, pressing]
  end

  # Runs the block with the Ctrl and Shift keys read as held when listed, the real readers put back after.
  def with_modifiers(held)
    swapping(PokeAccess::Keys, :ctrl_down?, proc { held.include?(:ctrl) }) do
      swapping(PokeAccess::Keys, :shift_down?, proc { held.include?(:shift) }) { yield }
    end
  end

  # The block's value with mod's own method meth answering as body does, the method put back after.
  def swapping(mod, meth, body)
    sc = mod.singleton_class
    saved = :"info_key_test_saved_#{meth.to_s.delete('?!')}"
    sc.send(:alias_method, saved, meth)
    mod.define_singleton_method(meth, &body)
    yield
  ensure
    if sc && sc.method_defined?(saved)
      sc.send(:alias_method, meth, saved)
      sc.send(:remove_method, saved)
    end
  end

  # The block's value with line as the last dialogue, the one before put back after.
  def with_last_dialogue(line)
    was = PokeAccess.last_dialogue
    PokeAccess.note_dialogue(line)
    yield
  ensure
    PokeAccess.instance_variable_set(:@last_dialogue, was)
  end
end
