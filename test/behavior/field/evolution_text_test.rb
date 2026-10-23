# EvolutionText (core/field/evolution_text.rb): while the evolution scene runs, a line written straight into its box
# outside a message is said once, queued; one the dialogue reader already said is not repeated. The file is evaluated
# again over a stand-in of the game's scene so its hook binds.
class PokemonEvolutionScene
  # The evolution's loop cut down to its frames: each entry of @frames is run on the scene, then the frame's pollers.
  def pbEvolution(_can_cancel = true)
    (@frames || []).each do |step|
      step.call(self)
      PokeAccess::Frame.run_pollers
    end
    :evolved
  end
end

path = File.join(Harness::ROOT, "core", "field", "evolution_text.rb")
eval(Harness.source(path), TOPLEVEL_BINDING, path)

class EvolutionTextTest < PokeAccessTest
  Text = PokeAccess::EvolutionText
  Box = Struct.new(:text)

  test "says the line written straight into the box, queued" do
    box = Box.new("¡Pikachu está evolucionando!")
    evolving(box) { Text.poll }
    assert_equal [["¡Pikachu está evolucionando!", false]], SpeakCapture.log
  end

  test "says a line once while it stays in the box" do
    box = Box.new("¡Pikachu está evolucionando!")
    evolving(box) { 3.times { Text.poll } }
    assert_equal ["¡Pikachu está evolucionando!"], SpeakCapture.lines
  end

  test "a line the dialogue reader already said is not said again" do
    box = Box.new("")
    evolving(box) do
      PokeAccess.say_dialogue("¡Anda!")
      SpeakCapture.clear
      box.text = "¡Anda!"
      Text.poll
    end
    assert_nothing_spoken
  end

  test "says nothing while a message is being shown, which the dialogue reader has" do
    box = Box.new("")
    evolving(box) do
      PokeAccess.message_enter
      box.text = "¡Enhorabuena!"
      Text.poll
    end
    assert_nothing_spoken
  ensure
    PokeAccess.message_leave
  end

  test "an evolution that opens inside a message still reads its box" do
    PokeAccess.message_enter
    evolving(Box.new("¡Pikachu está evolucionando!")) { Text.poll }
    assert_equal ["¡Pikachu está evolucionando!"], SpeakCapture.lines
  ensure
    PokeAccess.message_leave
  end

  test "a new evolution says its box's line even when the last one ended on the same line" do
    2.times { evolving(Box.new("¡Pikachu está evolucionando!")) { Text.poll } }
    assert_equal ["¡Pikachu está evolucionando!"] * 2, SpeakCapture.lines
  end

  test "an empty box, or a scene with no box, says nothing" do
    evolving(Box.new("   ")) { Text.poll }
    scene = World.stub_scene(:@sprites => {})
    Text.open(scene)
    Text.poll
    Text.close
    assert_nothing_spoken
  end

  test "nothing is watched once the scene has closed" do
    box = Box.new("")
    evolving(box) { Text.poll }
    box.text = "Otra cosa"
    Text.poll
    assert_nothing_spoken
  end

  test "the box is read while the game's evolution runs, and the evolution's result is kept" do
    scene = PokemonEvolutionScene.new
    box = Box.new("")
    scene.instance_variable_set(:@sprites, { "msgwindow" => box })
    scene.instance_variable_set(:@frames, [lambda { |_s| box.text = "¡Pikachu está evolucionando!" }])
    assert_equal :evolved, scene.pbEvolution
    box.text = "¡Ya no evoluciona!"
    PokeAccess::Frame.run_pollers
    assert_equal ["¡Pikachu está evolucionando!"], SpeakCapture.lines, "said while it ran, nothing after"
  end

  private

  # Runs the block with an evolution scene showing box open, closed after.
  def evolving(box)
    Text.open(World.stub_scene(:@sprites => { "msgwindow" => box }))
    yield
  ensure
    Text.close
  end
end
