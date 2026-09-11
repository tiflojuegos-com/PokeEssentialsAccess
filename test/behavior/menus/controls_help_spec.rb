# The gen-6 half of the controls help (its twin controls_help_gd_spec.rb covers the modern one). Seven games
# build ButtonEventScene the old way: one screen whose paragraphs go through addLabel(x, y, width, text)
# from the constructor, with no addLabelForScreen and no set_up_screen. Both core hooks were optional, so
# in those seven nothing bound, nothing landed in Hooks.missing, and the screen -- Realidea opens it from
# its first map -- said nothing at all.
Suite.define("controls help: the gen-6 screen reads its paragraphs as the constructor finishes") do
  SpeakCapture.clear
  ButtonEventScene.new(["ALT - Turbo", "F - Textlog", "V - Saltar diálogos"])
  eq "every paragraph, in order, as one line",
     SpeakCapture.lines, ["ALT - Turbo. F - Textlog. V - Saltar diálogos"]
  truthy "interrupting, because the player pressed a key to get here", SpeakCapture.log.last[1]

  SpeakCapture.clear
  ButtonEventScene.new([])
  silent "a screen with no paragraph says nothing"
end
