# Pokemon Anil 4.0 constants: a modern Essentials base (GameData, Battle::Scene, Ruby 3.1), core key defaults.
module PokeAccess
  module Config
  end
end

# Anil's hints name RPG Maker XP's default letter keys ("[S] Volar", "Pulsa [D]"), and Alt, the remappable turbo.
PokeAccess::Game.define("anil") do
  key_hints PokeAccess::KeyHints::RGSS_LETTERS.merge("Alt" => :alt)
end
