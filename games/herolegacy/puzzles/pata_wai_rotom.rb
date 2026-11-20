# Pata Wai, house 3 (map 228): five appliances drawn along row 8, each answered by a tile with no graphic in front of it
# (row 9) that, with Rotom first in the party, lets it into the appliance and changes its form. The tiles go by the
# appliance they stand before, which is all a sighted player sees.
PokeAccess::Game.define("herolegacy") do
  appliances = { 11 => :hl_rotom_heat, 15 => :hl_rotom_wash, 7 => :hl_rotom_frost, 8 => :hl_rotom_fan,
                 16 => :hl_rotom_mow }
  mechanic(:state, 228) do
    auto
    appliances.each { |ev, key| name ev, key }
  end
end
