# Insurgence's National Dex certificate (Scene_Certificate, 026_Scene_Certificate.rb): the "diploma" picture alone,
# its text only in the image, left with the confirm key. The transcription (ins_certificate) is said as it opens,
# then that key while key hints are said.
PokeAccess::Game.define("insurgence") do
  before("Scene_Certificate", :main) do |_s, _a|
    text = PokeAccess::I18n.t(:ins_certificate)
    if PokeAccess::Verbosity.hints?
      key = PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter))
      text = PokeAccess.sentences([text, PokeAccess::I18n.t(:title_press, :key => key)])
    end
    PokeAccess.speak(text, true)
  end
end
