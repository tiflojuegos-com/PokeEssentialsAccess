# The Trick Master's house on Route 110: the lobby (map 99), whose notes make a spark flash on the furniture he hides in
# (events 11 and 7, no graphic, which the note switches on); the garden (map 108), whose door opens once switch 2154 is on,
# set by the scroll of event 13 or, for a player who picked Team Aqua, by the Aqua guard of Route 109 (map 39, event 54);
# and the dark rooms (map 107), whose three doors take a six colour code (variables 1045 to 1047).
module PokeAccess
  module HoennTrickHouse
    # The two columns of each door's code, by the event of its panel.
    def self.codes
      { 1 => ["BBR", "BGY"], 7 => ["RRG", "BBR"], 8 => ["YYG", "GRG"] }
    end

    # The door each panel opens.
    def self.doors
      { 1 => 5, 7 => 6, 8 => 9 }
    end

    # The colour names of a string of letters, as the code screen says them.
    def self.colors(letters)
      letters.split(//).map { |c| PokeAccess::IF2ColorDoor.color_name(c) }.join(", ")
    end

    # What the assist says at a door's panel, by the columns of the screen; nil once that door is open.
    def self.answer(ev)
      code = codes[ev.id]
      return nil if code.nil? || $game_self_switches[[107, doors[ev.id], "A"]]
      cols = { :left => colors(code[0]), :right => colors(code[1]) }
      [:puzzle_answer, { :a => PokeAccess::I18n.t(:if_ho_code_cols, cols) }]
    end

    # True while the Trick Master has not gone on his journey (variable 1043 below 2).
    def self.here?
      $game_variables[1043].to_i < 2
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  mechanic(:state, 99) do
    auto
    name [7, 11], :if_ho_dresser
    on_reach 4, { :text => 1 }, lambda { PokeAccess::HoennTrickHouse.here? ? :if_ho_spark : nil }
    info { :if_ho_trick_info }
    active { PokeAccess::Puzzles.assist? && PokeAccess::HoennTrickHouse.here? }
    hint :if_ho_dresser_hint
  end

  mechanic(:state, 108) do
    auto
    name 13, :if_ho_scroll
    name 19, :if_ho_code_door
    watch :switch => 2154, :label => :if_ho_code, :on => :if_ho_code_found, :off => :if_ho_code_missing
    hint lambda { $game_switches[2154] ? :if_ho_garden_hint_door : :if_ho_garden_hint }
    arrival_hint lambda { PokeAccess::Puzzles.assist? && !$game_switches[2154] ? :if_ho_garden_rule : nil }
    solved { $game_self_switches[[108, 19, "A"]] }
  end

  mechanic(:state, 107) do
    auto
    name [1, 7, 8], :if_ho_panel, :numbered => true
    name [5, 6, 9], :if_ho_door, :numbered => true
    on_use [1, 7, 8], lambda { |ev| PokeAccess::HoennTrickHouse.answer(ev) }, :assist => true
    sent_back :if_ho_wrong_code, :forced => true, :events => [1, 7, 8]
    arrival_hint :if_ho_codes_rule
    solved { PokeAccess::HoennTrickHouse.doors.values.all? { |d| $game_self_switches[[107, d, "A"]] } }
  end
end
