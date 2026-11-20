# Shimo Mountain (maps 155, 169, 170, 171) and Minoru's farm (176): the Radiant Petals lie as events named Feather, and the
# Reins of Unity ask for a carrot offered on the summit altar. Minoru gives one seed for four berries; it grows in the soil of
# map 169 (south-west graveyard, where a Houndstone takes the harvest and must be fought) or of map 170 (north-east), each
# phase waiting for a yes to "wait", and the altar of map 155 (event 4) takes the carrot together with the Reins of Unity.
# With one seed the soil is a choice for good: map 169 grows the Shaderoot carrot (Spectrier) and map 170 the Iceroot
# (Glastrier). The hint stops once the offering is made (self switch C of the altar).
module PokeAccess
  module KeishouShimo
    # True while a self switch of an event of the current map is off.
    def self.off?(id, letter = "A")
      !$game_self_switches[[$game_map.map_id, id, letter]]
    end

    # True once the carrot has been offered.
    def self.offered?
      $game_self_switches[[155, 4, "C"]] ? true : false
    end

    # True while the altar still waits for its offering.
    def self.altar_waiting?(ev)
      off?(ev.id) && off?(ev.id, "C")
    end
  end
end

PokeAccess::Game.define("keishou") do
  petal = lambda { |ev| PokeAccess::KeishouShimo.off?(ev.id) }
  altar = lambda { |ev| PokeAccess::KeishouShimo.altar_waiting?(ev) }
  hinting = lambda { PokeAccess::Puzzles.assist? && !PokeAccess::KeishouShimo.offered? }

  mechanic(:state, 155) do
    auto
    name 4, :ks_carrot_altar, :when => altar
    hint :ks_carrot_hint
    active(&hinting)
  end

  mechanic(:state, 169) do
    auto
    name 2, :ks_radiant_petal, :when => petal
    name 4, :ks_carrot_soil, :when => lambda { |_ev| !$game_switches[77] }
    hint :ks_carrot_hint
    active(&hinting)
  end

  mechanic(:state, 170) do
    auto
    name 1, :ks_radiant_petal, :when => petal
    name 2, :ks_carrot_soil, :when => lambda { |_ev| !$game_switches[76] }
    hint :ks_carrot_hint
    active(&hinting)
  end

  mechanic(:state, 171) do
    auto
    name 2, :ks_radiant_petal, :when => petal
  end

  mechanic(:state, 176) do
    auto
    hint :ks_carrot_hint
    active(&hinting)
  end
end
