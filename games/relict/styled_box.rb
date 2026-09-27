# Relict's Deluxe Battle Kit copy draws a styled databox's foe with the Pokemon's own sex sign and level, where
# the stock box has the name alone; the HP and info keys follow it.
PokeAccess::Game.define("relict") do
  override("PokeAccess::Battle", :shown_sex) do |_mod, original, args|
    b = args[0]
    if PokeAccess::Battle.styled_box(b)
      s = PokeAccess::Party.sign((b.gender rescue nil))
      s ? " #{s}" : ""
    else
      original.call
    end
  end
  override("PokeAccess::Battle", :shown_level) do |_mod, original, args|
    PokeAccess::Battle.styled_box(args[0]) ? args[0].level : original.call
  end
end
