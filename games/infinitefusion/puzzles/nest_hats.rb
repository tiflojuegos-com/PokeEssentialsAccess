# The secret nest hats: standing still for a moment brings a wild Pokemon near, and moving makes it flee and leaves a hat.
# Route 1 (map 78, event 10), the Safari Zone (445, event 40), Viridian Forest (491, events 58 and 59, each only one visit in
# five) and Mt. Moon's summit (827, event 3) count frames of stillness south of row 5 (variable 289, reset by the counter
# event as the player moves); Route 15 (444, event 29) counts it north of row 20 instead. Celadon (95) needs one of five
# bare squares (events 81 to 83, 86 and 87) stepped on facing up, and then stillness; event 6 draws its Eevee. Each map is
# done once its hats are owned.
PokeAccess::Game.define("infinitefusion") do
  nests = {
    78 => [[10, "pidgey"]], 445 => [[40, "headparas"]], 491 => [[58, "pikhatchum"], [59, "pikhatchuf"]],
    827 => [[3, "swablu"]], 95 => [[6, "eevee"]], 444 => [[29, "headgoomy"]]
  }
  has = lambda { |hat| respond_to?(:hasHat?, true) && hasHat?(hat) }
  waiting = lambda do |pairs|
    pairs.any? do |id, hat|
      ev = $game_map.events[id]
      ev && !PokeAccess.ivar(ev, :@erased) && !has.call(hat)
    end
  end

  nests.each do |map, pairs|
    mechanic(:state, map) do
      auto
      pairs.each do |id, _hat|
        watch :event => id, :label => :ifq_nest_label, :on => :ifq_nest_here, :off => :ifq_nest_fled
      end
      solved(nil, :quiet => true) { pairs.all? { |_id, hat| has.call(hat) } }
      if map == 95
        name [81, 82, 83, 86, 87], :ifq_nest_square, :assist => true
        hint :ifq_nest_hint_squares
      else
        still = map == 444 ? :ifq_nest_hint_north : :ifq_nest_hint_still
        hint lambda { waiting.call(pairs) ? still : "" }
      end
    end
  end
end
