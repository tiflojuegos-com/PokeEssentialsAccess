# Vitro's gym of Blackthorn (map 86), beside rock_holes: the boulder (event 12) that falls into the hole at (28, 12) fills the gap
# the left room hops across, and with it the way to Debora. The boulder is tracked until that hole or the one at (37, 15) is filled.
PokeAccess::Game.define("vitro") do
  mechanic(:state, 86, :part => :carry) do
    phase lambda { !$game_switches[89] && !$game_switches[90] }, :title => :vitro_blackthorn_title, :quiet => true,
          :hint => :vitro_blackthorn_hint,
          :track => { :event => 12, :label => :vitro_blackthorn_rock, :goal => [28, 12, 28, 12], :goal_label => :vitro_blackthorn_hole }
    solved { $game_switches[11] }
  end
end
