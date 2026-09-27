# The v22 in-screen messages: show_message and its three siblings, inherited from UI::BaseScreen, are read by one set
# of hooks; an empty message is the screen clearing its box, and says nothing.
Suite.define("v22 screens: the dialogue every screen inherits is read, whichever of the four it uses") do
  truthy "the engine reports the v22 UI rework, which is what gates these hooks",
         PokeAccess::Engine.has?("UI::BaseScreen")

  screen = Class.new(UI::BaseScreen).new
  [[:show_message, "Un mensaje normal"],
   [:show_confirm_message, "Seguro que quieres?"],
   [:show_confirm_serious_message, "Esto no se puede deshacer"],
   [:show_choice_message, "Elige una opcion"]].each do |meth, text|
    SpeakCapture.clear
    eq "#{meth} still returns what the screen returns", screen.send(meth, text), text
    spoke "#{meth} is read out", /#{Regexp.escape(text)}/
  end

  SpeakCapture.clear
  screen.show_message("")
  silent "an empty message is not announced"
end
