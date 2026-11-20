# Nami's three monkeys (SQ3): Pansear in Yosei Woods (map 88, event 19), Pansage on Suna Beach (101, event 2) and Panpour in Aki
# Forest (384, event 6), each counted in var 39 when found, which a defeat counts as much as a catch. Pansage only counts on its
# third meeting (var 47). With the three, the invisible monkey in front of the Lele Shrine door (map 92, event 4) turns into a
# fight. The count and the hint speak from Nami's request (self switch A of her event 2 on map 88) to the end of that fight
# (self switch B of event 4 on map 92).
module PokeAccess
  module KeishouMonkeys
    FOUND = [[88, 19, :ks_monkey_pansear], [101, 2, :ks_monkey_pansage], [384, 6, :ks_monkey_panpour]]

    # The hint: the monkeys still to find and where, or what the three open.
    def self.hint
      left = FOUND.reject { |m| $game_self_switches[[m[0], m[1], "A"]] }
      return :ks_monkeys_done if left.empty?
      [:ks_monkeys_hint, { :list => left.map { |m| PokeAccess::I18n.t(m[2]) }.join(", ") }]
    end

    # True from Nami's request.
    def self.started?
      $game_self_switches[[88, 2, "A"]] ? true : false
    end

    # True from Nami's request until the fight at the shrine door is over.
    def self.running?
      started? && !$game_self_switches[[92, 4, "B"]]
    end

    # True while the invisible monkey still blocks the shrine door.
    def self.blocking?
      !$game_self_switches[[92, 4, "A"]] && !$game_self_switches[[92, 4, "B"]]
    end
  end
end

PokeAccess::Game.define("keishou") do
  mechanic(:state, [88, 101, 384]) do
    auto
    count :ks_monkeys, :var => 39, :of => 3
    hint lambda { PokeAccess::KeishouMonkeys.hint }
    active { PokeAccess::KeishouMonkeys.running? }
  end

  mechanic(:state, 92) do
    auto
    name 4, lambda { |_ev| PokeAccess::KeishouMonkeys.blocking? ? :ks_invisible_block : nil },
         :when => lambda { |_ev| PokeAccess::KeishouMonkeys.blocking? }
    count :ks_monkeys, :var => 39, :of => 3
    hint lambda { PokeAccess::KeishouMonkeys.hint }
    active { PokeAccess::KeishouMonkeys.running? }
  end
end
