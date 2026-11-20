# Luka S.J.'s Modern Title Screen: the splash images cyclePics is handed, by the profile's transcription, then the
# prompt, queued behind that transcription, once the style's intro is over: Scene_Intro plays that skippable intro, which
# takes the first press, and only then waits for a key (one hook per style, for the censuses). A copy without cyclePics
# (Infinite Fusion's, which plays a film instead) shows no splash images.
PokeAccess::Hooks.before_hook("Scene_Intro", :cyclePics, :optional => true) do |_s, args|
  PokeAccess::TitleScreen.splash(args[0])
end

PokeAccess::Hooks.after_hook("GenOneStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenTwoStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenThreeStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenFourStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenFiveStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenSixStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenSevenStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenCustomStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end
