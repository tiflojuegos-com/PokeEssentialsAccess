# The generic auto-detect net (core/menus/menus.rb): a navigable SpriteWindow_Selectable with no reader of its own is
# read from its own option list as its cursor moves, through the engine stub's real window chain.
class AutoDetectNetTest < PokeAccessTest
  # A list entry that names itself through .name, or through .text.
  Named = Struct.new(:name)
  Texted = Struct.new(:text)

  test "says a generic selectable's focused option from its own list, queued the first time" do
    focus(selectable(:@items => %w[Correr Luchar Objetos]), 1)
    assert_equal [["Luchar", false]], SpeakCapture.log
  end

  test "says the option the cursor moves to, interrupting" do
    win = selectable(:@items => %w[Correr Luchar Objetos])
    focus(win, 1)
    SpeakCapture.clear
    focus(win, 2)
    assert_equal [["Objetos", true]], SpeakCapture.log
  end

  test "says nothing more while the cursor stays" do
    win = selectable(:@items => %w[Correr Luchar])
    focus(win, 1)
    SpeakCapture.clear
    win.update
    assert_nothing_spoken
  end

  test "leaves a command window to its own reader, said once" do
    focus(Window_DrawableCommand.new(%w[Guardar Salir]), 0)
    assert_equal [["Guardar", false]], SpeakCapture.log
  end

  test "says nothing with auto-detection off" do
    PokeAccess::Config.auto_detect = false
    focus(selectable(:@items => %w[Uno Dos]), 1)
    assert_nothing_spoken
  end

  test "says nothing over rows that are not text" do
    focus(selectable(:@items => [[1, 2], [3, 4]]), 0)
    focus(selectable(:@items => [nil, 7]), 0)
    assert_nothing_spoken
  end

  test "says an entry by its name or its text, or a symbol as it is spelled" do
    { Named.new("Pokédex") => "Pokédex", Texted.new("Mochila") => "Mochila", :Opciones => "Opciones",
      Struct.new(:name, :text).new("", "Guardar") => "Guardar" }.each do |entry, said|
      SpeakCapture.clear
      focus(selectable(:@items => [entry]), 0)
      assert_equal [said], SpeakCapture.lines, "for #{entry.inspect}"
    end
  end

  test "reads the first of the window's lists that holds the focused entry" do
    {
      { :@commands => %w[Correr], :@items => %w[Luchar Objetos] } => "Objetos",
      { :@commands => %w[Correr Huir], :@items => %w[Luchar Objetos] } => "Huir",
      { :@commands => [nil, [1]], :@stock => %w[Poción Antídoto] } => "Antídoto"
    }.each do |lists, said|
      SpeakCapture.clear
      focus(selectable(lists), 1)
      assert_equal [said], SpeakCapture.lines, "for #{lists.inspect}"
    end
  end

  test "says nothing for a window that ignores input, has a reader of its own, is inactive or has no cursor" do
    [{ :@ignore_input => true }, { :@access_dedicated => true }].each do |flag|
      focus(selectable(flag.merge(:@items => %w[Uno Dos])), 1)
    end
    inactive = selectable(:@items => %w[Uno Dos])
    inactive.active = false
    focus(inactive, 1)
    focus(selectable(:@items => %w[Uno Dos]), -1)
    assert_nothing_spoken
  end

  test "takes the cursor from the window's own index where it keeps it apart from @index" do
    win = selectable(:@items => %w[Correr Luchar])
    win.define_singleton_method(:index) { 1 }
    win.update
    assert_equal ["Luchar"], SpeakCapture.lines
  end

  test "says the entry again when the pocket turns under a still cursor" do
    win = selectable(:@items => %w[Poción Antídoto])
    pocket = 1
    win.define_singleton_method(:pocket) { pocket }
    focus(win, 0)
    pocket = 2
    win.update
    assert_equal %w[Poción Poción], SpeakCapture.lines
  end

  private

  # A selectable window of a class no reader knows, holding the given instance variables.
  def selectable(ivars)
    win = Class.new(SpriteWindow_Selectable).new
    ivars.each { |name, value| win.instance_variable_set(name, value) }
    win
  end

  # Puts the window's cursor on index and updates it, as the game does.
  def focus(win, index)
    win.index = index
    win.update
  end
end
