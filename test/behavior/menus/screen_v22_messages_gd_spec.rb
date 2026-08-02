# In-screen messages on the v22 UI. Every v22 screen inherits show_message and its three siblings from
# UI::BaseScreen, and one set of hooks reads them all -- but the class was missing from the stubs, so
# Engine.has?("UI::BaseScreen") was false in BOTH engines and those four hooks never registered in any test
# run. A typo in any of them was a screen whose dialogue went unread, with the suite green.
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

  # Empty text is the screen clearing its own box, not something to announce.
  SpeakCapture.clear
  screen.show_message("")
  silent "an empty message is not announced"
end
