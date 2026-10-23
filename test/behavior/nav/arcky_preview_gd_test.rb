# Arcky's region map (Royal): the map's mode said when the corner paints a new one, and the location preview said
# once per opening, its description first and then each exit after the direction its icon shows.
class ArckyPreviewGdTest < PokeAccessTest
  Arcky = PokeAccess::ArckyRegionMap
  MODES = { :normal => { :text => "Normal" }, :fly => { :text => "Vuelo" } }

  # The plugin's PreviewState, as far as the reader asks it.
  PreviewBox = Struct.new(:state) do
    def isHidden; state == :hidden; end
  end

  test "says the mode the corner paints, without interrupting" do
    Arcky.mode(map_scene, ["[Z] Cambiar", "Vuelo"])
    assert_equal [[mode_line("Vuelo"), false]], SpeakCapture.log
  end

  test "says a mode once while the corner keeps painting it" do
    scene = map_scene
    Arcky.mode(scene, ["[Z] Cambiar", "Vuelo"])
    Arcky.mode(scene, ["[Z] Cambiar", "Vuelo"])
    assert_equal [mode_line("Vuelo")], SpeakCapture.lines
  end

  test "says each new mode as the corner changes it" do
    scene = map_scene
    Arcky.mode(scene, ["Vuelo"])
    Arcky.mode(scene, ["Normal"])
    Arcky.mode(scene, ["Vuelo"])
    assert_equal [mode_line("Vuelo"), mode_line("Normal"), mode_line("Vuelo")], SpeakCapture.lines
  end

  test "takes the last mode name painted when the corner paints two" do
    Arcky.mode(map_scene, ["Normal", "[Z] Cambiar", "Vuelo"])
    assert_equal [mode_line("Vuelo")], SpeakCapture.lines
  end

  test "takes no button hint or other painted text for a mode" do
    Arcky.mode(map_scene, ["[Z] Cambiar", "X: Vuelo Rapido"])
    assert_nothing_spoken
  end

  test "says no mode on a map with no table of modes, whatever it paints" do
    Arcky.mode(World.stub_scene, ["X: Vuelo Rapido", "Vuelo"])
    assert_nothing_spoken
  end

  test "matches a mode painted in colour markup and says it clean" do
    scene = map_scene(:normal => { :text => "<c2=7FFF0000>Normal</c2>" })
    Arcky.mode(scene, ["<c2=7FFF0000>Normal</c2>"])
    assert_equal [mode_line("Normal")], SpeakCapture.lines
  end

  test "takes a blank painted row for no mode, even beside a mode with no text" do
    scene = map_scene(:normal => { :text => "Normal" }, :unnamed => { :text => nil })
    Arcky.mode(scene, ["Normal", ""])
    assert_equal [mode_line("Normal")], SpeakCapture.lines
  end

  test "says the built preview at once: the description, then each exit after its direction" do
    build(map_scene, "<c2=7FFF0000>Un pueblo tranquilo.", "<icon=north>Ruta 1   <icon=southWest>Lago")
    assert_equal [["Un pueblo tranquilo. #{dir(:dir_n)}: Ruta 1. #{dir(:dir_so)}: Lago.", true]], SpeakCapture.log
  end

  test "says a text the panel paints twice in one build once" do
    build(map_scene, "Un pueblo tranquilo.", "Un pueblo tranquilo.", "<icon=east>Ruta 2")
    assert_equal ["Un pueblo tranquilo. #{dir(:dir_e)}: Ruta 2."], SpeakCapture.lines
  end

  test "names each exit by the direction its icon shows" do
    { "north" => :dir_n, "northEast" => :dir_ne, "east" => :dir_e, "southEast" => :dir_se, "south" => :dir_s,
      "southWest" => :dir_so, "west" => :dir_o, "northWest" => :dir_no }.each do |icon, key|
      SpeakCapture.clear
      build(map_scene, "<icon=#{icon}>Ruta 3")
      assert_equal ["#{dir(key)}: Ruta 3."], SpeakCapture.lines, "the #{icon} icon"
    end
  end

  test "drops an icon it knows no direction for, keeping the exit's name" do
    build(map_scene, "<icon=up>Cueva")
    assert_equal ["Cueva."], SpeakCapture.lines
  end

  test "ends each text with a full stop unless it already ends a sentence" do
    { "Ruta 1" => "Ruta 1.", "Un pueblo." => "Un pueblo.", "¡Peligro!" => "¡Peligro!",
      "¿Seguro?" => "¿Seguro?" }.each do |text, said|
      SpeakCapture.clear
      build(map_scene, text)
      assert_equal [said], SpeakCapture.lines, "for #{text.inspect}"
    end
  end

  test "drops a text that is markup alone" do
    build(map_scene, "<c2=7FFF0000>", "Ruta 1")
    assert_equal ["Ruta 1."], SpeakCapture.lines
  end

  test "says nothing for a build that paints nothing" do
    build(map_scene)
    assert_nothing_spoken
  end

  test "stays silent when the open panel is rebuilt unchanged" do
    scene = map_scene
    build(scene, "Un pueblo tranquilo.", "<icon=north>Ruta 1")
    scene.instance_variable_get(:@previewBox).state = :shown
    SpeakCapture.clear
    build(scene, "Un pueblo tranquilo.", "<icon=north>Ruta 1")
    assert_nothing_spoken
  end

  test "says the new place when the open panel is rebuilt for another" do
    scene = map_scene
    build(scene, "Un pueblo tranquilo.")
    scene.instance_variable_get(:@previewBox).state = :shown
    SpeakCapture.clear
    build(scene, "Una cueva oscura.")
    assert_equal ["Una cueva oscura."], SpeakCapture.lines
  end

  test "says the preview again when the panel is opened anew on the same place" do
    scene = map_scene
    build(scene, "Un pueblo tranquilo.", "<icon=north>Ruta 1")
    SpeakCapture.clear
    build(scene, "Un pueblo tranquilo.", "<icon=north>Ruta 1")
    assert_equal ["Un pueblo tranquilo. #{dir(:dir_n)}: Ruta 1."], SpeakCapture.lines
  end

  test "takes a panel with no state for an open one, so an unchanged rebuild stays silent" do
    scene = World.stub_scene(:@modeInfo => MODES)
    build(scene, "Un pueblo tranquilo.")
    SpeakCapture.clear
    build(scene, "Un pueblo tranquilo.")
    assert_nothing_spoken
  end

  test "takes a panel whose state cannot be read for an open one, so an unchanged rebuild stays silent" do
    box = PreviewBox.new(:hidden)
    def box.isHidden; raise "no state"; end
    scene = World.stub_scene(:@modeInfo => MODES, :@previewBox => box)
    build(scene, "Un pueblo tranquilo.")
    SpeakCapture.clear
    build(scene, "Un pueblo tranquilo.")
    assert_nothing_spoken
  end

  test "ignores what the screen paints outside a preview build" do
    build(map_scene)
    Arcky.preview_note("Pulsa C para cerrar")
    build(map_scene, "Ruta 1")
    assert_equal ["Ruta 1."], SpeakCapture.lines
  end

  private

  # A map scene with the plugin's table of modes and its preview panel closed.
  def map_scene(modes = MODES)
    World.stub_scene(:@modeInfo => modes, :@previewBox => PreviewBox.new(:hidden))
  end

  # Builds the location preview on scene as the plugin paints it: each text drawn in turn.
  def build(scene, *texts)
    Arcky.preview_start(scene)
    texts.each { |text| Arcky.preview_note(text) }
    Arcky.preview_end(scene)
  end

  # What the reader says for a mode.
  def mode_line(name)
    PokeAccess::I18n.t(:arm_mode, :m => name)
  end

  # A direction's word.
  def dir(key)
    PokeAccess::I18n.t(key)
  end
end
