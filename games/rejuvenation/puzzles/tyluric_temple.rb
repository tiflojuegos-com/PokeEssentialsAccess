# Tyluric Temple (map 179), once the mural sets variable 719 to 5: four whirlwinds (events 64 to 67) step variable 515
# in the order 64, 65, 66, 67, 64, 67 (a wrong one drops it to 1), and the last sets 719 to 6. Five deflectors (events
# 11, 12, 13, 16, 17) steer the ball of event 14: all set but the fourth takes it to the mural, and 719 goes to 7.
module PokeAccess
  module RejuvTyluricTemple
    WHIRLS = { 64 => :rjd_ty_whirl_se, 65 => :rjd_ty_whirl_sw, 66 => :rjd_ty_whirl_ne, 67 => :rjd_ty_whirl_nw }
    ORDER = { 1 => 64, 2 => 65, 3 => 66, 4 => 67, 5 => 64, 6 => 67 }
    DEFLECTORS = [[11, 502, 1], [12, 503, 1], [13, 504, 1], [16, 505, 0], [17, 506, 1]]

    # The quest's step, variable 719.
    def self.step; $game_variables[719].to_i; end

    # With the assist, the whirlwind to step on next, from variable 515.
    def self.next_whirl
      id = ORDER[$game_variables[515].to_i]
      id ? [:rjd_ty_whirl_next, { :name => PokeAccess::I18n.t(WHIRLS[id]) }] : nil
    end

    # A deflector's name: its place along the ball's way and whether it is set.
    def self.deflector(ev)
      DEFLECTORS.each_with_index do |d, i|
        next unless d[0] == ev.id
        return [$game_variables[d[1]].to_i == 1 ? :rjd_ty_deflector_on : :rjd_ty_deflector_off, { :n => i + 1 }]
      end
      nil
    end

    # With the assist, the deflectors still to switch, or the launch once they all stand right.
    def self.deflector_hint
      wrong = []
      DEFLECTORS.each_with_index { |d, i| wrong.push(i + 1) if $game_variables[d[1]].to_i != d[2] }
      return :rjd_ty_deflect_go if wrong.empty?
      [:rjd_ty_deflect_hint, { :list => wrong.join(", ") }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  temple = PokeAccess::RejuvTyluricTemple
  mechanic(:state, 179, :part => :whirlwinds) do
    auto
    temple::WHIRLS.each { |id, label| name id, label }
    avoid temple::WHIRLS.keys
    hint lambda { temple.next_whirl }
    active { temple.step == 5 }
    solved { temple.step >= 6 }
  end
  mechanic(:state, 179, :part => :deflectors) do
    auto
    name temple::DEFLECTORS.map { |d| d[0] }, lambda { |ev| temple.deflector(ev) }
    name 14, :rjd_ty_launch
    avoid 14
    hint lambda { temple.deflector_hint }
    active { temple.step == 6 }
    solved { temple.step >= 7 }
  end
end
