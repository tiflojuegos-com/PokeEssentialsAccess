# Rejuvenation 14's options window and CyberNav: the options window moves its cursor in its own update, which never
# reaches Window_DrawableCommand's, and the CyberNav's buttons keep their painted name in @displayname, not in name.
class Rejuv14MenusGdTest < PokeAccessTest
  # A CyberNav button: name is declared and never set; the painted word is @displayname.
  class DisplaynameButton < PokegearButton
    def initialize(word); @displayname = word; @selected = false; end
  end

  test "an options window whose own update moves the cursor says each row it lands on, the closing row included" do
    win = options_window
    win.index = 1
    SpeakCapture.clear
    win.update
    win.index = 2
    win.update
    assert_equal ["Battle Scene: On", "Back"], SpeakCapture.lines
  end

  test "an options window that reaches the base update says its row once" do
    win = options_window
    win.own_update = false
    win.index = 1
    SpeakCapture.clear
    win.update
    assert_equal ["Battle Scene: On"], SpeakCapture.lines
  end

  test "left and right on an own-update window say the new value" do
    win = options_window
    win.index = 1
    win.update
    SpeakCapture.clear
    win[1] = 1
    win.update
    assert_equal ["Off"], SpeakCapture.lines
  end

  test "a CyberNav button with no name says the name it paints" do
    PokeAccess::UIV21.reset(:pokegear)
    SpeakCapture.clear
    buttons = ["Map", "Jukebox"].map { |w| DisplaynameButton.new(w) }
    buttons[0].selected = true
    buttons[1].selected = false
    buttons[0].selected = false
    buttons[1].selected = true
    assert_equal ["Map", "Jukebox"], SpeakCapture.lines
  end

  private

  # Rejuvenation 14's list: a section header, an option and the closing row, as plain strings around the option.
  def options_window
    win = Window_PokemonOption.new(["Battle", EnumOption.new("Battle Scene", ["On", "Off"]), "Back"], "Close")
    win.own_update = true
    win.active = true
    win
  end
end
