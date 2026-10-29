# The help line of the menus with help (pbShowCommandsWithHelp and its AndText form, Reminiscencia's
# pbShowCommandsRogue): said queued once the menu is up, once per window, only for the variant running with no message
# above it, and kept for the info key.

# The window pbShowCommandsRogue writes each option's help into is the engine stubs' Window_UnformattedTextPokemon,
# whose text= listener the mod bound as it loaded.
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

  test "Ctrl+T says the focused option before its help, and the info key the help alone" do
    cmds = Window_DrawableCommand.new(["Continuar", "Nueva partida"])
    menu_up(:withhelp) do
      cmds.update
      CH.note(Object.new, :withhelp, "Continua esta partida.")
      assert_equal "Continuar. Continua esta partida.", PokeAccess::Info.row_text, "Ctrl+T"
      assert_equal "Continua esta partida.", PokeAccess::Info.info_text, "the info key"
    end
  end

  test "Ctrl+T follows the option the cursor moves to" do
    cmds = Window_DrawableCommand.new(["Continuar", "Nueva partida"])
    help = Object.new
    menu_up(:withhelp) do
      cmds.update
      CH.note(help, :withhelp, "Continua esta partida.")
      cmds.index = 1
      cmds.update
      CH.note(help, :withhelp, "Empieza una partida nueva.")
      assert_equal "Nueva partida. Empieza una partida nueva.", PokeAccess::Info.row_text
    end
  end

  test "Ctrl+T follows the cursor onto an option that shares the last one's help, said once" do
    cmds = Window_DrawableCommand.new(["Pocion", "Superpocion"])
    help = Object.new
    menu_up(:withhelp) do
      cmds.update
      CH.note(help, :withhelp, "Cura a un Pokemon.")
      cmds.index = 1
      cmds.update
      CH.note(help, :withhelp, "Cura a un Pokemon.")
      assert_equal "Superpocion. Cura a un Pokemon.", PokeAccess::Info.row_text
    end
    assert_equal 1, SpeakCapture.log.count { |text, _i| text == "Cura a un Pokemon." }
  end

  test "an option with no help after one with gives Ctrl+T the option alone and the info key no stale help" do
    cmds = Window_DrawableCommand.new(["Continuar", "Salir"])
    help = Object.new
    menu_up(:withhelp) do
      cmds.update
      CH.note(help, :withhelp, "Continua esta partida.")
      cmds.index = 1
      cmds.update
      CH.note(help, :withhelp, "")
      assert_equal ["Salir", nil], [PokeAccess::Info.row_text, PokeAccess::Info.info_text]
    end
  end

  test "Ctrl+T follows the cursor across options with no help in a row, and a help said again after them" do
    cmds = Window_DrawableCommand.new(["Continuar", "Opciones", "Salir"])
    help = Object.new
    rows = []
    menu_up(:withhelp) do
      cmds.update
      CH.note(help, :withhelp, "Continua esta partida.")
      [1, 2].each do |i|
        cmds.index = i
        cmds.update
        CH.note(help, :withhelp, "")
        rows.push(PokeAccess::Info.row_text)
      end
      cmds.index = 0
      cmds.update
      CH.note(help, :withhelp, "Continua esta partida.")
    end
    assert_equal ["Opciones", "Salir"], rows
    assert_equal 2, SpeakCapture.log.count { |text, _i| text == "Continua esta partida." }
  end

  test "a help written as the menu opens gets its row once the command window first updates" do
    cmds = Window_DrawableCommand.new(["Continuar"])
    in_menu(:withhelp) do
      CH.note(Object.new, :withhelp, "Continua esta partida.")
      assert_nil PokeAccess::Info.row_text, "before the window updates"
      cmds.update
      assert_equal "Continuar. Continua esta partida.", PokeAccess::Info.row_text, "after it"
    end
  end

  test "a choice shown in a message from inside the menu does not head its row" do
    cmds = Window_DrawableCommand.new(["Continuar"])
    choice = Window_DrawableCommand.new(["Si", "No"])
    menu_up(:withhelp) do
      cmds.update
      in_message { choice.update }
      CH.note(Object.new, :withhelp, "Continua esta partida.")
      assert_equal "Continuar. Continua esta partida.", PokeAccess::Info.row_text
    end
  end

  test "the row leaves Ctrl+T when the menu closes" do
    cmds = Window_DrawableCommand.new(["Continuar"])
    menu_up(:withhelp) do
      cmds.update
      CH.note(Object.new, :withhelp, "Continua esta partida.")
      assert_equal "Continuar. Continua esta partida.", PokeAccess::Info.row_text, "while the menu is open"
    end
    assert_nil PokeAccess::Info.row_text, "once it closes"
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
