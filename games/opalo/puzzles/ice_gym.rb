# Opalo's gym of ice (map 67): a snowball pushed by walking into it, six pushes in turn (var 119, the ball ending on (26, 57)),
# and a room of 27 tiles each stepped on once (events 3 to 29, var 120). Leaving the map and coming back starts both over; the
# leader's medal (switch 382) ends the ball's rule on arriving and its line on the info key.
module PokeAccess
  # The six pushes of the snowball in order, as the direction it is pushed and how far it rolls.
  module OpaloIceBall
    PUSHES = [[:dir_up, 15], [:dir_left, 7], [:dir_down, 3], [:dir_left, 9], [:dir_down, 6], [:dir_right, 3]]
    VARIABLE = 119

    # The hint for the push to make now, or that all are made.
    def self.hint
      push = PUSHES[$game_variables[VARIABLE].to_i]
      return :op_g8_done unless push
      [:op_g8_next, { :dir => PokeAccess::I18n.t(push[0]), :n => push[1] }]
    end
  end
end

PokeAccess::Game.define("opalo") do
  mechanic(:state, 67, :part => :ball) do
    auto
    name 1, :op_g8_ball
    phase lambda { !$game_switches[354] }, :title => :op_g8_ball_title, :hint => lambda { PokeAccess::OpaloIceBall.hint },
          :progress => { :var => 119, :of => 6, :label => :op_g8_push, :announce => true },
          :track => { :event => 1, :label => :op_g8_ball, :goal => [26, 57, 26, 57], :goal_label => :op_g8_goal }
    arrival_hint :op_g8_rule, :once => true
    solved { $game_switches[382] }
  end

  mechanic(:grid, 67, :part => :tiles) do
    auto
    tiles 3..29, :self => "A", :label => :op_g8_tile, :count => :op_g8_tiles,
                 :words => { true => :op_g8_stepped, false => :op_g8_free }
    sent_back :op_g8_repeat, :to => [5, 50], :events => 3..29
    solved(:op_g8_tiles_solved) { $game_variables[120] >= 27 || $game_switches[382] }
  end
end
