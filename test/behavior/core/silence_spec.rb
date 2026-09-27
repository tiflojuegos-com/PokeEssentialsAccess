# The silence watch: a screen silent for Silence::WINDOW frames is named in the diagnostic, once and capped at MAX;
# one that spoke is not.
Suite.define("silence: a screen that says nothing gets named, one that speaks does not") do
  sil = PokeAccess::Silence
  frames = PokeAccess::Silence::WINDOW

  sil.reset
  PokeAccess::Hooks.note_screen("QuietScene")
  (frames + 2).times { sil.tick }
  truthy "a screen silent for the whole window is recorded",
         sil.quiet.any? { |q| q =~ /\AQuietScene@/ }

  sil.reset
  PokeAccess::Hooks.note_screen("TalkingScene")
  sil.tick
  PokeAccess.speak("something", true)
  (frames + 2).times { sil.tick }
  eq "a screen that spoke inside the window is not", sil.quiet, []

  sil.reset
  1.upto(PokeAccess::Silence::MAX + 5) do |n|
    PokeAccess::Hooks.note_screen("Scene#{n}")
    (frames + 2).times { sil.tick }
  end
  eq "and the list is capped", sil.quiet.length, PokeAccess::Silence::MAX

  sil.reset
  PokeAccess::Hooks.note_screen("SameScene")
  2.times { (frames + 2).times { sil.tick } }
  eq "the same screen is named once", sil.quiet.length, 1

  sil.reset
end
