# Reminiscencia's pbShowCommandsRogue: the per-option help (an Unformatted window) and, under :rogue, the caption set
# once at open (an AdvancedText window), read once the menu is up.
Suite.define("command help: under the Rogue variant the caption window is read, and plain dialogue is not") do
  ch = PokeAccess::CommandHelp
  caption = Object.new
  help = Object.new

  SpeakCapture.clear
  ch.note(caption, :rogue, "(Qué majo, el bichete.)")
  silent "outside any variant a caption window is plain dialogue, and stays with the dialogue reader"

  ch.enter(:rogue)
  begin
    SpeakCapture.clear
    ch.note(caption, :rogue, "(Qué majo, el bichete.)")
    silent "written on the way in, it waits for the menu's first option"
    2.times { ch.release }
    spoke "and is read once the Rogue menu is up", /bichete/
    SpeakCapture.clear
    ch.note(caption, :rogue, "(Qué majo, el bichete.)")
    silent "and not again for the same window"
    SpeakCapture.clear
    ch.note(help, :rogue, "Recupera 20 PS.")
    spoke "while the help window keeps reading each option", /20 PS/
    SpeakCapture.clear
    ch.note(help, :withhelp, "Otra cosa")
    silent "a listener serving the other variant stays quiet"
  ensure
    ch.leave
  end
end

# The first help, written before the loop reads its option, is held to follow it; a message the menu puts up from
# inside (a window of the same class) is the dialogue reader's alone.
Suite.define("command help: the first help follows its option, and a message inside the menu is said once") do
  ch = PokeAccess::CommandHelp
  help = Object.new
  box = Object.new
  ch.enter(:withhelp)
  begin
    SpeakCapture.clear
    ch.note(help, :withhelp, "Continua esta partida.")
    ch.release
    PokeAccess.speak("Continuar", false)
    ch.release
    eq "the option, then the help it opened with", SpeakCapture.lines, ["Continuar", "Continua esta partida."]
    SpeakCapture.clear
    ch.note(help, :withhelp, "Empieza una partida nueva.")
    eq "after that each help is said as it is written", SpeakCapture.lines, ["Empieza una partida nueva."]
    SpeakCapture.clear
    PokeAccess.message_enter
    begin
      ch.note(box, :withhelp, "Juega al capitulo extra.")
    ensure
      PokeAccess.message_leave
    end
    silent "a message shown from inside the menu is left to the dialogue reader"
  ensure
    ch.leave
  end
end

# A menu with help opened inside a message (pbMessageWithHelp, the ability changers) reads the help it writes into the
# message's window; a message it puts up on top of itself is not read.
Suite.define("command help: a menu opened inside a message reads its help, and not a message on top of it") do
  ch = PokeAccess::CommandHelp
  box = Object.new
  inner = Object.new
  PokeAccess.message_enter
  begin
    ch.enter(:withhelp)
    begin
      2.times { ch.release }
      SpeakCapture.clear
      ch.note(box, :withhelp, "Solo la primera generacion.")
      spoke "a help line written into the message's own window is read", /primera generacion/
      SpeakCapture.clear
      PokeAccess.message_enter
      begin
        ch.note(inner, :withhelp, "Seguro que quieres salir?")
      ensure
        PokeAccess.message_leave
      end
      silent "a message the menu puts up on top of itself is the dialogue reader's"
    ensure
      ch.leave
    end
  ensure
    PokeAccess.message_leave
  end
end

# The menu-help setting silences the reading, as its help text says, and never the info key: switched off, the
# help of the focused option is still what the key answers with.
Suite.define("command help: with menu help switched off the help is not read, and the info key still has it") do
  ch = PokeAccess::CommandHelp
  help = Object.new
  was = PokeAccess::Config.read_help
  ch.enter(:withhelp)
  begin
    PokeAccess::Config.read_help = false
    2.times { ch.release }
    SpeakCapture.clear
    ch.note(help, :withhelp, "Cura a un Pokemon.")
    silent "switched off, nothing is read"
    eq "and the info key answers with it", PokeAccess::Info.info_text, "Cura a un Pokemon."
  ensure
    PokeAccess::Config.read_help = was
    ch.leave
  end
end

# The help is one of the descriptions the verbosity leaves to full: below it the help is not read, and the info key
# still answers with it.
Suite.define("command help: with descriptions left out the help is not read, and the info key still has it") do
  ch = PokeAccess::CommandHelp
  help = Object.new
  ch.enter(:withhelp)
  begin
    PokeAccess::Config.verbosity = :medium
    2.times { ch.release }
    SpeakCapture.clear
    ch.note(help, :withhelp, "Cura a un Pokemon.")
    silent "in medium, nothing is read"
    eq "and the info key answers with it", PokeAccess::Info.info_text, "Cura a un Pokemon."
  ensure
    PokeAccess::Config.verbosity = :full
    ch.leave
  end
end

# A menu with help over the map updates the map after each help; the info key keeps the help while the menu is open.
Suite.define("command help: the map's frame does not take the info key from a menu with help") do
  ch = PokeAccess::CommandHelp
  help = Object.new
  ch.enter(:withhelp)
  begin
    2.times { ch.release }
    ch.note(help, :withhelp, "Cura a un Pokemon.")
    PokeAccess::Locator.refresh_info
    eq "the help stays the key's answer while the menu is open", PokeAccess::Info.info_text, "Cura a un Pokemon."
  ensure
    ch.leave
  end
  PokeAccess::Locator.refresh_info
  eq "and once it closes, the map gives it the trainer back", PokeAccess::Info.instance_variable_get(:@kind), :trainer
end
