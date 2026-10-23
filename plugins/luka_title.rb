# Luka S.J.'s Modern Title Screen (gen-6): the splash images cyclePics shows, by the profile's transcription, then
# the prompt, queued behind that transcription, as each style comes to wait for a key: from its constructor, or for
# the second style once its intro is over (one hook per style, for the censuses).
PokeAccess::Hooks.before_hook("Scene_Intro", :cyclePics, :optional => true) do |s, _args|
  PokeAccess::TitleScreen.splash(PokeAccess.ivar(s, :@pics))
end

PokeAccess::Hooks.after_hook("GenOneStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

# The second style's intro is a skippable animation that takes the first press: the prompt waits for its end.
PokeAccess::Hooks.after_hook("GenTwoStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenCustomStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenThreeStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenFourStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenFiveStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenSixStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenSevenStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end
