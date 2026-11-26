# The Water Treatment Center's Water Grid: nine districts, each in four maps by its variable (256 to 264): 0 low and murky,
# 1 low and clear, 2 high and murky (the floating garbage is hopped across), 3 high and clear (surfed). Each room's
# computer lowers or raises its water. Variable 276 keeps the story: the infiltration with Titania from 4 to 22, the
# Swalot at 22, the cleaning at 23 and 24 (every district raised to 3, then Beryl's computer), the way out from 25 to 27
# (Beryl's north-east door, North Obsidia, Titania in the entrance room), done at 28; 29 is set later, outside.
module PokeAccess
  module RebornWTC
    VARS = { :nobs => 256, :cobs => 257, :opal => 258, :peridot => 259, :onyx => 260, :coral => 261,
             :lapis => 262, :jasper => 263, :beryl => 264 }
    NAMES = { :nobs => :rbb_wtc_nobs, :cobs => :rbb_wtc_cobs, :opal => :rbb_wtc_opal, :peridot => :rbb_wtc_peridot,
              :onyx => :rbb_wtc_onyx, :coral => :rbb_wtc_coral, :lapis => :rbb_wtc_lapis, :jasper => :rbb_wtc_jasper,
              :beryl => :rbb_wtc_beryl }
    LEVELS = [:rbb_wtc_level0, :rbb_wtc_level1, :rbb_wtc_level2, :rbb_wtc_level3]
    ORDER = [:opal, :nobs, :cobs, :onyx, :peridot, :jasper, :lapis, :beryl, :coral]
    ROOMS = { 470 => [:nobs, 18], 479 => [:nobs, 32], 480 => [:nobs, 24], 497 => [:nobs, 28],
              469 => [:cobs, 24], 481 => [:cobs, 45], 482 => [:cobs, 29], 498 => [:cobs, 29],
              473 => [:opal, 16], 487 => [:opal, 22], 488 => [:opal, 20], 501 => [:opal, 20],
              474 => [:peridot, 19], 489 => [:peridot, 34], 490 => [:peridot, 28], 502 => [:peridot, 28],
              471 => [:onyx, 18], 483 => [:onyx, 38], 484 => [:onyx, 20], 499 => [:onyx, 30],
              472 => [:coral, 33], 485 => [:coral, 32], 486 => [:coral, 24], 500 => [:coral, 24],
              468 => [:lapis, 24], 491 => [:lapis, 38], 492 => [:lapis, 28], 503 => [:lapis, 28],
              475 => [:jasper, 17], 493 => [:jasper, 34], 494 => [:jasper, 26], 504 => [:jasper, 26],
              476 => [:beryl, 20], 495 => [:beryl, 32], 496 => [:beryl, 26], 505 => [:beryl, 26] }
    STAGE_HINTS = { 4 => :rbb_wtc_h4, 5 => :rbb_wtc_h5, 6 => :rbb_wtc_h6, 7 => :rbb_wtc_h7, 8 => :rbb_wtc_h7,
                    9 => :rbb_wtc_h9, 10 => :rbb_wtc_h9, 11 => :rbb_wtc_h11, 12 => :rbb_wtc_h11, 13 => :rbb_wtc_h13,
                    14 => :rbb_wtc_h14, 15 => :rbb_wtc_h16, 16 => :rbb_wtc_h16, 17 => :rbb_wtc_h16, 18 => :rbb_wtc_h18,
                    19 => :rbb_wtc_h19, 20 => :rbb_wtc_h20, 21 => :rbb_wtc_h21, 22 => :rbb_wtc_h22,
                    25 => :rbb_wtc_h25, 26 => :rbb_wtc_h26, 27 => :rbb_wtc_h27 }

    def self.stage
      $game_variables[276].to_i
    end

    def self.level(d)
      $game_variables[VARS[d]].to_i
    end

    def self.district_name(d)
      PokeAccess::I18n.t(NAMES[d])
    end

    def self.murky
      ORDER.reject { |d| level(d) == 3 }
    end

    # From the infiltration to Titania's word in the entrance room, which sets 28.
    def self.chapter?
      stage >= 4 && stage < 28
    end

    # The room's water as drawn: high or low, murky or clear.
    def self.water_line
      room = ROOMS[$game_map.map_id]
      return nil unless room && chapter?
      [:rbb_wtc_water, { :level => PokeAccess::I18n.t(LEVELS[level(room[0])] || LEVELS[0]) }]
    end

    # The next step for the live stage; while cleaning, the first district not yet clear and what its computer needs.
    def self.hint
      s = stage
      if s == 23 || s == 24
        left = murky
        return :rbb_wtc_h24 if left.empty?
        d = left.first
        key = level(d) == 2 ? :rbb_wtc_clean_lower : :rbb_wtc_clean_raise
        return [key, { :name => district_name(d), :left => left.map { |x| district_name(x) }.join(", ") }]
      end
      STAGE_HINTS[s]
    end
  end
end

PokeAccess::Game.define("reborn") do
  wtc = PokeAccess::RebornWTC
  wtc::ROOMS.each do |map_id, room|
    mechanic(:state, map_id, :part => :water_grid) do
      auto
      name room[1], :rbb_wtc_computer
      name(/\Ablock\z/, :rbb_wtc_garbage)
      arrival_hint lambda { wtc.water_line }
      count :rbb_wtc_clean, :value => lambda { 9 - wtc.murky.size }, :of => 9, :assist => true, :announce => false,
                            :reset => false, :hide_zero => true
      active { PokeAccess::Puzzles.assist? && wtc.chapter? }
      hint lambda { wtc.hint }
    end
  end
end
