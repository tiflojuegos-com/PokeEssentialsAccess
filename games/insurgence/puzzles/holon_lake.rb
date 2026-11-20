# Holon Undercave, the underwater floor of the Magby pool (map 793, reached from map 489): Dive surfaces only where the
# surface map (557) has deep water, a ring of 24 tiles around the island with Delta Magby. The seabed marks it as a ring
# of lighter sediment, 7 tiles across (x 33 to 39, y 27 to 33); its four middle tiles stand for it in the list.
PokeAccess::Game.define("insurgence") do
  mechanic(:state, 793) do
    auto
    [[36, 27], [36, 33], [33, 30], [39, 30]].each { |x, y| spot :at => [x, y], :label => :ins_o2_sediment }
    arrival_hint lambda { PokeAccess::Puzzles.assist? ? :ins_o2_sediment_hint : nil }, :once => true
    hint :ins_o2_sediment_hint
    active { true }
  end
end
