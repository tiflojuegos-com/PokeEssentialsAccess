# Route 24 (map 418), Martin's farm work: while switch 175 is on, five spots with no graphic by the pens, where the
# player looks at the farm's Pokémon, each add to variable 78. The pen of Wooloo and Mareep answers only facing up,
# and the Miltank and Tauros spots fire by stepping on them.
PokeAccess::Game.define("herolegacy") do
  species = lambda { |id| PokeAccess::Data.species_name(id).to_s }
  pen = lambda do |*ids|
    lambda { |_ev| PokeAccess::I18n.t(:hl_farm_pen, :name => ids.map { |id| species.call(id) }.join(", ")) }
  end
  mechanic(:state, 418) do
    auto
    name 14, pen.call(:SKIDDO)
    name 16, pen.call(:PONYTA)
    name 17, pen.call(:WOOLOO, :MAREEP)
    name 21, pen.call(:MILTANK)
    name 22, pen.call(:TAUROS)
  end
end
