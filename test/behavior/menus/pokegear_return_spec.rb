# The RMXP-style Pokegear (Scene_Pokegear, gen-6) opens its map, phone and quest log in place and reselects the same
# button every frame after: back from one of them the focused button is said again, as the reworked Pokegear's is.
Suite.define("pokegear: back on an RMXP-style Scene_Pokegear from an app it opened in place, the button is said again") do
  made = !Object.const_defined?(:Scene_Pokegear)
  Object.const_set(:Scene_Pokegear, Class.new) if made
  had = $scene
  ui = PokeAccess::UIV21
  back = lambda do
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.leave!
  end
  begin
    $scene = Scene_Pokegear.new
    ui.reset(:pokegear)
    SpeakCapture.clear
    ui.speak_changed(:pokegear, "Quest Log")
    ui.speak_changed(:pokegear, "Quest Log")
    eq "the focused button is said once while the cursor stays", SpeakCapture.lines, ["Quest Log"]
    SpeakCapture.clear
    back.call
    ui.speak_changed(:pokegear, "Quest Log")
    eq "back from the app, once more", SpeakCapture.lines, ["Quest Log"]
    SpeakCapture.clear
    $scene = Object.new
    back.call
    ui.speak_changed(:pokegear, "Quest Log")
    eq "a return anywhere else leaves the Pokegear's button alone", SpeakCapture.lines, []
  ensure
    $scene = had
    Object.send(:remove_const, :Scene_Pokegear) if made
    ui.reset(:pokegear)
  end
end
