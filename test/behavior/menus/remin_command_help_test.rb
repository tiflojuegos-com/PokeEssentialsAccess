# Reminiscencia's help and caption windows are its own class, Window_AdvancedTextPokemonCentro
# (games/reminiscencia/command_help.rb): what it is given serves the plain menu's help and the Rogue menu's caption;
# outside both menus the class is dialogue, left to the dialogue reader.
class Window_AdvancedTextPokemonCentro
  def text=(value); @text = value; end
end
command_help_path = File.join(Harness::ROOT, "games", "reminiscencia", "command_help.rb")
eval(Harness.source(command_help_path), TOPLEVEL_BINDING, command_help_path)

class ReminCommandHelpTest < PokeAccessTest
  test "reads the help it is given once a menu with help has opened, queued" do
    in_menu(:withhelp) do
      Window_AdvancedTextPokemonCentro.new.text = "Vuelve atras."
      assert_nothing_spoken "held while the menu opens"
      2.times { PokeAccess::CommandHelp.release }
      assert_equal [["Vuelve atras.", false]], SpeakCapture.log
    end
  end

  test "reads the caption it is given while the Rogue menu runs" do
    in_menu(:rogue) do
      Window_AdvancedTextPokemonCentro.new.text = "(Que majo, el bichete.)"
      2.times { PokeAccess::CommandHelp.release }
      assert_equal [["(Que majo, el bichete.)", false]], SpeakCapture.log
    end
  end

  test "keeps the help on the info key" do
    in_menu(:withhelp) do
      Window_AdvancedTextPokemonCentro.new.text = "Vuelve atras."
      assert_equal "Vuelve atras.", PokeAccess::Info.info_text
    end
  end

  test "leaves what it is given outside both menus to the dialogue reader" do
    Window_AdvancedTextPokemonCentro.new.text = "Hola."
    2.times { PokeAccess::CommandHelp.release }
    assert_nothing_spoken
    assert_nil PokeAccess::Info.info_text, "nor is it kept for the info key"
  end

  private

  # Runs the block inside a menu of kind (:withhelp or :rogue), as its opener marks it, and closes it after.
  def in_menu(kind)
    PokeAccess::CommandHelp.enter(kind)
    yield
  ensure
    PokeAccess::CommandHelp.leave
  end
end
