# The Sky Pillar of Route 131: on its second and fourth floors (maps 572 and 574) cracked floor tiles (events named tree
# that run pbTransferSameCoords) give way under a walker at once, dropping them to the floor below at the same tile. On
# the bicycle the first pass only cracks one (self switch A), and a parallel page drops whoever then stands on it, so it
# is crossed riding on without stopping and never twice. pbResetSkyPillar mends them as the player falls. On the second
# floor the way up crosses some cracks whatever way is taken.
module PokeAccess
  module SeviiSkyPillar
    FLOORS = [572, 574]

    # The crack tiles of a floor: its tree events that drop the player.
    def self.cracks(map)
      map == 572 ? (4..41).to_a : (5..38).to_a
    end

    # A crack's name: broken open once cracked, plain before.
    def self.crack_name(map, ev)
      $game_self_switches[[map, ev.id, "A"]] ? :sevii_pillar_cracked : :sevii_pillar_crack
    end
  end
end

PokeAccess::Game.define("sevii") do
  pillar = PokeAccess::SeviiSkyPillar

  pillar::FLOORS.each do |map|
    mechanic(:state, map) do
      auto
      name pillar.cracks(map), lambda { |ev| pillar.crack_name(map, ev) }, :when => false
      avoid pillar.cracks(map), :assist => true
      arrival_hint :sevii_pillar_rule, :once => true
      hint :sevii_pillar_hint
    end
  end
end
