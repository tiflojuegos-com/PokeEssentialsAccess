# Infinite Fusion keeps one LANGUAGES list per game (Settings::LANGUAGES[Settings::GAME_ID]; Hoenn ships French and
# Chinese), so the language the game runs in is read from its own game's list.
PokeAccess::Game.define("infinitefusion_common") do
  override("PokeAccess::GameLang", :languages_table) do |_mod, original, _args|
    t = (::Settings::LANGUAGES rescue nil)
    t.is_a?(Hash) ? (t[(::Settings::GAME_ID rescue nil)] rescue nil) : original.call
  end
end
