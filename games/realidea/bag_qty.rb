# Key items Realidea's own vercantidad accepts (the Paper) keep their painted count; other key items hide it.
PokeAccess::Game.define("realidea") do
  override("PokeAccess::Menus", :bag_hides_qty?) do |_mod, original, args|
    (vercantidad(args[0]) rescue false) ? false : original.call
  end
end
