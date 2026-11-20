# The sleeping girl's mission: Dream Route 13 (maps 111, 207, 208, 209 and 213) counts three points, one per path, in
# switches 248 (east, map 208 event 6), 249 (north, map 209 event 11) and 250 (west, map 111 event 7); Abyssal Venesi
# (map 71, abyssal_venesi.rb) sends the player back to its start from a wrong path.
PokeAccess::Game.define("uranium") do
  mechanic(:state, [111, 207, 208, 209, 213, 217], :part => :trackers) do
    auto
    arrival_hint :ura_po_dream_rule, :once => true
    count :ura_po_dream_trackers, :switches => [248, 249, 250], :of => 3
  end

  mechanic(:state, 111, :part => :west_tracker) do
    auto
    spot :event => 7, :label => :ura_po_dream_tracker, :assist => true, :when => lambda { !$game_switches[250] }
  end

  mechanic(:state, 209, :part => :north_tracker) do
    auto
    spot :event => 11, :label => :ura_po_dream_tracker, :assist => true, :when => lambda { !$game_switches[249] }
  end

  mechanic(:state, 208, :part => :east_tracker) do
    auto
    spot :event => 6, :label => :ura_po_dream_tracker, :assist => true, :when => lambda { !$game_switches[248] }
  end
end
