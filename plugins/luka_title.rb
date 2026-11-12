# Luka S.J.'s Modern Title Screen: splash transcriptions, then a queued prompt when a style waits for a key.
# The first and second styles can have a separate skippable intro; announce readiness after it returns.
# Constructor-only first-style forks keep their original opening prompt.
PokeAccess::Hooks.before_hook("Scene_Intro", :cyclePics, :optional => true) do |s, _args|
  PokeAccess::TitleScreen.splash(PokeAccess.ivar(s, :@pics))
end

PokeAccess::Hooks.after_hook("GenOneStyle", :initialize, :optional => true) do |s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false) unless s.respond_to?(:intro)
end

PokeAccess::Hooks.after_hook("GenOneStyle", :intro, :optional => true, :hook_container => true) do |_s, _r, _a|
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
