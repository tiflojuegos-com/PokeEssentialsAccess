# Opalo's event pictures that paint text with no message beside them: the clue notes that give the digits of the
# treasure chest's code in the Ruinas Secretas (pista1-3), and the credits (Map361, and the ending's cred1-8 and fin).
module PokeAccess
  module OpaloPictures
    # Clue note => the two digits it paints.
    CLUES = { "pista1" => "2 6", "pista2" => "0 2", "pista3" => "2 1" }

    # Credits picture => its painted text, transcribed from the game's images (Opalo ships in Spanish only).
    CREDITS = {
      "creditos1" => "Creado por EricLostie",
      "creditos2" => "Pokemon Essentials: Maruno, Pira, Flameguru, Poccil. RPGMaker XP: Enterbrain",
      "creditos3" => "Pokemon es una licencia propiedad de The Pokemon Company, GameFreak, Nintendo",
      "cred1" => "Arte: Mr. Almagrís, Rinkuu, Dewy, ChekaArt, Therusan",
      "cred2" => "Sprites: Don Flowers, Gamid, Scept",
      "cred3" => "Música: Asier Orozco, Dan_trvlr",
      "cred4" => "Scripts: Skyflier, Alberto, Clara, Pira",
      "cred5" => "Agradecimientos: HarveySpecter, Mosh, Izquierdinho, JorgeMar, Team Cháchara, antonio_rona88, " \
                 "xdiegoxv2",
      "cred6" => "Creado por EricLostie",
      "cred7" => "¡Muchas gracias por jugar!",
      "cred8" => "Para Mimi",
      "fin" => "Fin"
    }

    # Says a clue note's digits, or queues a credits picture's text, as two credits share the screen.
    def self.on_picture(name)
      if CLUES[name]
        PokeAccess.speak(PokeAccess::I18n.t(:op_clue, :digits => CLUES[name]), true)
      elsif CREDITS[name]
        PokeAccess.speak(CREDITS[name], false)
      end
    end
  end
end

PokeAccess::Game.define("opalo") do
  on_picture { |name, _args| PokeAccess::OpaloPictures.on_picture(name) }
end
