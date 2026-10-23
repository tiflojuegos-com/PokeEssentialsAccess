# Insurgence's National Dex certificate (Scene_Certificate, 026_Scene_Certificate.rb) and the Pokegear's diploma
# (Scene_Diploma, 109_PokemonDiploma.rb): the same "diploma" picture, its text only in the image, left with the
# confirm key. The transcription (ins_certificate) is said as either opens, then that key while key hints are said.
PokeAccess::Game.define("insurgence") do
  %w[Scene_Certificate Scene_Diploma].each do |cname|
    before(cname, :main) do |_s, _a|
      text = PokeAccess::I18n.t(:ins_certificate)
      if PokeAccess::Verbosity.hints?
        key = PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter))
        text = PokeAccess.sentences([text, PokeAccess::I18n.t(:title_press, :key => key)])
      end
      PokeAccess.speak(text, true)
    end
  end
end
