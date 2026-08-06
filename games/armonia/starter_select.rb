# Armonia starter selection (shiney570's PokemonStarterSelection): a custom sprite picker that replaces the
# standard starter menu. gettinginput runs every frame and moves @select (1..3) over three balls; the focused
# starter's name and types are drawn to a bitmap, so nothing is spoken. Hook gettinginput, dedup by @select,
# and read the focused starter's name and type(s). The confirm prompt (pbConfirmMessage) is already spoken by
# the message reader.
#
# The starter is resolved from @data with the CURRENT @select rather than read off @pokemon, because the
# scene's loop assigns `@pokemon = @data["pkmn_#{@select}"]` BEFORE calling gettinginput. In an after-hook
# @select is therefore already the new ball while @pokemon is still the previous one: every press re-read the
# starter you had just left, and the one you moved onto was never named at all -- the dedup had already been
# spent on its index. It is the first screen of a new game.
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
