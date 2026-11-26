# Lapis Gym (map 182): seven computers raise or lower sets of bookcase blocks (switches 140 to 146). The game's guide
# marks the floor before the next one (variable 319, step 320); a wrong computer sets both to -1 and event 112 starts
# over. The last computer, event 91, is reached from the side room (map 176); with all on, event 105 sets switch 150.
module PokeAccess
  module RebornLapisGym
    COMPUTERS = { 87 => 140, 62 => 141, 55 => 142, 69 => 143, 91 => 144, 17 => 145, 18 => 146 }
    MARKS = { 1 => 87, 2 => 62, 3 => 55, 4 => 69, 5 => 91, 6 => 17, 7 => 18 }
    DONE = 150
    LEDGE = 91
    END_TILE = 105
    RESET_MAN = 112

    # True once the way to Shelly is open.
    def self.done?; $game_switches[DONE] ? true : false; end

    # True when every computer is on.
    def self.all_on?; COMPUTERS.values.all? { |s| $game_switches[s] }; end

    # True when the game's guide lost its way, a wrong computer used.
    def self.lost?; $game_variables[320].to_i < 0 && !all_on?; end

    # The computer the game's guide marks now, nil with no mark.
    def self.marked; MARKS[$game_variables[319].to_i]; end

    # A computer's name: on or off, and marked when the guide points at it.
    def self.label(ev)
      state = PokeAccess::I18n.t($game_switches[COMPUTERS[ev.id]] ? :rba_lg_on : :rba_lg_off)
      return [:rba_lg_computer_marked, { :state => state }] if marked == ev.id && !done?
      [:rba_lg_computer, { :state => state }]
    end

    # With the assist, what to do next.
    def self.hint
      return nil if done?
      return :rba_lg_hint_walk if all_on?
      return :rba_lg_hint_reset if lost?
      marked == LEDGE ? :rba_lg_hint_ledge : :rba_lg_hint_marked
    end
  end
end

PokeAccess::Game.define("reborn") do
  gym = PokeAccess::RebornLapisGym
  mechanic(:state, 182) do
    auto
    name gym::COMPUTERS.keys, lambda { |ev| gym.label(ev) }
    name gym::RESET_MAN, :rba_lg_reset_man, :assist => true, :when => lambda { |_ev| gym.lost? && !gym.done? }
    spot :event => gym::END_TILE, :label => :rba_lg_end, :assist => true, :onto => true,
         :when => lambda { gym.all_on? && !gym.done? }
    hint lambda { gym.hint }
    active { !gym.done? }
    solved { gym.done? }
  end
end
