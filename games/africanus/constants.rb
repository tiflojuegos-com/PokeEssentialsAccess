# Africanvs profile (gen-6 Essentials / mkxp-z) on the core defaults; its quests and achievements are read by the
# easy_questing and logros plugin readers its manifest declares.
module PokeAccess
  module Config
  end
end

# Africanvs' Input keeps RPG Maker XP's default letters, as in the achievements' "Presiona A".
PokeAccess::Game.define("africanus") do
  key_hints PokeAccess::KeyHints::RGSS_LETTERS
end
