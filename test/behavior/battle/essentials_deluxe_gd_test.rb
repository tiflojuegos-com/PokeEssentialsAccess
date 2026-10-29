# Essentials Deluxe's midbattle speech (plugins/essentials_deluxe.rb): while the name window over a scripted battle
# line shows, its name leads the next line said, once. The plugin's hook is evaluated again over the stand-in below so
# it binds.

# The name window as Essentials Deluxe fills it: the speaker's name (a trainer's, or the panel's own name), shown
# unless it is empty or the call hides it, as a reset of the panel does.
class Battle::Scene
  NameBox = Struct.new(:text, :visible)

  def pbUpdateNameWindow(speaker = "", visible = true, reset = false)
    @namePanelName = nil if reset
    name = speaker.is_a?(String) || speaker.nil? ? (@namePanelName || "") : (@namePanelName || speaker.name)
    @sprites ||= {}
    win = (@sprites["nameWindow"] ||= NameBox.new("", false))
    win.text = name
    win.visible = (name.empty? || !visible) ? false : true
  end
end

deluxe = File.join(Harness::ROOT, "plugins", "essentials_deluxe.rb")
eval(Harness.source(deluxe), TOPLEVEL_BINDING, deluxe)

class EssentialsDeluxeGdTest < PokeAccessTest
  Trainer = Struct.new(:name)

  test "the speaker's name leads the next scripted line, once" do
    Battle::Scene.new.pbUpdateNameWindow(Trainer.new("Brock"))
    PokeAccess.say_dialogue("¡Mis Pokémon son duros como la roca!")
    PokeAccess.say_dialogue("¡Prepárate!")
    assert_equal [["Brock: ¡Mis Pokémon son duros como la roca!", false], ["¡Prepárate!", false]], SpeakCapture.log
  ensure
    PokeAccess.before_next_line(nil)
  end

  test "a line with no speaker, or a window the call keeps hidden though it holds the name, leads nothing" do
    scene = Battle::Scene.new
    scene.pbUpdateNameWindow(Trainer.new("Brock"))
    scene.pbUpdateNameWindow(nil)
    PokeAccess.say_dialogue("¡El combate sigue!")
    scene.pbUpdateNameWindow(Trainer.new("Misty"), false)
    PokeAccess.say_dialogue("¡Cuidado!")
    assert_equal [["¡El combate sigue!", false], ["¡Cuidado!", false]], SpeakCapture.log
  ensure
    PokeAccess.before_next_line(nil)
  end
end
