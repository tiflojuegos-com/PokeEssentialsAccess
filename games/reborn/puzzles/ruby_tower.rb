# Citae Astrae's Ruby Tower (map 310): spriteless statues before drawn ones tell a truth or a lie and ask whether they
# are Light or Dark. Chimchar, Monferno and Infernape (events 12 to 14, switches 394 to 396) set variable 150 to 18 once
# all are right; Tyrogue, Hitmonchan, Hitmontop and Hitmonlee (events 39 to 42, switches 397 to 400) set it to 21.
module PokeAccess
  module RebornRubyTower
    LOWER = [[12, 394, :rba_rt_chimchar], [13, 395, :rba_rt_monferno], [14, 396, :rba_rt_infernape]]
    UPPER = [[39, 397, :rba_rt_tyrogue], [40, 398, :rba_rt_hitmonchan], [41, 400, :rba_rt_hitmontop],
             [42, 399, :rba_rt_hitmonlee]]

    # The tower's story step, variable 150.
    def self.step; $game_variables[150].to_i; end
  end
end

PokeAccess::Game.define("reborn") do
  tower = PokeAccess::RebornRubyTower
  [[:rba_ruby_lower, tower::LOWER, 18], [:rba_ruby_upper, tower::UPPER, 21]].each do |part, statues, goal|
    mechanic(:state, 310, :part => part) do
      auto
      statues.each do |id, switch, label|
        name id, label
        right_choice id, :takes => { :switch => switch, :to => true }
      end
      hint :rba_rt_hint
      active { tower.step < goal }
      solved { tower.step >= goal }
    end
  end
end
