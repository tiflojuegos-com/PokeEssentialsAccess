module PokeAccess
  # royal's battle move-flag legend (DBK Enhanced Battle UI "Leyenda de Iconos", IconosLeyenda_Scene, opened
  # with D on the move menu). It is a single static image with no text nodes, so it was silent. The image
  # (Graphics/Plugins/Enhanced Battle UI/iconos_leyenda.png) was transcribed and is spoken when the scene
  # opens. If royal ever changes that image, update this transcription.
  module RoyalIconLegend
    TEXT = "Leyenda de iconos de movimiento. " \
           "No puede ser bloqueado. No puede ser reflejado. Movimiento de contacto. " \
           "Más daño contra reducción. Alto índice crítico. Descongela al Pokémon. " \
           "Movimiento de sonido. Movimiento de viento. Movimiento de puños. " \
           "Movimiento de colmillos. Movimiento de bomba. Movimiento de pulso. " \
           "Movimiento de polvo. Movimiento de baile. Movimiento de corte."
  end
end

PokeAccess::Game.define("royal") do
  read_on_open("IconosLeyenda_Scene") { |_s| PokeAccess::RoyalIconLegend::TEXT }
end
