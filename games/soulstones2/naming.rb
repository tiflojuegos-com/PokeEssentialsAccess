# Soulstones 2's way out of Breloom's penthouse: a touch tile whose script leaves for the map a variable holds. The
# game's naps run that same script, so only the event's name tells them apart.
PokeAccess::Game.define("soulstones2") do
  override("PokeAccess::Locator", :transfer_event_uncached?) do |_mod, original, args|
    original.call || args[0].name.to_s == "Leave B9K Penthouse"
  end
end
