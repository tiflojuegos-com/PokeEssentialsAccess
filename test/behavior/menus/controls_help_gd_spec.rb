# The opening's controls help (ButtonEventScene): its paragraphs go straight to bitmaps, so they are collected as
# addLabelForScreen registers them and read when set_up_screen puts their screen up.
Suite.define("controls help: each screen of the opening reads the paragraphs registered for it") do
  scene = ButtonEventScene.new
  scene.addLabelForScreen(0, 10, 10, 400, "F1 abre la configuracion.")
  scene.addLabelForScreen(0, 10, 40, 400, "F8 hace una captura.")
  scene.addLabelForScreen(1, 10, 10, 400, "Las flechas mueven al personaje.")

  SpeakCapture.clear
  scene.set_up_screen(0)
  eq "the first screen says both of its paragraphs, in the order it registered them, without doubling the stop they already carry",
     SpeakCapture.lines, ["F1 abre la configuracion. F8 hace una captura."]
  truthy "and it interrupts, because the player pressed a key to get here", SpeakCapture.log.last[1]

  SpeakCapture.clear
  scene.set_up_screen(1)
  eq "the next screen says its own, not the previous one's",
     SpeakCapture.lines, ["Las flechas mueven al personaje."]

  SpeakCapture.clear
  scene.set_up_screen(3)
  silent "a screen nobody registered a paragraph for says nothing, instead of repeating the last"

  other = ButtonEventScene.new
  other.addLabelForScreen(0, 0, 0, 400, "Consulta el manual.")
  SpeakCapture.clear
  other.set_up_screen(0)
  eq "a screen with a single paragraph reads it", SpeakCapture.lines, ["Consulta el manual."]

  third = ButtonEventScene.new
  third.addLabelForScreen(0, 0, 0, 400, "Pulsa C")
  third.addLabelForScreen(0, 0, 30, 400, "para hablar")
  SpeakCapture.clear
  third.set_up_screen(0)
  eq "and one without a stop of its own is given one", SpeakCapture.lines, ["Pulsa C. para hablar"]
end

# Anil's fork deleted the paragraphs and shows one picture with the whole list; the gamedata pass runs its
# profile, which says the picture's text when the scene registered none.
Suite.define("controls help: Anil's single picture is said when the scene registered no paragraph") do
  SpeakCapture.clear
  ButtonEventScene.new.set_up_screen(0)
  eq "the transcribed picture, interrupting", SpeakCapture.log, [[PokeAccess::I18n.t(:anil_controls), true]]
end
