# Ctrl+T on a menu with help in the v19+ engines: the focused option of its command window, then the help.
class CommandHelpRowGdTest < PokeAccessTest
  CH = PokeAccess::CommandHelp

  test "Ctrl+T says the focused option of the command window before its help" do
    cmds = Window_CommandPokemon.new(["Tope de nivel", "Sin tope"])
    CH.enter(:withhelp)
    begin
      2.times { CH.release }
      cmds.index = 1
      cmds.update
      CH.note(Object.new, :withhelp, "Los Pokemon no suben de nivel.")
      assert_equal "Sin tope. Los Pokemon no suben de nivel.", PokeAccess::Info.row_text, "Ctrl+T"
      assert_equal "Los Pokemon no suben de nivel.", PokeAccess::Info.info_text, "the info key"
    ensure
      CH.leave
    end
  end
end
