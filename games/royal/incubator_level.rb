# The incubator level Royal writes above the grid ($PokemonGlobal.version_incubadora), said before the first slot.
PokeAccess::Game.define("royal_incubator") do
  override("PokeAccess::Incubator", :header) do |_mod, _original, _args|
    lv = ($PokemonGlobal.version_incubadora rescue nil)
    lv ? PokeAccess::I18n.t(:hatch_level, :n => lv) : nil
  end
end
