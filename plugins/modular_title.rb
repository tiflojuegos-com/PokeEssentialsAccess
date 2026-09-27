# Luka S.J.'s Modular Title Screen, which has no text: the prompt is said as its constructor ends.
PokeAccess::Hooks.after_hook("ModularTitleScreen", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, true)
end
