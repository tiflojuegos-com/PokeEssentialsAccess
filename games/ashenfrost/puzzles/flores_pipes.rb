# Ashen Frost's pool room in the Flores Mansion (map 648): sixteen pipe tiles turned by four switches with no graphic in
# row 7, one variable each (223 to 226), from position 1 to 4 and round. Common event 136 shuffles them on entry; the
# parallel EV22 sets switch 258 (the ladder upstairs) once all four stand at 1.
module PokeAccess
  module AshenPipes
    MAP = 648
    SOLVED = 258
    # Each switch: its event, its variable and the key of its name.
    SWITCHES = [[18, 223, :afe_pipe_red], [19, 224, :afe_pipe_orange], [20, 225, :afe_pipe_yellow], [21, 226, :afe_pipe_green]]

    # Whether the pipes are joined: the game has set the switch its checker sets.
    def self.solved?
      $game_switches[SOLVED] ? true : false
    end

    # How many presses a switch still needs to come round to position 1.
    def self.presses(var)
      value = $game_variables[var].to_i
      value.between?(2, 4) ? 5 - value : 0
    end

    # The assist's hint: the presses each switch still needs.
    def self.hint
      t = PokeAccess::I18n
      parts = SWITCHES.map { |_ev, var, label| t.t(:afe_pipe_presses, :switch => t.t(label), :n => presses(var)) }
      t.t(:afe_pipes_hint, :list => parts.join(", "))
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  pipes = PokeAccess::AshenPipes
  mechanic(:state, pipes::MAP, :part => :afe_pipes) do
    arrival_hint :afe_pipes_rule
    solved(nil, :quiet => true) { pipes.solved? }
    phase lambda { !pipes.solved? }, :hint => lambda { pipes.hint },
          :values => pipes::SWITCHES.map { |ev, var, label| { :var => var, :label => label, :event => ev } }
  end
end
