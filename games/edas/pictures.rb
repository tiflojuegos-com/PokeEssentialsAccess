# The pictures Edas shows with no text behind them (checked against Graphics/Titles and Graphics/Pictures): the credits
# before the title, each ending's card and logo, as they are written, and a few scenes in the mod's words. Its other
# pictures (ablack, impact, Fondo Camion, the Escena1 gradients) are backdrops.
PokeAccess::Game.define("edas") do
  picture_texts(
    "intro1" => "Si no has descargado este juego desde su link en PokéLiberty, estás jugando una versión desactualizada. " \
                "Por favor, descárgalo desde la fuente oficial. Juego creado por: @pkCaeles, @DasKyu1 y @Clara_Dragon. " \
                "Juego creado por fans para fans, sin fines de lucro.",
    "BadEndingCiencia" => "Experimento 626. Fin.",
    "BadEndingReligion" => "Su suscripción ha caducado. Fin.",
    "GoodEndingCiencia" => "I told you, it was aliens! Fin.",
    "GoodEndingReligion" => "Evangelio según Don Limpio. Fin.",
    "NormalEnding" => "Llamada y al paro. Fin.",
    "FinalCorrida" => "La gran corrida. Fin.",
    "final draculaura" => "La reina vampírica. Fin.",
    "finalbruja" => "Hola de aventuras. Fin.",
    "haremending" => "La gran corrida: versión harem. Fin.",
    "aend" => "Fin.",
    "aende" => "¿Fin?",
    "Edas" => "Pokémon Edas",
    "Código Ámbar" => "Pokémon Edas: Código Ámbar",
    "campos" => :edas_pic_fields,
    "Camión Base" => :edas_pic_truck,
    "Centefico1" => :edas_pic_scientists,
    "Draculaura1" => :edas_pic_night,
    "Dibujo Ecchi" => :edas_pic_drawing,
    "Escena1_Capa2" => :edas_pic_satellite
  )
end
