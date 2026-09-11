# The "BW Key Items" ceremony (plugins/bw_key_items.rb) names what it shows as it starts: an item id
# through the data adapter, or a picture name -- the shape the Pokévial and the portable healer pass,
# which never reaches the game's own "obtained" message.
Suite.define("key item ceremony: the item is named from its id or from its picture name") do
  k = PokeAccess::KeyItemGet
  eq "an item id goes through the data adapter", k.name_of(:POTION), PokeAccess::Data.item_name(:POTION)
  eq "a picture name sheds its suffix", k.name_of("VIAL_key"), "Vial"
  eq "and its item prefix, with underscores spoken as spaces", k.name_of("item012_CURA_PORTATIL_key"), "Cura portatil"
  eq "nothing is nothing", k.name_of(nil), nil
  eq "a name that is all suffix says nothing", k.name_of("_key"), nil
end
