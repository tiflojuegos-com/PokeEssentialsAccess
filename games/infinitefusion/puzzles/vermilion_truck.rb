# Vermilion's truck (map 19): event 33, drawn as nothing, east of the truck, asks "push the truck?" only when faced from
# the east. The push (switch 976) uncovers a Mist Stone ball; the hidden battle of event 34 waits on a switch nothing sets.
PokeAccess::Game.define("infinitefusion") do
  pushed = lambda { $game_switches[976] }

  mechanic(:state, 19) do
    auto
    name 33, :ifo_truck, :assist => true, :when => lambda { |_ev| !pushed.call }
    hint lambda { pushed.call ? nil : :ifo_truck_hint }
    active { PokeAccess::Puzzles.assist? && !pushed.call }
  end
end
