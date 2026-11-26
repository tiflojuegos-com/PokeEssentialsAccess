# Well Temple sand pit room (map 686, Case Seventeen): four 2x2 pits (events 33, 36, 39, 44; no sprite). The pit due
# advances variable 254, a wrong one buzzes; both send them back (38, 8), but the upper right pit as the third step (254
# at 2) leaves them on it. The eighth step sends them below (7, 33), where the switch (event 46) adds one to 251.
module PokeAccess
  module AshenTemplePits
    MAP = 686
    STEP = 254
    SWITCH = 46
    PITS = { 33 => :afc_pit_ul, 36 => :afc_pit_ll, 39 => :afc_pit_lr, 44 => :afc_pit_ur }
    ORDER = [33, 39, 44, 36, 39, 33, 36, 44]
    LANDING = [38, 8]
    BELOW = [7, 33]

    # The steps taken so far.
    def self.step
      $game_variables[STEP].to_i
    end

    # Whether the switch below is pressed: its self switch A.
    def self.pressed?
      $game_self_switches[[MAP, SWITCH, "A"]] ? true : false
    end

    # A pit's name by its corner, marked as due to the assist.
    def self.label(ev)
      due = PokeAccess::Puzzles.assist? && !pressed? && step < ORDER.length && ORDER[step] == ev.id
      due ? [:afc_due, { :name => PokeAccess::I18n.t(PITS[ev.id]) }] : PITS[ev.id]
    end

    # The assist's line for a step: the pit due and how many come before it.
    def self.next_line(n)
      [:afc_pits_next, { :pit => PokeAccess::I18n.t(PITS[ORDER[n]]), :n => n + 1 }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  pits = PokeAccess::AshenTemplePits
  room = at(31, 45, 3, 13)
  below = at(1, 13, 27, 37)
  assist = lambda { PokeAccess::Puzzles.assist? && !PokeAccess::AshenTemplePits.pressed? }
  mechanic(:state, pits::MAP, :part => :pits) do
    name pits::PITS.keys, lambda { |ev| PokeAccess::AshenTemplePits.label(ev) }
    name pits::SWITCH, :afc_switch
    sent_back :afc_pit_fell, :to => pits::LANDING, :events => pits::PITS.keys
    sent_back :afc_pit_below, :to => pits::BELOW, :events => pits::PITS.keys
    pits::ORDER.each_index do |n|
      phase lambda { assist.call && room.call && PokeAccess::AshenTemplePits.step == n },
            :hint => lambda { PokeAccess::AshenTemplePits.next_line(n) }
    end
    phase lambda { assist.call && room.call && PokeAccess::AshenTemplePits.step >= 8 }, :hint => :afc_pits_any
    phase lambda { assist.call && below.call }, :hint => :afc_pits_press
    phase lambda { room.call && PokeAccess::AshenTemplePits.step < 8 && !PokeAccess::AshenTemplePits.pressed? },
          :title => :afc_pits_rule
    solved(nil, :quiet => true) { PokeAccess::AshenTemplePits.pressed? }
  end
end
