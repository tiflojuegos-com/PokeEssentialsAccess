module PokeAccess
  # Anil's new-game menus are event pictures; the focused option shows a "...Sel" picture, named after what its
  # confirmation sets (MenuCompSel switch 110 "Modo Completo", MenuRandSel switch 111 "Modo Radical").
end

# The new-game character slider, the look-detail picture (three portraits over the Left, Middle and Right choice) and
# the "Modo Juego" mode menu, named by picture; the slider's third portrait, Yellow, is said by name in every language.
PokeAccess::Game.define("anil") do
  picture_texts(
    "introGirl" => :ap_girl,
    "introBoy" => :ap_boy,
    "introYellow" => "Yellow",
    "introGirlRaza" => :anil_looks_girl,
    "introBoyRaza" => :anil_looks_boy,
    "MenuClasSel" => :ev_mode_classic,
    "MenuCompSel" => :ev_mode_complete,
    "MenuRandSel" => :ev_mode_radical
  )
end

# The opening's controls screen, one picture with the whole list: its transcribed text (anil_controls) is said when
# the screen is set up, unless the scene registered paragraphs of its own.
PokeAccess::Game.define("anil") do
  after("ButtonEventScene", :set_up_screen, :optional => true) do |scene, _r, _a|
    labels = PokeAccess.ivar(scene, :@access_labels)
    PokeAccess.speak(PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:anil_controls)), true) if labels.nil? || labels.empty?
  end
end
