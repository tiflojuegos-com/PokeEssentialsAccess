# Insight (variable 90): finds that each add to "your knowledge of the mystery", read later by one check for 6 or more (map
# 381). Most shine (graphic "sparkle", gone once read); three have no sprite, a diary or a note drawn on the map: Odis Town
# Hall (map 326, event 1), the Wildlands (map 328, event 5) and the Wildlands Cave (map 334, event 7, two at once). The
# scenes of maps 329 and 479 move it on their own and are left out.
module PokeAccess
  module DesolationInsight
    POINTS = { 164 => [2, 3, 4, 5, 14], 317 => [10], 318 => [6], 319 => [1], 320 => [5], 322 => [1], 326 => [1],
               328 => [5], 332 => [1], 334 => [7], 451 => [15] }

    # True while the find has not been read.
    def self.open?(map, ev)
      !$game_self_switches[[map, ev.id, "A"]]
    end

    # A find's name: a shine for anyone, what it is with the assist.
    def self.label(ev)
      return :deso_insight_point if PokeAccess::Puzzles.assist?
      ev.character_name.to_s == "sparkle" ? :deso_insight_shine : nil
    end
  end
end

PokeAccess::Game.define("desolation") do
  ins = PokeAccess::DesolationInsight
  ins::POINTS.each do |map, ids|
    mechanic(:state, map, :part => :insight) do
      auto
      name ids, lambda { |ev| ins.label(ev) },
           :when => lambda { |ev| ins.open?(map, ev) && (ev.character_name.to_s == "sparkle" || PokeAccess::Puzzles.assist?) }
      count :deso_insight_count, :var => 90, :of => 6, :assist => true, :hide_zero => true
    end
  end
end
