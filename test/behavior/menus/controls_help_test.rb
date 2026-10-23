# The gen-6 controls help (ButtonEventScene, one screen its constructor builds; controls_help_gd_test.rb covers the
# modern one): its paragraphs are said as one line once the constructor finishes, each led by the key its picture shows.
class ControlsHelpTest < PokeAccessTest
  PICTURES = "Graphics/Pictures/"

  test "says every paragraph in order, as one line, interrupting, once the screen is built" do
    ButtonEventScene.new(["ALT - Turbo", "F - Textlog", "V - Saltar diálogos"])
    assert_equal [["ALT - Turbo. F - Textlog. V - Saltar diálogos", true]], SpeakCapture.log
  end

  test "says nothing for a screen with no paragraph" do
    ButtonEventScene.new([])
    assert_nothing_spoken
  end

  test "leads each paragraph with the key its picture shows beside it" do
    labels = [["Moves the main character.", 26], ["Used to confirm a choice.", 106], ["Used to exit.", 186],
              ["Hold down while walking to run.", 266], ["Press to use a registered Key Item.", 314]]
    pictures = [[36, "#{PICTURES}helpArrowKeys"], [118, "#{PICTURES}helpCkey"], [198, "#{PICTURES}helpXkey"],
                [260, "#{PICTURES}helpZkey"], [308, "#{PICTURES}helpF5key"]]
    ButtonEventScene.new(labels, pictures)
    want = "#{PokeAccess::I18n.t(:ctl_arrows)}: Moves the main character. C: Used to confirm a choice. " \
           "X: Used to exit. Z: Hold down while walking to run. F5: Press to use a registered Key Item."
    assert_equal [[want, true]], SpeakCapture.log
  end

  test "gives a key picture to the paragraph drawn nearest its height" do
    ButtonEventScene.new([["Confirma.", 20], ["Sale.", 100]],
                         [[96, "#{PICTURES}helpXkey"], [24, "#{PICTURES}helpCkey"]])
    assert_equal [["C: Confirma. X: Sale.", true]], SpeakCapture.log
  end

  test "leaves a paragraph to the first of two pictures nearest it" do
    ButtonEventScene.new([["Confirma.", 26]], [[26, "#{PICTURES}helpCkey"], [30, "#{PICTURES}helpXkey"]])
    assert_equal [["C: Confirma.", true]], SpeakCapture.log
  end

  test "gives no key to a paragraph drawn at no height" do
    assert_equal ["Sin altura.", "C: Con altura."],
                 PokeAccess::ControlsHelp.keyed([["Sin altura.", nil], ["Con altura.", 30]], [[0, "C"]])
  end

  test "says a button the player moved on its new key, and a key no button stands for as painted" do
    PokeAccess::Config.rebinds = { :c => 0x56 }
    ButtonEventScene.new([["Confirma.", 26], ["Registrado.", 106]],
                         [[30, "#{PICTURES}helpCkey"], [110, "#{PICTURES}helpF5key"]])
    assert_equal [["V: Confirma. F5: Registrado.", true]], SpeakCapture.log
  end

  test "names the key each help picture shows, whatever the case of its file name" do
    { "helpArrowKeys" => PokeAccess::I18n.t(:ctl_arrows), "HELPARROWKEYS" => PokeAccess::I18n.t(:ctl_arrows),
      "helpCkey" => "C", "helpckey" => "C", "helpFkey" => "F", "helpF5key" => "F5" }.each do |file, want|
      assert_equal want, PokeAccess::ControlsHelp.picture_key("#{PICTURES}#{file}"), "for #{file}"
    end
  end

  test "names no key for a picture that shows none" do
    ["helpbg", "helpkey", "helpCkeys"].each do |file|
      assert_nil PokeAccess::ControlsHelp.picture_key("#{PICTURES}#{file}"), "for #{file}"
    end
  end

  test "joins two paragraphs with a full stop only where the first lacks end punctuation" do
    ButtonEventScene.new(["Pulsa C", "para hablar.", "Atención:", "mira", "¡Listo!", "Vamos;", "sigue", "¿Ya?", "fin"])
    assert_equal [["Pulsa C. para hablar. Atención: mira. ¡Listo! Vamos; sigue. ¿Ya? fin", true]], SpeakCapture.log
  end

  test "passes over a blank paragraph" do
    ButtonEventScene.new(["Pulsa C", "   ", "para hablar"])
    assert_equal [["Pulsa C. para hablar", true]], SpeakCapture.log
  end

  test "says the paragraphs without the game's text codes" do
    ButtonEventScene.new(["<b>F1</b> abre la configuración.", "\\c[2]F8 hace una captura."])
    assert_equal [["F1 abre la configuración. F8 hace una captura.", true]], SpeakCapture.log
  end

  test "reports none of its hooks missing on a copy that lacks the modern screen's methods" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\AButtonEventScene#/)
  end
end
