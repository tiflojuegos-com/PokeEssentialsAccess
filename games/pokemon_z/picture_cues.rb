# Pokemon Z picture screens: the alchemy book pages (CommonEvent 62), the berry chart and the two
# new-game selectors (Map001 events), which light exactly ONE picture at a time for the highlighted
# option. Z ships as THREE per-language builds (es 2.18, en 2.13, fr 2.12) that repaint these images, so
# every text below is a per-build transcription READ OFF that build's own PNG -- never a translation of
# the mod's -- and GameLang picks the running build's set. Two honest quirks preserved: the en build never
# localised the alchemy pages (they paint Spanish, so they carry no :en entry and GameLang falls back to :es), and each build
# words its cards differently (the fr berry chart is titled "Baies du jour" and uses other framings).
PokeAccess::Game.define("pokemon_z") do
  picture_texts_multibuild(:es,
    "alquimia1" => {
      :es => "Pelaje Fino: pueden soltarlo Pokémon de tipo Normal. Rocío Matinal: pueden soltarlo Pokémon de tipo Bicho. Pluma Suave: pueden soltarlo Pokémon de tipo Volador. Mineral Extraño: pueden soltarlo Pokémon de tipo Roca. Grava Seca: pueden soltarlo Pokémon de tipo Tierra. Polvo Brillante: pueden soltarlo Pokémon de tipo Eléctrico.",
      :fr => "Belle Fourrure : sur les Pokémon Normal. Rosée du Matin : sur les Pokémon Insecte. Plume Douce : sur les Pokémon Vol. Minerai Étrange : sur les Pokémon Roche. Gravier Sec : sur les Pokémon Sol. Poudre Brillante : sur les Pokémon Électrique."
    },
    "alquimia2" => {
      :es => "Brasa Candente: pueden soltarlo Pokémon de tipo Fuego. Agua Vital: pueden soltarlo Pokémon de tipo Agua. Musgo Aromático: pueden soltarlo Pokémon de tipo Planta. Pokétoxina: pueden soltarlo Pokémon de tipo Veneno. Esquirlas Frías: pueden soltarlo Pokémon de tipo Hielo. Fibra Elástica: pueden soltarlo Pokémon de tipo Lucha.",
      :fr => "Braise : sur les Pokémon Feu. Eau : sur les Pokémon Eau. Mousse Suave : sur les Pokémon Plante. Pokétoxines : sur les Pokémon Poison. Glaçons : sur les Pokémon Glace. Fibre Élastique : sur les Pokémon Combat."
    },
    "alquimia3" => {
      :es => "Fluido Onírico: pueden soltarlo Pokémon de tipo Psíquico. Ectoplasma: pueden soltarlo Pokémon de tipo Fantasma. Extracto Sombrío: pueden soltarlo Pokémon de tipo Siniestro. Virutas Férreas: pueden soltarlo Pokémon de tipo Acero. Escama Dura: pueden soltarlo Pokémon de tipo Dragón. Azúcar Meloso: pueden soltarlo Pokémon de tipo Hada.",
      :fr => "Fluide Onirique : sur les Pokémon Psy. Ectoplasme : sur les Pokémon Spectre. Matière Sinistre : sur les Pokémon Ténèbres. Copeaux de Fer : sur les Pokémon Acier. Écaille Draconique : sur les Pokémon Dragon. Sucre Féerique : sur les Pokémon Fée."
    },
    "alquimia4" => {
      :es => "Madera: se obtiene cortando árboles y en cajas de suministros. Guijarro: se encuentran en cuevas y lugares pedregosos. Polvo de Hueso: muy escaso, se encuentra en catacumbas y profundidades.",
      :fr => "Bois : scierie de Bois-en-Tronc, en coupant des arbustes, dans des caisses. Galet : dans les boutiques, en éclatant des rochers, dans les amas rocheux. Poudre d'Os : très rare, dans les catacombes et autres cryptes."
    },
    "cartaBayas" => {
      :es => "Carta de Bayas. Baya Zreza, color rojo: cura la parálisis. Baya Aranja, color azul: cura un poco los PS. Baya Ziuela, color verde: cura todos los estados. Baya Zidra, color amarillo: cura mucho los PS. Baya Atania, color morado: cura el sueño.",
      :en => "Berry Recipe. Cheri Berry, color red: cures paralysis. Oran Berry, color blue: restores HP. Lum Berry, color green: cures status effects. Sitrus Berry, color yellow: restores a lot of HP. Chesto Berry, color purple: cures sleep.",
      :fr => "Baies du jour. Ceriz : soigne la paralysie. Oran : soigne quelques PV. Prine : soigne n'importe quel statut. Sitrus : soigne beaucoup de PV. Maron : soigne le sommeil."
    },
    "MenuClasSel" => {
      :es => "Modo Normal. Juega con la dificultad predeterminada.",
      :en => "Normal Mode. Play with the default difficulty.",
      :fr => "Mode Normal. Jouer au jeu avec le niveau de difficulté prédéterminé."
    },
    "MenuCompSel" => {
      :es => "Modo Heroico. Dificultad elevada para jugadores que buscan un reto.",
      :en => "Heroic Mode. High difficulty for players looking for a challenge.",
      :fr => "Mode Héroïque. Jouer au jeu avec un niveau de difficulté élevé."
    },
    "MenuRandSel" => {
      :es => "Modo Fácil. Dificultad reducida en los combates.",
      :en => "Easy Mode. Reduced difficulty in battles.",
      :fr => "Mode Facile. Jouer au jeu sans se prendre la tête."
    },
    "MenuNormalClaro" => {
      :es => "Sin Nuzlocke. Juega sin normas adicionales.",
      :en => "No Nuzlocke. Play without additional rules.",
      :fr => "Classique. Jouer au jeu sans règles additionnelles."
    },
    "MenuNuzNuzClaro" => {
      :es => "Nuzlocke. Los Pokémon debilitados mueren permanentemente.",
      :en => "Nuzlocke. Fainted Pokémon die permanently.",
      :fr => "Nuzlocke. Jouer au jeu en mode Nuzlocke."
    },
    "MenuNuzAyudaClaro" => {
      :es => "Nuzlocke con ayuda. 2 resurrecciones tras cada gimnasio.",
      :en => "Nuzlocke with help. 2 resurrections after each gym.",
      :fr => "Nuzlocke assisté. Jouer au jeu en mode Nuzlocke avec 2 résurrections par arène vaincue."
    }
  )
end

# Regi legendary inscriptions (maps 289/245/303): a braille message shown as an image. Instead of speaking
# dots, the mod announces a mystery braille message, sends the braille (as unicode, U+2800 + dot mask)
# straight to any connected braille display, and copies it to the clipboard so a player without a display
# can paste it into Notepad.
#
# Per build, like the pictures above: the en build reuses the Spanish plaques byte for byte (verified by
# hash), the fr build paints its own inscriptions -- decoded dot by dot from its PNGs with the same
# extractor that reproduces the verified Spanish tables exactly. The French plaques write with English
# grade-2-style signs (dot 6 capitals, dots-12456 "er", two-cell accent prefixes); the dots ship as
# painted, the reader's display renders them as the plaque intends.
module PokeAccess
  module ZRegi
    # Keys are the games actual picture names: map 289's plaque is "reg1" (no "i"), maps 245/303 are
    # "regi2"/"regi3" -- the game names them inconsistently, so these match the assets exactly (verified).
    BRAILLE = {
      "reg1" => {
        :es => [0x283A, 0x2801, 0x280A, 0x2807, 0x2815, 0x2817, 0x2819, 0x20, 0x2811, 0x2807, 0x20, 0x280F, 0x2817, 0x280A, 0x280D, 0x2811, 0x2817, 0x2815],
        :fr => [0x2820, 0x283A, 0x2801, 0x280A, 0x2810, 0x2807, 0x20, 0x2811, 0x281D, 0x20, 0x280F, 0x2817, 0x2811, 0x280D, 0x280A, 0x283B]
      },
      "regi2" => {
        :es => [0x2807, 0x2811, 0x281D, 0x281E, 0x2811, 0x20, 0x2819, 0x2811, 0x20, 0x2807, 0x2801, 0x20, 0x2827, 0x2811, 0x2817, 0x2819, 0x2801, 0x2819],
        :fr => [0x2820, 0x280D, 0x280A, 0x2817, 0x2815, 0x280A, 0x2817, 0x20, 0x2819, 0x2811, 0x20, 0x2807, 0x2801, 0x20, 0x2820, 0x2827, 0x2818, 0x280C, 0x2811, 0x2817, 0x280A, 0x281E, 0x2818, 0x280C, 0x2811]
      },
      "regi3" => {
        :es => [0x280F, 0x280A, 0x2811, 0x2819, 0x2817, 0x2801, 0x20, 0x280A, 0x281D, 0x280B, 0x2811, 0x2817, 0x280A, 0x2815, 0x2817, 0x20, 0x2819, 0x2811, 0x2817, 0x2811, 0x2809, 0x2813, 0x2801],
        :fr => [0x2820, 0x280F, 0x280A, 0x283B, 0x2817, 0x2811, 0x20, 0x2811, 0x281D, 0x20, 0x2803, 0x2801, 0x280E, 0x20, 0x2818, 0x2821, 0x2801, 0x20, 0x2819, 0x2817, 0x2815, 0x280A, 0x281E, 0x2811]
      }
    }
    @last = nil

    # On a regi inscription picture: pushes its braille to the display, copies it to the clipboard and
    # announces it. Deduped so the engine's same-picture re-show does not copy twice; reset() (on erase)
    # allows re-reading.
    def self.on_picture(name)
      cps = PokeAccess::GameLang.pick(BRAILLE[name.to_s], :es)
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
