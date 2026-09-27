# Reminiscencia's help and caption windows are its own class, Window_AdvancedTextPokemonCentro: its listener serves
# the plain menu's help and the Rogue menu's caption; outside both menus the class is dialogue.
class Window_AdvancedTextPokemonCentro
  def text=(value); @text = value; end
end
require File.expand_path("../../../games/reminiscencia/command_help", File.dirname(__FILE__))

Suite.define("reminiscencia command help: its own window class serves the variant that is running") do
  ch = PokeAccess::CommandHelp
  ch.enter(:withhelp)
  begin
    Window_AdvancedTextPokemonCentro.new.text = "Vuelve atras."
    2.times { ch.release }
    spoke "the plain menu's help is read", /Vuelve atras/
  ensure
    ch.leave
  end
  ch.enter(:rogue)
  begin
    SpeakCapture.clear
    Window_AdvancedTextPokemonCentro.new.text = "(Que majo, el bichete.)"
    2.times { ch.release }
    spoke "and the Rogue menu's caption as well", /bichete/
  ensure
    ch.leave
  end
  SpeakCapture.clear
  Window_AdvancedTextPokemonCentro.new.text = "Hola."
  silent "outside both menus the class is dialogue, and stays with the dialogue reader"
end
