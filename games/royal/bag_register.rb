# Royal's bag draws the register icon on any item the quick menu would take (pbCanRegisterItem?), not only key
# items, so the shared test's key-item guard is dropped here.
PokeAccess::Game.define("royal") do
  override("PokeAccess::Menus", :bag_registrable?) do |mod, _original, args|
    bag, itemid = args
    if mod.bag_registered?(bag, itemid)
      false
    else
      (pbCanRegisterItem?(itemid) rescue false) ? true : false
    end
  end
end
