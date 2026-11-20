# Lanthanite Cave (map 106): ice floor whose slide stops at eight fixed ice blocks (events 9 to 16).
PokeAccess::Game.define("uranium") do
  mechanic(:state, 106) do
    auto
    name 9..16, :ura_po_ice_block
    arrival_hint :ura_po_lanthanite_rule, :once => true
  end
end
