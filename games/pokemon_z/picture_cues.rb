# Pokemon Z picture screens: the alchemy book pages (CommonEvent 62) and the two new-game selectors
# (Map001 events), which light exactly ONE picture at a time for the highlighted option, so each lit
# picture maps to its spoken text. The difficulty screen uses the "...Sel" pictures; the nuzlocke screen
# uses the "...Claro" pictures. ASCII only (ruby 1.8.7).
PokeAccess::Game.define("pokemon_z") do
  picture_texts(
    "alquimia1" => "Pelaje Fino lo sueltan Pokemon tipo Normal. Rocio Matinal tipo Bicho. Pluma Suave tipo Volador. Mineral Extrano tipo Roca. Grava Seca tipo Tierra. Polvo Brillante tipo Electrico.",
    "alquimia2" => "Brasa Candente tipo Fuego. Agua Vital tipo Agua. Musgo Aromatico tipo Planta. Poketoxina tipo Veneno. Esquirlas Frias tipo Hielo. Fibra Elastica tipo Lucha.",
    "alquimia3" => "Fluido Onirico tipo Psiquico. Ectoplasma tipo Fantasma. Extracto Sombrio tipo Siniestro. Virutas Ferreas tipo Acero. Escama Dura tipo Dragon. Azucar Meloso tipo Hada.",
    "alquimia4" => "Madera, se obtiene cortando arboles y en cajas de suministros. Guijarro, en cuevas y lugares pedregosos. Polvo de Hueso, muy escaso, en catacumbas y profundidades.",
    "cartaBayas" => "Carta de Bayas. Baya Zreza, color rojo: cura la paralisis. Baya Aranja, color azul: cura un poco los PS. Baya Ziuela, color verde: cura todos los estados. Baya Zidra, color amarillo: cura mucho los PS. Baya Atania, color morado: cura el sueno.",
    "MenuClasSel" => "Modo Normal. Juega con la dificultad predeterminada.",
    "MenuCompSel" => "Modo Heroico. Dificultad elevada para jugadores que buscan un reto.",
    "MenuRandSel" => "Modo Facil. Dificultad reducida en los combates.",
    "MenuNormalClaro"   => "Sin Nuzlocke. Partida normal, sin reglas adicionales.",
    "MenuNuzNuzClaro"   => "Modo Nuzlocke. Los Pokemon debilitados se consideran muertos para siempre.",
    "MenuNuzAyudaClaro" => "Modo Nuzlocke con ayuda. Las reglas Nuzlocke pero con asistencia."
  )
end

# Regi legendary inscriptions (maps 289/245/303): a braille message shown as an image. Instead of speaking
# dots, the mod announces a mystery braille message, sends the braille (as unicode, U+2800 + dot mask)
# straight to any connected braille display, and copies it to the clipboard so a player without a display
# can paste it into Notepad. Values transcribed from the in-game plaques.
module PokeAccess
  module ZRegi
    # Keys are the games actual picture names: map 289's plaque is "reg1" (no "i"), maps 245/303 are
    # "regi2"/"regi3" -- the game names them inconsistently, so these match the assets exactly (verified).
    BRAILLE = {
      "reg1"  => [0x283A, 0x2801, 0x280A, 0x2807, 0x2815, 0x2817, 0x2819, 0x20, 0x2811, 0x2807, 0x20, 0x280F, 0x2817, 0x280A, 0x280D, 0x2811, 0x2817, 0x2815],
      "regi2" => [0x2807, 0x2811, 0x281D, 0x281E, 0x2811, 0x20, 0x2819, 0x2811, 0x20, 0x2807, 0x2801, 0x20, 0x2827, 0x2811, 0x2817, 0x2819, 0x2801, 0x2819],
      "regi3" => [0x280F, 0x280A, 0x2811, 0x2819, 0x2817, 0x2801, 0x20, 0x280A, 0x281D, 0x280B, 0x2811, 0x2817, 0x280A, 0x2815, 0x2817, 0x20, 0x2819, 0x2811, 0x2817, 0x2811, 0x2809, 0x2813, 0x2801]
    }
    @last = nil

    # On a regi inscription picture: pushes its braille to the display, copies it to the clipboard and
    # announces it. Deduped so the engine's same-picture re-show does not copy twice; reset() (on erase)
    # allows re-reading.
    def self.on_picture(name)
      cps = BRAILLE[name.to_s]
      return if cps.nil? || name.to_s == @last
      @last = name.to_s
      (PokeAccess.braille_codepoints(cps) rescue nil)
      ok = (PokeAccess::Clipboard.set_codepoints(cps) rescue false)
      PokeAccess.speak(PokeAccess::I18n.t(ok ? :regi_braille_copied : :regi_braille), true)
    end

    def self.reset; @last = nil; end
  end
end

PokeAccess::Game.define("pokemon_z") do
  on_picture { |name, _args| (PokeAccess::ZRegi.on_picture(name) rescue nil) }
  after("Game_Picture", :erase) { (PokeAccess::ZRegi.reset rescue nil) }
end
