# Egg incubator (Kyu's plugin, class Incubadora): the same six-slot grid the core Hatcher screen has --
# @index over $PokemonGlobal.eggs, egg.eggsteps for the hatch hint -- under a different class name, which
# is the only reason the core's own hooks never matched it. refresh runs on open and after every move.
#
# The two copies are the SAME FILE, byte for byte, so there is nothing to reconcile and this can simply
# point the core reader at the other class name.
PokeAccess::Hooks.after_hook("Incubadora", :refresh, :optional => true) do |scene, _r, _a|
  PokeAccess::Incubator.announce(scene)
end
