# Prison Puzzle (map 746, Cobalt's Serenity quest): nine by four cells joined by spikes of three colours, down while
# their switch is on (326 red, 327 green, 328 blue). A switch asks Lower or Raise: lowering a colour raises the one
# before it (red raises blue, green red, blue green), raising lowers the next. The final switch (EV81) sets 329.
module PokeAccess
  module AshenPrison
    MAP = 746
    RED = 326
    GREEN = 327
    BLUE = 328
    ALL_DOWN = 329
    COLOURS = { /\ARed / => :red, /\AGreen / => :green, /\ABlue / => :blue }
    SWITCHES = { :red => RED, :green => GREEN, :blue => BLUE }

    # Whether every spike is down for good.
    def self.done?
      $game_switches[ALL_DOWN] ? true : false
    end

    # Whether the right column is open: red and blue down, green up.
    def self.open?
      $game_switches[RED] && $game_switches[BLUE] && !$game_switches[GREEN] ? true : false
    end

    # The colour an event of the room wears, by its name, or nil.
    def self.colour(ev)
      COLOURS.each { |pattern, c| return c if ev.name.to_s =~ pattern }
      nil
    end

    # Whether a colour's spikes are down now.
    def self.down?(c)
      done? || $game_switches[SWITCHES[c]] ? true : false
    end

    # The branch a switch's right option takes as things stand: one that turns red on while it is off, else one that
    # turns blue on; nil once the column is open.
    def self.right_branch
      return nil if done? || open?
      { :switch => $game_switches[RED] ? BLUE : RED, :to => true }
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  prison = PokeAccess::AshenPrison
  mechanic(:state, prison::MAP) do
    auto
    name(/\A(Red|Green|Blue) Switch\z/, lambda { |ev| :"afh_prison_switch_#{prison.colour(ev)}" })
    name 81, :afh_prison_final
    name(/\A(Red|Green|Blue) Spikes\z/, lambda { |ev|
      c = prison.colour(ev)
      prison.down?(c) ? :"afh_prison_spikes_#{c}_down" : :"afh_prison_spikes_#{c}_up"
    }, :when => false)
    right_choice(/\A(Red|Green|Blue) Switch\z/, :takes => lambda { prison.right_branch })
    arrival_hint :afh_prison_rule
    phase lambda { PokeAccess::Puzzles.assist? && !prison.done? && !prison.open? }, :hint => :afh_prison_hint
    phase lambda { PokeAccess::Puzzles.assist? && !prison.done? && prison.open? }, :hint => :afh_prison_hint_open
    solved { prison.done? }
  end
end
