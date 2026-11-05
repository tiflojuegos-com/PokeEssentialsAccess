# The room of symmetry of the Abandoned Mansion (map 202): the right side must be made to match the left in seven details,
# each behind a switch (240 picture, 241 candles, 242 books, 243 plate, 245 flower put, 246 bin in place, 247 sign in the
# bin). Most of the objects are events without a graphic or a name. The game's own check of the details (a parallel event of
# the map) says that something was unlocked and turns its self switch A on: that ends the rule and the details on the info key.
module PokeAccess
  module RealideaMansion
    MAP = 202
    DETAILS = [240, 241, 242, 243, 245, 246, 247]
    CHECK = 34

    # True once the game's check has found the details matched and unlocked what they hide.
    def self.unlocked?
      $game_self_switches[[MAP, CHECK, "A"]] ? true : false
    end

    # A name that follows a switch: on_key while it is on, off_key while it is off.
    def self.follows(switch, on_key, off_key)
      lambda { |_ev| $game_switches[switch] ? on_key : off_key }
    end

    # The name of a flowerpot: how many flowers it holds before (from) and after (to) its switch.
    def self.pot(switch, from, to)
      lambda { |_ev| [:rea_mansion_pot, { :n => $game_switches[switch] ? to : from }] }
    end
  end
end

PokeAccess::Game.define("realidea") do
  mansion = PokeAccess::RealideaMansion
  mechanic(:state, mansion::MAP) do
    auto
    name [7, 12], mansion.follows(240, :rea_mansion_picture_on, :rea_mansion_picture_off)
    name [13, 14], :rea_mansion_picture_on
    name [17, 18], mansion.follows(241, :rea_mansion_candles_off, :rea_mansion_candles_on)
    name [19, 20], :rea_mansion_candles_off
    name [23, 24], mansion.follows(242, :rea_mansion_books_on, :rea_mansion_books_off)
    name [21, 22], :rea_mansion_books_on
    name 29, mansion.follows(243, :rea_mansion_plate_broken, :rea_mansion_plate_whole)
    name 30, :rea_mansion_plate_broken
    name 31, mansion.pot(244, 5, 4)
    name 32, mansion.pot(245, 3, 4)
    name 1, :rea_mansion_bin_papers
    name 2, :rea_mansion_bin
    name 37, :rea_mansion_bin_set
    name 6, :rea_mansion_sign
    count :rea_mansion_details, :switches => mansion::DETAILS, :assist => true
    arrival_hint :rea_mansion_rule
    solved { mansion.unlocked? }
    hint :rea_mansion_hint
  end
end
