# The opening's controls help (ButtonEventScene): four screens explaining the keys, and not one of them
# reached the player. Its paragraphs never touch a window -- addLabelForScreen compiles each one straight
# into a bitmap -- so there is nothing for a window reader to find; they are collected as the scene
# registers them and read when the screen they belong to is put up.
#
# The class is vanilla Essentials and has the same two signatures in ten of the surveyed games, eight
# paragraphs each in seven of them, which is why the reader is core. It lived in one profile for a while,
# and that left four screens unread in six other games.
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

  # The tenth game registers a single label -- its help is one image -- so the reader has one paragraph to
  # say instead of eight, which is still one more than silence.
  other = ButtonEventScene.new
  other.addLabelForScreen(0, 0, 0, 400, "Consulta el manual.")
  SpeakCapture.clear
  other.set_up_screen(0)
  eq "a screen with a single paragraph reads it", SpeakCapture.lines, ["Consulta el manual."]

  # A paragraph that does NOT end in punctuation still gets a stop, or it would run into the next.
  third = ButtonEventScene.new
  third.addLabelForScreen(0, 0, 0, 400, "Pulsa C")
  third.addLabelForScreen(0, 0, 30, 400, "para hablar")
  SpeakCapture.clear
  third.set_up_screen(0)
  eq "and one without a stop of its own is given one", SpeakCapture.lines, ["Pulsa C. para hablar"]
end
