# PokedexInfoV21.entry_number: the stored 1-based :number, one lower when the entry has :shift (a region in
# DEXES_WITH_OFFSETS), as the screen shows it.
Suite.define("battle: pokedex entry_number matches the shown number without an offset") do
  scene = Object.new
  scene.instance_variable_set(:@dexlist, [{ :species => :BULBASAUR, :number => 4, :shift => false }])
  scene.instance_variable_set(:@index, 0)
  eq "the raw number is spoken when the dex has no offset", PokeAccess::PokedexInfoV21.entry_number(scene), 4
end

Suite.define("battle: pokedex entry_number applies the :shift offset like the screen") do
  scene = Object.new
  scene.instance_variable_set(:@dexlist, [{ :species => :BULBASAUR, :number => 4, :shift => true }])
  scene.instance_variable_set(:@index, 0)
  eq "an offset dex speaks one less than the stored number", PokeAccess::PokedexInfoV21.entry_number(scene), 3
end

# A zero number (painted "???") is nil with or without :shift, and so is a scene with no dexlist.
Suite.define("battle: pokedex entry_number stays nil for an unnumbered entry") do
  scene = Object.new
  scene.instance_variable_set(:@dexlist, [{ :species => :MEW, :number => 0, :shift => true }])
  scene.instance_variable_set(:@index, 0)
  falsy "a zero number is not spoken even with an offset flag", PokeAccess::PokedexInfoV21.entry_number(scene)

  bare = Object.new
  falsy "a scene without a dexlist yields no number", PokeAccess::PokedexInfoV21.entry_number(bare)
end
