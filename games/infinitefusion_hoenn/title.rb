# Hoenn's title screen (HoennIntroScreen, all pictures but its version label): Scene_Intro builds it instead of
# Kanto's GenOneStyle, so the title prompt is said as it shows its logo and its "press a key" picture.
PokeAccess::Game.define("infinitefusion_hoenn") do
  before("HoennIntroScreen", :intro) { |_s, _a| PokeAccess.speak(PokeAccess::TitleScreen.prompt, true) }
end
