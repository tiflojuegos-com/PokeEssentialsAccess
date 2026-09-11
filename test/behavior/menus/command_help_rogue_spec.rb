# The Rogue variant of the command menu with help (Reminiscencia's pbShowCommandsRogue): its per-option
# help goes to an Unformatted window and its CAPTION -- the protagonist's aside, set once at open -- to an
# AdvancedText window. The caption was silenced on purpose, taken for decoration; it is seventy-odd lines
# of prose that appear nowhere else, so under :rogue the AdvancedText listener serves that variant too.
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
    spoke "the caption is read once the Rogue menu is up", /bichete/
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
