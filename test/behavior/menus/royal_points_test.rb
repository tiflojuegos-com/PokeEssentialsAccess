# Royal's trainer-points screen (PokemonOptionPuntos_Scene): the focused slider as "name: value" and its value after
# each edit, the help line on the info key, and the running total, read on open and after each change.

# The screen: the total painted as it opens, the help textbox and the slider window, and the selection changes under
# both names the forks give them.
class PokemonOptionPuntos_Scene
  attr_reader :sprites

  def initialize(window = nil)
    @sprites = { "puntos_totales" => FakeTextWin.new, "textbox" => FakeTextWin.new, "option" => window }
  end

  def pbStartScene; @sprites["puntos_totales"].text = "Total: 12"; end
  def pbEndScene; end
  def pbChangeSelection; :changed; end
  def updateDescription; :described; end
end

# The screen's slider window: @options with their values (win[i]), the focused index, and value_changed on the frame
# a value moved; the row past the options closes the screen.
class Window_PokemonOption_Sky
  attr_accessor :index, :value_changed

  def initialize(options, values)
    @options = options
    @values = values
    @index = 0
    @value_changed = false
  end

  def [](i); @values[i]; end
  def update; :updated; end
end

path = File.join(Harness::ROOT, "games", "royal_common", "puntos.rb")
eval(Harness.source(path), TOPLEVEL_BINDING, path)

class RoyalPointsTest < PokeAccessTest
  # The screen's sliders as Royal builds them: 0 to 10 points each.
  OPTIONS = [SliderOption.new("Entrenadores", 0, 10), SliderOption.new("Capturas", 0, 10)]

  test "reads the focused slider as its name and the value it paints" do
    win = Window_PokemonOption_Sky.new(OPTIONS, [3, 7])
    win.index = 1
    assert_equal "Capturas: 7", PokeAccess::Menus.focused_text(win)
  end

  test "reads the row past the sliders as the closing row the game paints" do
    win = Window_PokemonOption_Sky.new(OPTIONS, [3, 7])
    win.index = 2
    assert_equal ["Cerrar", "Close"],
                 [PokeAccess::Menus.focused_text(win), with_intl("Cerrar" => "Close") { PokeAccess::Menus.focused_text(win) }]
  end

  test "reads a slider with no name by its value alone" do
    win = Window_PokemonOption_Sky.new([SliderOption.new("", 0, 10)], [4])
    assert_equal "4", PokeAccess::Menus.focused_text(win)
  end

  test "reads a slider whose value the window cannot give at 0" do
    win = Window_PokemonOption_Sky.new(OPTIONS, nil)
    assert_equal "Entrenadores: 0", PokeAccess::Menus.focused_text(win)
  end

  test "reads nothing for a window with no options" do
    win = Window_PokemonOption_Sky.new(nil, [])
    assert_nil PokeAccess::Menus.focused_text(win)
  end

  test "says a slider's new value, interrupting, on the frame it moves" do
    win = Window_PokemonOption_Sky.new(OPTIONS, [3, 7])
    win.value_changed = true
    assert_equal :updated, win.update, "the window's own value"
    assert_equal [["Entrenadores: 3", true]], SpeakCapture.log
  end

  test "says nothing on a frame where no value moved" do
    Window_PokemonOption_Sky.new(OPTIONS, [3, 7]).update
    assert_nothing_spoken
  end

  test "says nothing for a window that never flags a moved value" do
    win = Window_PokemonOption_Sky.new(OPTIONS, [3, 7])
    win.singleton_class.send(:undef_method, :value_changed)
    assert_equal :updated, win.update, "the window's own value"
    assert_nothing_spoken
  end

  test "puts the help line under the sliders on the info key as the selection moves, under either name" do
    [:pbChangeSelection, :updateDescription].each do |meth|
      PokeAccess::Info.set_info(nil, nil)
      win = Window_PokemonOption_Sky.new(OPTIONS, [3, 7])
      scene = PokemonOptionPuntos_Scene.new(win)
      scene.sprites["textbox"].text = "Puntos por derrotar Entrenadores."
      scene.send(meth)
      win.index = 1
      scene.sprites["textbox"].text = "Puntos por capturar Pokémon."
      scene.send(meth)
      assert_equal "Puntos por capturar Pokémon.", PokeAccess::Info.info_text, meth.to_s
    end
  end

  test "reads the total the screen paints as it opens, queued" do
    on_points_screen do |scene|
      scene.pbStartScene
      PokeAccess::InfoWindow.tick
      assert_equal [["Total: 12", false]], SpeakCapture.log
    end
  end

  test "reads the new total after an edit, and an unchanged total no more" do
    on_points_screen do |scene|
      scene.pbStartScene
      PokeAccess::InfoWindow.tick
      SpeakCapture.clear
      scene.sprites["puntos_totales"].text = "Total: 9"
      PokeAccess::InfoWindow.tick
      PokeAccess::InfoWindow.tick
      assert_equal [["Total: 9", false]], SpeakCapture.log
    end
  end

  test "reads the total no more once the screen closes" do
    on_points_screen do |scene|
      scene.pbStartScene
      scene.pbEndScene
      scene.sprites["puntos_totales"].text = "Total: 30"
      PokeAccess::InfoWindow.tick
      assert_nothing_spoken
    end
  end

  private

  # Runs the block with a points screen, the information windows' live scene put back after.
  def on_points_screen
    was = PokeAccess::InfoWindow.live
    yield PokemonOptionPuntos_Scene.new
  ensure
    was ? PokeAccess::InfoWindow.enter(was) : PokeAccess::InfoWindow.leave
  end
end
