# The Regi's New World (map 825): Danielle reads each tablet's ritual as a game of Simon Says (door 576 at 4, Regirock's
# boulders 579 at 2, Registeel's levers 581 at 2), each order checked as read (variable 744 runs the game); talking to
# her offers Opt Out. Regice's ice (580 at 2): five cracks, each broken by sliding onto it the way the order says.
module PokeAccess
  module RebornRegi
    MAP = 825
    DOOR = 576
    ROCK = 579
    STEEL = 581
    ICE = 580
    STEP = 577
    FAILED = 1377
    DANIELLE = { 1 => DOOR, 81 => ROCK, 104 => STEEL }
    LEVERS = { 105 => [582, :rbi_regi_north], 106 => [583, :rbi_regi_east], 107 => [584, :rbi_regi_west],
               108 => [585, :rbi_regi_south] }
    LEVER_STATES = { 0 => :rbi_regi_center, 1 => :rbi_regi_left, 2 => :rbi_regi_right }
    GREY = 82
    BROWN = 83
    CRACKS = { 88 => 1379, 89 => 1380, 90 => 1381, 91 => 1382, 92 => 1383 }
    ICE_DANIELLE = 87
    ICE_PLAN = { 1 => [[28, 22], :rbi_ice_step1, 0], 2 => [[22, 21], :rbi_ice_step2, 1], 4 => [[28, 20], :rbi_ice_step3, 2],
                 6 => [[26, 26], :rbi_ice_step4, 3], 8 => [[23, 24], :rbi_ice_step5, 4] }

    # The name of a lever: which one, as Danielle calls it, and the way it is turned.
    def self.lever_label(ev)
      var, side = LEVERS[ev.id]
      state = LEVER_STATES[$game_variables[var].to_i] || :rbi_regi_center
      [:rbi_regi_lever, { :side => PokeAccess::I18n.t(side), :state => PokeAccess::I18n.t(state) }]
    end

    # True while one of Danielle's three Simon Says rituals waits to be played or runs.
    def self.ritual_waiting?
      $game_variables[DOOR] == 4 || $game_variables[ROCK] == 2 || $game_variables[STEEL] == 2
    end

    # True when a crack of the ice has broken.
    def self.broken?(id)
      $game_switches[CRACKS[id]] ? true : false
    end

    # The step of the ice's plan due now, as [start tile, hint, cracks broken before it], or nil outside it: Danielle
    # has told the order (her self switch B) and the count waits for a slide.
    def self.ice_step
      return nil unless $game_variables[ICE] == 2 && $game_self_switches[[MAP, ICE_DANIELLE, "B"]]
      ICE_PLAN[$game_variables[STEP].to_i]
    end

    # The tile the next slide starts from, while the plan holds.
    def self.ice_start
      step = ice_step
      step && !ice_spoilt? ? step[0] : nil
    end

    # True when the ritual cannot end as it stands: failed, or a crack broken the wrong way.
    def self.ice_spoilt?
      step = ice_step
      return false unless step
      $game_switches[FAILED] || CRACKS.keys.count { |id| broken?(id) } > step[2]
    end

    # With the assist, the next slide, or the reset once the ice is spoilt.
    def self.ice_hint
      step = ice_step
      return nil unless step
      ice_spoilt? ? :rbi_ice_reset : step[1]
    end
  end
end

PokeAccess::Game.define("reborn") do
  regi = PokeAccess::RebornRegi
  mechanic(:state, regi::MAP, :part => :rituals) do
    auto
    name regi::LEVERS.keys, lambda { |ev| regi.lever_label(ev) }
    name regi::GREY, :rbi_regi_grey_rock
    name regi::BROWN, :rbi_regi_brown_rock
    spot :at => [47, 89], :label => :rbi_regi_rock, :when => lambda { $game_variables[regi::DOOR] == 4 }
    spot :at => [5, 65], :label => :rbi_regi_tallest, :when => lambda { $game_variables[regi::ROCK] == 2 }
    spot :at => [9, 66], :label => :rbi_regi_center_stone, :when => lambda { $game_variables[regi::ROCK] == 2 }
    regi::DANIELLE.each { |id, var| right_choice id, :takes => { :var => var } }
    hint :rbi_regi_ritual_hint
    info { nil }
    active { PokeAccess::Puzzles.assist? && regi.ritual_waiting? }
  end
  mechanic(:state, regi::MAP, :part => :regice) do
    auto
    name regi::CRACKS.keys, lambda { |ev| regi.broken?(ev.id) ? :rbi_ice_crack_broken : :rbi_ice_crack }
    avoid regi::CRACKS.keys
    spot :at => lambda { regi.ice_start }, :label => :rbi_ice_start, :assist => true, :onto => true,
         :when => lambda { !regi.ice_start.nil? }
    hint lambda { regi.ice_hint }
    info { nil }
    active { PokeAccess::Puzzles.assist? && !regi.ice_step.nil? }
    solved(nil, :quiet => true) { $game_variables[regi::ICE] >= 3 }
  end
end
