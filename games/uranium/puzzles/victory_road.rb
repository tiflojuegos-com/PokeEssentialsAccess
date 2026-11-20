# Victory Road's volcano (map 184): six boulders (events 1, 2, 5, 6, 7 and 8) fill six holes (events 34 to 39, their self
# switch A on once filled) and each filled pair raises one bridge over the lava. The west bridge (holes 34 and 35) leads to
# the south, whose holes 38 and 39 raise the central bridge, and that one to the east, whose holes 36 and 37 raise the
# north-east bridge, the only way to the apex.
module PokeAccess
  module UraniumVictoryRoad
    # Whether the hole event is already filled by a boulder.
    def self.filled?(id)
      $game_self_switches[[184, id, "A"]] ? true : false
    end

    # Whether all the holes given are filled.
    def self.done?(*ids)
      ids.all? { |id| filled?(id) }
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 184) do
    auto
    arrival_hint :ura_po_vr_rule, :once => true
    name 34..39, lambda { |ev| PokeAccess::UraniumVictoryRoad.filled?(ev.id) ? nil : :ura_po_vr_hole }
    count :ura_po_vr_west, :selfs => [[34, 35], "A", 184], :of => 2
    count :ura_po_vr_center, :selfs => [[38, 39], "A", 184], :of => 2
    count :ura_po_vr_northeast, :selfs => [[36, 37], "A", 184], :of => 2
    phase lambda { !PokeAccess::UraniumVictoryRoad.done?(34, 35) }, :quiet => true, :hint => :ura_po_vr_hint_west
    phase lambda { !PokeAccess::UraniumVictoryRoad.done?(38, 39) }, :quiet => true, :hint => :ura_po_vr_hint_center
    phase lambda { !PokeAccess::UraniumVictoryRoad.done?(36, 37) }, :quiet => true, :hint => :ura_po_vr_hint_northeast
  end
end
