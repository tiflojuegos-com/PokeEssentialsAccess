# Luka S.J.'s Modular Title Screen (ModularTitleScreen), the modern-era sibling of luka_title.rb, in three
# of the surveyed games: unskippable splashes, then a logo and a blinking "start" picture over a loop that
# waits for the use key -- no text anywhere. The screen builds itself in its constructor, right before
# that loop; the prompt goes there.
PokeAccess::Hooks.after_hook("ModularTitleScreen", :initialize, :optional => true) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:title_press_start), true)
end
