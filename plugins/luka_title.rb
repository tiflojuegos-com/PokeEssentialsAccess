# Luka S.J.'s Modern Title Screen (gen-6): the splash images cyclePics shows, by the profile's transcription, then
# the prompt each style's constructor says, queued behind that transcription, before its wait for a key (one hook per
# style, for the censuses).
PokeAccess::Hooks.before_hook("Scene_Intro", :cyclePics, :optional => true) do |s, _args|
  PokeAccess::TitleScreen.splash(PokeAccess.ivar(s, :@pics))
end

PokeAccess::Hooks.after_hook("GenOneStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
end

PokeAccess::Hooks.after_hook("GenTwoStyle", :initialize, :optional => true) do |_s, _r, _a|
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
