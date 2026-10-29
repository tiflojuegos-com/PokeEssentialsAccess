# Revival's text cards, event pictures whose text nothing else says: the chapter cards (CAPITULO*, one picture per
# language), the title drop's credit and logo, the wanted posters, the unstoppable Pokemon's defeat banner (its two
# halves shown together, said as the second comes up), each said from its transcription as it shows; and the banner
# a character joins the party or takes control with, said with the card of that character's name shown under it.
module PokeAccess
  module RevivalCards
    # What each banner paints, by picture.
    BANNERS = { "Seunealgrupo" => "Se une al grupo", "Seunealgrupo_en" => "Joins the party",
                "Tomaelcontrol" => "Toma el control", "Tomaelcontrol_en" => "Takes control" }

    # What each name card the events show paints, by picture.
    NAMES = { "NombreCira" => "Cira", "NombreGalg" => "Galg Kir", "NombreGawain" => "Gawain",
              "NombreMilenka" => "Milenka", "NombreNullin" => "Nullin", "NombrePikachu" => "Pikachu",
              "NombrePorygon" => "Porygon", "NombrePupitar" => "Pupitar", "NombreRufio" => "Rufio",
              "NombreSamurott" => "Samurott", "NombreSirfetchd" => "Sirfetch'd", "NombreTunia" => "Tunia",
              "NombreVezo" => "Vezo" }

    # The banner on screen with a name card, which the events show first on a slot of its own; nil when none is.
    def self.banner
      pics = ($game_screen.pictures rescue nil)
      return nil unless pics
      (1..50).each do |i|
        t = BANNERS[(pics[i].name rescue nil).to_s]
        return t if t
      end
      nil
    end

    # Says a name card as it shows, after the banner over it, at once.
    def self.shown(picture)
      who = NAMES[picture.to_s]
      PokeAccess.speak(PokeAccess.sentences([banner, who]), true) if who
    end
  end
end

PokeAccess::Game.define("revival") do
  picture_texts("CAPITULO01" => "Capítulo 1. DEJA VU", "CAPITULO01fin" => "Capítulo 1. DEJA VU",
                "CAPITULO01en" => "Chapter 1. DEJA VU", "CAPITULO01finen" => "Chapter 1. DEJA VU",
                "CAPITULO02" => "Capítulo 2. ENCRUCIJADA", "CAPITULO02fin" => "Capítulo 2. ENCRUCIJADA",
                "CAPITULO02en" => "Chapter 2. CROSSROADS", "CAPITULO02finen" => "Chapter 2. CROSSROADS",
                "CAPITULO03" => "Capítulo 3. EL MISERABLE", "CAPITULO03fin" => "Capítulo 3. EL MISERABLE",
                "CAPITULO03en" => "Chapter 3. THE MISERABLE", "CAPITULO03finen" => "Chapter 3. THE MISERABLE",
                "tituloreinicioa" => "Basado en los juegos de The Pokémon Company. SQUARE ENIX",
                "titulo reinicio" => "Pokémon Revival",
                "victoriapokemon2" => "POKÉMON IMPARABLE. ¡DERROTADO!",
                "wantedofix1" => "WANTED. Kurev Ranger Dppt.",
                "wantedofi" => "WANTED. Kurev Ranger Dppt. Documento reservado para agentes de Kurev y la Guardia " \
                               "real. Cira Stratford (19), mercenaria, hurto. Petunia Tyson (26), alta traición y " \
                               "hurto de Pokémon. Los sujetos deben ser capturados cuanto antes e indemnes para ser " \
                               "entregados al cuerpo de Pokémon Ranger en Kurev. Campeón de Kurev. Galg Kir",
                "wantedrufio" => "WANTED. 1.000.000₽. Renault Thatch a.k.a. Rufio. DEAD OR ALIVE. Líder del Equipo " \
                                 "Sigma. Hurto de Pokémon, vandalismo, rebelión, pillaje, agresión y evasión fiscal.")
  on_picture { |picture, _args| PokeAccess::RevivalCards.shown(picture) }
end
