# EvolutionText: a line written straight into the evolution scene's box outside a message is said once, queued; one
# the dialogue reader already said is not repeated.
Suite.define("evolution: the line written straight into the box is said, and nothing twice") do
  ev = PokeAccess::EvolutionText
  box = Struct.new(:text).new("")
  scene = World.stub_scene(:@sprites => { "msgwindow" => box })
  ev.open(scene)
  begin
    PokeAccess.say_dialogue("¡Anda!")
    box.text = "¡Anda!"
    SpeakCapture.clear
    ev.poll
    silent "the line the dialogue reader said is not said again"
    box.text = "¡Pikachu está evolucionando!"
    ev.poll
    eq "the line written straight into the box is said", SpeakCapture.lines, ["¡Pikachu está evolucionando!"]
    eq "queued", SpeakCapture.log.last[1], false
    SpeakCapture.clear
    ev.poll
    silent "once"
    PokeAccess.message_enter
    box.text = "¡Enhorabuena!"
    ev.poll
    silent "and nothing while a message is being shown, which the dialogue reader has"
    PokeAccess.message_leave
  ensure
    ev.close
  end
  box.text = "Otra cosa"
  SpeakCapture.clear
  ev.poll
  silent "with the scene closed nothing is watched"
end
