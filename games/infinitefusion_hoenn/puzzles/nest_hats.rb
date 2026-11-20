# Hoenn's secret nest hats: standing still for a moment brings a wild Pokemon near, and moving makes it flee and leaves a hat.
# Route 101 (map 5, event 24, from switch 2012 on) and Route 115 (map 65, event 30) count stillness south of row 5 (variable
# 289, reset by the counter event as the player moves). Route 102 (map 10, event 22, until switch 2025) counts it anywhere
# and, one visit in twenty, brings the shiny Ralts, a hat of its own. Each map is done once its hats are owned.
PokeAccess::Game.define("infinitefusion_hoenn") do
  nests = { 5 => [24, %w[zigzaghat]], 10 => [22, %w[ralts raltsshiny]], 65 => [30, %w[swablu]] }
  has = lambda { |hat| respond_to?(:hasHat?, true) && hasHat?(hat) }
  missing = lambda { |hats| hats.reject { |hat| has.call(hat) } }
  live = lambda do |map, id|
    ev = $game_map.events[id]
    ev && !PokeAccess.ivar(ev, :@erased) && (map != 5 || $game_switches[2012])
  end
  ralts = lambda do
    left = missing.call(nests[10][1])
    if $game_switches[2025] || left.empty? then ""
    elsif left.include?("ralts") then :if_ho_nest_hint_ralts
    else :if_ho_nest_hint_shiny
    end
  end

  nests.each do |map, nest|
    id, hats = nest
    mechanic(:state, map) do
      auto
      watch :event => id, :label => :ifq_nest_label, :on => :ifq_nest_here, :off => :ifq_nest_fled
      solved(nil, :quiet => true) { missing.call(hats).empty? }
      if map == 10
        hint ralts
      else
        hint lambda { live.call(map, id) && !missing.call(hats).empty? ? :ifq_nest_hint_still : "" }
      end
    end
  end
end
