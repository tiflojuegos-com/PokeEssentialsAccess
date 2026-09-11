# Luka S.J.'s Modern Title Screen for gen-6 games (Scene_Intro with GenOneStyle, GenTwoStyle or
# GenCustomStyle, chosen by SCREENSTYLE), in eight of the surveyed games: splashes, then a logo and a
# blinking "press start" picture over a loop that waits for a key -- no text anywhere, so the mod's first
# word came in the load screen and nothing said the game was up and waiting. Each style builds itself in
# its constructor, right before that loop; the prompt goes there. One hook per style, written out, so the
# plugin census and the arity census see each of them.
PokeAccess::Hooks.after_hook("GenOneStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:title_press_start), true)
end

PokeAccess::Hooks.after_hook("GenTwoStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:title_press_start), true)
end

PokeAccess::Hooks.after_hook("GenCustomStyle", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:title_press_start), true)
end
