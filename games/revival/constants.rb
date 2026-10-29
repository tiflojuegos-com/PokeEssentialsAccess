# Pokemon Revival profile, on La Base de Sky (Essentials v21.1 with its MUI and Deluxe Battle Kit plugins) and the
# core's v21 readers; its own screens are the other modules of this folder.
module PokeAccess
  # The language Revival's own pictures are painted in.
  module RevivalLang
    # Whether the game shows its English pictures: any language but the first, as its scripts pick the _en files.
    def self.english?
      ($PokemonSystem.language.to_i != 0 rescue false)
    end
  end
end

# Sky's base paints RPG Maker XP's default letters in its hints ("[D]: Descripción", the summary's SPECIAL).
PokeAccess::Game.define("revival") do
  key_hints PokeAccess::KeyHints::RGSS_LETTERS
end
