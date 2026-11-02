# Perseida's title (0245_Resource_TitleScreen, Luka's script cut down to one style): the credit pictures cyclePics fades in,
# as they are written, then the prompt when GenSevenStyle's skippable intro has ended and it waits for the key.
PokeAccess::Game.define("perseida") do
  picture_texts(
    "intro1" => "Si no has descargado este juego desde el link de Pokéliberty o del blog oficial del juego " \
                "pokemonperseida.blogspot.com, puedes estar jugando una versión desactualizada. Por favor, descárgalo de la " \
                "fuente oficial para evitar errores indeseados. Juego creado por fans para fans, sin fines de lucro.",
    "intro2" => "Juego sin animo de lucro creado por: @Clara_Dragon. Juego creado por fans para fans, sin fines de lucro."
  )
  before("Scene_Intro", :cyclePics, :optional => true) do |scene, _a|
    PokeAccess::TitleScreen.splash(PokeAccess.ivar(scene, :@pics))
  end
  after("GenSevenStyle", :intro, :optional => true, :hook_container => true) do |_style, _r, _a|
    PokeAccess.speak(PokeAccess::TitleScreen.prompt, false)
  end
end
