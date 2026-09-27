# The gen-6 splash (IntroEventScene#openSplash, v16 to v18 and Reborn's lineage): once it has faded in to wait for the
# confirm key, the prompt is queued behind what the opening cards still say. Quiet when the scene is gone: a copy that
# takes the key during the fade (Desolation's) runs the load screen inside this call.
PokeAccess::Hooks.after_hook("IntroEventScene", :openSplash, :optional => true, :hook_container => true) do |s, _r, _a|
  PokeAccess.speak(PokeAccess::TitleScreen.prompt, false) unless (s.disposed? rescue false)
end
