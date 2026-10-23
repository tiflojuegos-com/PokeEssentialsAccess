# The help line of the menus with help (pbShowCommandsWithHelp and its AndText form, Reminiscencia's
# pbShowCommandsRogue): said queued once the menu is up, once per window, only for the variant running with no message
# above it, and kept for the info key.

# The window pbShowCommandsRogue writes each option's help into, which the engine stubs lack: text= as the game's.
class Window_UnformattedTextPokemon
  def initialize(text = ""); self.text = text; end
  def text=(value); @text = value; end
end

# The mod registered that window's listener before the stand-in existed, so it bound to nothing: its registration, the
# last hook of core/menus/command_help.rb, is evaluated again (as the harness serves it) to bind it to the stand-in.
command_help = File.join(Harness::ROOT, "core", "menus", "command_help.rb")
source = Harness.source(command_help)
listener = source.index('PokeAccess::Hooks.after_hook("Window_UnformattedTextPokemon"')
eval(source[listener..-1], TOPLEVEL_BINDING, command_help, source[0, listener].count("\n") + 1)

class CommandHelpRogueTest < PokeAccessTest
  CH = PokeAccess::CommandHelp

  test "says nothing for a help window with no menu running" do
    Window_AdvancedTextPokemon.new("Hola, soy un dialogo.")
    CH.note(Object.new, :rogue, "(Qué majo, el bichete.)")
    assert_nothing_spoken
    assert_nil PokeAccess::Info.info_text, "the info key keeps nothing"
  end

  test "holds the help written as the menu opens until its second frame" do
    heard = []
    in_menu(:rogue) do
      CH.note(Object.new, :rogue, "(Qué majo, el bichete.)")
      2.times do
        CH.release
        heard.push(SpeakCapture.log.dup)
      end
    end
    assert_equal [[], [["(Qué majo, el bichete.)", false]]], heard, "after the first frame, after the second"
  end

  test "says the option before the help the menu opened with" do
    in_menu(:withhelp) do
      CH.note(Object.new, :withhelp, "Continua esta partida.")
      CH.release
      PokeAccess.speak("Continuar", false)
      CH.release
    end
    assert_equal [["Continuar", false], ["Continua esta partida.", false]], SpeakCapture.log
  end

  test "the frame pulse releases the help held as the menu opened" do
    in_menu(:withhelp) do
      CH.note(Object.new, :withhelp, "Cura a un Pokemon.")
      2.times { PokeAccess::Frame.run_pollers }
    end
    assert_equal [["Cura a un Pokemon.", false]], SpeakCapture.log.select { |text, _i| text == "Cura a un Pokemon." }
  end

  test "says each later help queued as it is written" do
    menu_up(:withhelp) { CH.note(Object.new, :withhelp, "Empieza una partida nueva.") }
    assert_equal [["Empieza una partida nueva.", false]], SpeakCapture.log
  end

  test "says nothing more on the frames after the held help was said" do
    in_menu(:withhelp) do
      CH.note(Object.new, :withhelp, "Cura a un Pokemon.")
      2.times { CH.release }
      SpeakCapture.clear
      CH.release
    end
    assert_nothing_spoken
  end

  test "never says the help of a menu closed before its second frame" do
    in_menu(:withhelp) { CH.note(Object.new, :withhelp, "Cura a un Pokemon.") }
    2.times { CH.release }
    assert_nothing_spoken
  end

  test "says a window's help again only when its text changes" do
    help = Object.new
    menu_up(:rogue) do
      ["Recupera 20 PS.", "Recupera 20 PS.", "Recupera 50 PS."].each { |t| CH.note(help, :rogue, t) }
    end
    assert_equal [["Recupera 20 PS.", false], ["Recupera 50 PS.", false]], SpeakCapture.log
  end

  test "reads the help a menu with help writes into its help window" do
    menu_up(:withhelp) { Window_AdvancedTextPokemon.new("Cura a un Pokemon.") }
    assert_equal [["Cura a un Pokemon.", false]], SpeakCapture.log
  end

  test "under the Rogue variant reads the caption its formatted window takes" do
    menu_up(:rogue) { Window_AdvancedTextPokemon.new("(Qué majo, el bichete.)") }
    assert_equal [["(Qué majo, el bichete.)", false]], SpeakCapture.log
  end

  test "under the Rogue variant reads the help its unformatted window takes" do
    menu_up(:rogue) { Window_UnformattedTextPokemon.new.text = "Recupera 20 PS." }
    assert_equal [["Recupera 20 PS.", false]], SpeakCapture.log
  end

  test "leaves an unformatted window quiet under a menu with help, keeping nothing for the info key" do
    menu_up(:withhelp) do
      Window_UnformattedTextPokemon.new.text = "Recupera 20 PS."
      assert_nil PokeAccess::Info.info_text, "the info key"
    end
    assert_nothing_spoken
  end

  test "leaves a help listener of the other variant quiet" do
    { :rogue => :withhelp, :withhelp => :rogue }.each do |running, serves|
      menu_up(running) { CH.note(Object.new, serves, "Otra cosa") }
    end
    assert_nothing_spoken
  end

  test "speaks and keeps the help cleaned of the game's text codes" do
    menu_up(:withhelp) do
      CH.note(Object.new, :withhelp, "\\c[2]Recupera <b>20</b> PS.")
      assert_equal "Recupera 20 PS.", PokeAccess::Info.info_text, "the info key"
    end
    assert_equal [["Recupera 20 PS.", false]], SpeakCapture.log
  end

  test "neither says nor keeps a help that cleans to nothing" do
    menu_up(:withhelp) do
      [nil, "", "\\c[2]"].each { |raw| CH.note(Object.new, :withhelp, raw) }
      assert_nil PokeAccess::Info.info_text, "the info key"
    end
    assert_nothing_spoken
  end

  test "leaves a message shown from inside the menu to the dialogue reader, and the info key on the help" do
    menu_up(:withhelp) do
      CH.note(Object.new, :withhelp, "Cura a un Pokemon.")
      SpeakCapture.clear
      in_message { CH.note(Object.new, :withhelp, "Juega al capitulo extra.") }
      assert_nothing_spoken
      assert_equal "Cura a un Pokemon.", PokeAccess::Info.info_text, "the info key"
    end
  end

  test "reads the help a menu opened inside a message writes into that message's window" do
    in_message { menu_up(:withhelp) { CH.note(Object.new, :withhelp, "Solo la primera generacion.") } }
    assert_equal [["Solo la primera generacion.", false]], SpeakCapture.log
  end

  test "leaves a message the menu puts up over the message it opened in to the dialogue reader" do
    in_message { menu_up(:withhelp) { in_message { CH.note(Object.new, :withhelp, "Seguro que quieres salir?") } } }
    assert_nothing_spoken
  end

  test "with menu help switched off says nothing, and the info key still answers with the help" do
    PokeAccess::Config.read_help = false
    menu_up(:withhelp) do
      CH.note(Object.new, :withhelp, "Cura a un Pokemon.")
      assert_nothing_spoken
      assert_equal "Cura a un Pokemon.", PokeAccess::Info.info_text, "the info key"
    end
  end

  test "below full verbosity says nothing, and the info key still answers with the help" do
    [:brief, :medium].each do |level|
      PokeAccess::Config.verbosity = level
      menu_up(:withhelp) do
        CH.note(Object.new, :withhelp, "Cura a un Pokemon.")
        assert_nothing_spoken "at #{level}"
        assert_equal "Cura a un Pokemon.", PokeAccess::Info.info_text, "the info key at #{level}"
      end
    end
  end

  test "drops its help from the info key when the menu closes" do
    in_menu(:withhelp) { CH.note(Object.new, :withhelp, "Cura a un Pokemon.") }
    assert_nil PokeAccess::Info.info_text
  end

  test "leaves what else took the info key when the menu closes" do
    in_menu(:withhelp) do
      CH.note(Object.new, :withhelp, "Cura a un Pokemon.")
      PokeAccess::Info.set_info(:trainer, nil)
    end
    assert_equal PokeAccess::Info.trainer_info, PokeAccess::Info.info_text
  end

  test "keeps the info key on the help while the map's frame runs under the menu, and gives it back once closed" do
    menu_up(:withhelp) do
      CH.note(Object.new, :withhelp, "Cura a un Pokemon.")
      PokeAccess::Locator.refresh_info
      assert_equal "Cura a un Pokemon.", PokeAccess::Info.info_text, "while the menu is open"
    end
    PokeAccess::Locator.refresh_info
    assert_equal PokeAccess::Info.trainer_info, PokeAccess::Info.info_text, "once it closes"
  end

  test "an inner menu closing gives the outer one its variant back and keeps its help with the info key" do
    in_menu(:withhelp) do
      2.times { CH.release }
      CH.note(Object.new, :withhelp, "Cura a un Pokemon.")
      in_menu(:rogue) { assert_equal :rogue, CH.current, "while the inner menu runs" }
      assert_equal :withhelp, CH.current, "after it closes"
      assert_equal "Cura a un Pokemon.", PokeAccess::Info.info_text, "the outer menu's help"
    end
    assert_nil CH.current, "once both have closed"
  end

  private

  # Runs the block inside a menu of the variant kind, closed afterwards whatever happens.
  def in_menu(kind)
    CH.enter(kind)
    yield
  ensure
    CH.leave
  end

  # Runs the block inside a menu of the variant kind already past its first two frames, closed afterwards.
  def menu_up(kind)
    in_menu(kind) do
      2.times { CH.release }
      yield
    end
  end

  # Runs the block under a message box, taken down afterwards.
  def in_message
    PokeAccess.message_enter
    yield
  ensure
    PokeAccess.message_leave
  end
end
