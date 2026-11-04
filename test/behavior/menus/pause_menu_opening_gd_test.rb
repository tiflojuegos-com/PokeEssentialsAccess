# The real pause loop updates its command window before the first Input pulse.
# The generic window reader must not race its dedicated scene watcher.
class IFPauseOpeningStandIn
  def initialize(window = Window_DrawableCommand.new(["Bag", "Save"]))
    @sprites = {"cmdwindow" => window}
  end

  def pbShowCommands(rows)
    window = @sprites["cmdwindow"]
    return :closed unless window
    rows.each do |index|
      window.index = index
      window.update
      2.times { PokeAccess::Frame.run_pollers }
    end
    :closed
  end
end

# Bind the production reader to an isolated loop class, preserving the actual
# generic command-window hook and avoiding changes to the shared engine stub.
opening_source = Harness.source(File.join(Harness::ROOT, "core", "menus", "v21", "pausemenu_v21.rb"))
opening_source = opening_source.gsub('"PokemonPauseMenu_Scene"', '"IFPauseOpeningStandIn"')
opening_source = opening_source.sub('PauseMenuV21 =', 'IFPauseOpeningReader =')
eval(opening_source, TOPLEVEL_BINDING, "pause_menu_opening_fixture")

class PauseMenuOpeningGdTest < PokeAccessTest
  def teardown
    PokeAccess::IFPauseOpeningReader.unwatch
    super
  end

  test "the opening row is spoken once when the window updates before the poller" do
    scene = IFPauseOpeningStandIn.new
    assert_equal :closed, scene.pbShowCommands([0, 0])
    assert_equal [["Bag", false]], SpeakCapture.log
  end

  test "each real cursor move is still spoken once and interrupts" do
    IFPauseOpeningStandIn.new.pbShowCommands([0, 1, 1, 0])
    assert_equal [["Bag", false], ["Save", true], ["Bag", true]], SpeakCapture.log
  end

  test "reopening the same menu on the same row announces it again" do
    scene = IFPauseOpeningStandIn.new
    scene.pbShowCommands([0])
    SpeakCapture.clear
    scene.pbShowCommands([0])
    assert_equal [["Bag", false]], SpeakCapture.log
  end

  test "a missing window is harmless and an unrelated window keeps its reader" do
    assert_equal :closed, IFPauseOpeningStandIn.new(nil).pbShowCommands([0])
    assert_nothing_spoken
    Window_DrawableCommand.new(["Bag"]).update
    assert_equal [["Bag", false]], SpeakCapture.log
  end
end
