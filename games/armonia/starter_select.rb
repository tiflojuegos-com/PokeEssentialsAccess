# Armonia starter selection (shiney570's PokemonStarterSelection): gettinginput runs every frame and moves
# @select (1..3) over three balls, with the focused starter drawn to a bitmap. Hooked there, deduped by
# @select, reading name and types. The starter is resolved from @data with the CURRENT @select rather than
# @pokemon, which the loop assigns BEFORE gettinginput and so still holds the previous ball in an after-hook.
PokeAccess::Game.define("armonia") do
  after("PokemonStarterSelection", :gettinginput) do |scene, _result, _args|
    sel = PokeAccess.ivar(scene, :@select)
    next unless PokeAccess::Cursor.changed?(scene, :starter_sel, sel)
    data = PokeAccess.ivar(scene, :@data)
    pkmn = data.is_a?(Hash) ? data["pkmn_#{sel}"] : nil
    next unless pkmn
    name = (pkmn.name rescue nil)
    next if !name || name.to_s.empty?
    types = (PokeAccess::Data.pokemon_types(pkmn) rescue [])
    txt = types.empty? ? name.to_s : "#{name}, #{types.join('/')}"
    PokeAccess.speak_clean(txt, true)
  end
end
