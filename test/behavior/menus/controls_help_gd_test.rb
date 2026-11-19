# The opening's modern controls help (ButtonEventScene with addLabelForScreen): each screen's paragraphs are kept as the
# scene registers them and said when set_up_screen puts that screen up; Anil's profile says its single picture instead.
class ControlsHelpGdTest < PokeAccessTest
  test "says a screen's paragraphs in the order registered, joined, interrupting, when it is put up" do
    { ["Consulta el manual."] => "Consulta el manual.",
      ["F1 abre la configuracion.", "F8 hace una captura."] => "F1 abre la configuracion. F8 hace una captura.",
      ["Pulsa C", "para hablar"] => "Pulsa C. para hablar" }.each do |paragraphs, want|
      SpeakCapture.clear
      screen_with(0 => paragraphs).set_up_screen(0)
      assert_equal [[want, true]], SpeakCapture.log, "for #{paragraphs.inspect}"
    end
  end

  test "says each screen's own paragraphs, not the previous screen's" do
    scene = screen_with(0 => ["F1 abre la configuracion."], 1 => ["Las flechas mueven al personaje."])
    scene.set_up_screen(0)
    SpeakCapture.clear
    scene.set_up_screen(1)
    assert_equal [["Las flechas mueven al personaje.", true]], SpeakCapture.log
  end

  test "pairs function key pictures with labels on their own page" do
    scene = screen_with(1 => ["Key Bindings.", "Take a screenshot."], 2 => ["Use the Arrow keys."])
    scene.addImageForScreen(1, 44, 9, "Graphics/Pictures/Controls help/help_f1")
    scene.addImageForScreen(1, 44, 43, "Graphics/Pictures/Controls help/help_f8")
    scene.addImageForScreen(2, 44, 9, "Graphics/Pictures/Controls help/help_arrows")
    scene.set_up_screen(1)
    scene.set_up_screen(2)
    assert_equal [["F1: Key Bindings. F8: Take a screenshot.", true], ["Use the Arrow keys.", true]], SpeakCapture.log
  end

  test "does not repeat an explicit function key or confuse F1 with F10" do
    scene = screen_with(1 => ["Press F1 for controls.", "F10 has a different action."])
    scene.addImageForScreen(1, 44, 9, "help_f1")
    scene.addImageForScreen(1, 44, 43, "help_f1")
    scene.set_up_screen(1)
    assert_equal [["Press F1 for controls. F1: F10 has a different action.", true]], SpeakCapture.log
  end

  test "says a screen again each time it is put up" do
    scene = screen_with(0 => ["F1 abre la configuracion."])
    2.times { scene.set_up_screen(0) }
    assert_equal [["F1 abre la configuracion.", true]] * 2, SpeakCapture.log
  end

  test "says nothing for a screen no paragraph was registered for" do
    screen_with(0 => ["F1 abre la configuracion."], 1 => ["Las flechas mueven al personaje."]).set_up_screen(3)
    assert_nothing_spoken
  end

  test "says Anil's transcribed picture, interrupting, when the scene registered no paragraph" do
    ButtonEventScene.new.set_up_screen(0)
    assert_equal [[PokeAccess::I18n.t(:anil_controls), true]], SpeakCapture.log
  end

  test "names a button the player moved on its new key in Anil's transcription" do
    PokeAccess::Config.rebinds = { :c => 0x56 }
    want = PokeAccess::I18n.t(:anil_controls).sub(" C: ", " V: ")
    refute_equal PokeAccess::I18n.t(:anil_controls), want, "the transcription names the C key"
    ButtonEventScene.new.set_up_screen(0)
    assert_equal [[want, true]], SpeakCapture.log
  end

  test "reports none of its hooks missing on a copy that lacks the gen-6 screen's methods" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\AButtonEventScene#/)
  end

  private

  # A scene with the paragraphs registered for each screen number, as its constructor registers them.
  def screen_with(screens)
    scene = ButtonEventScene.new
    screens.each do |number, paragraphs|
      paragraphs.each_with_index { |text, i| scene.addLabelForScreen(number, 10, 10 + 30 * i, 400, text) }
    end
    scene
  end
end
