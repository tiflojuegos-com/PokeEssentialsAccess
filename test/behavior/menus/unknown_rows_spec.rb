# A command row painted as nothing but question marks (Desolation's quest log and field list, before a quest or a field
# is found) is said as the word for unknown, which a screen reader would leave unsaid; any other row is untouched.
Suite.define("command windows: a row of question marks is said as unknown") do
  unknown = PokeAccess::I18n.t(:pdx_unknown_short)
  win = Window_DrawableCommand.new(["???", "Back"])
  SpeakCapture.clear
  win.update
  eq "the row of marks is the word", SpeakCapture.lines, [unknown]
  SpeakCapture.clear
  win.index = 1
  win.update
  eq "a named row as painted", SpeakCapture.lines, ["Back"]
  m = PokeAccess::Menus
  eq "marks with spaces around them too", m.unknown_row("  ??? "), unknown
  eq "a lone mark stays", m.unknown_row("?"), "?"
  eq "marks inside a name stay", m.unknown_row("Who? ???"), "Who? ???"
  eq "anything else passes untouched", m.unknown_row(nil), nil
end
