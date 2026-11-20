# Edas' Monte Azur F-1 (map 81): eight rocks stand round an empty middle, and four of them, touched in turn (north, east,
# west, north-east), open the door to the crystal hall (event 15) and set switch 85. Variable 43 counts the right touches and
# any other touch sets it back, yet every rock answers alike, so the count is the assist's. The order comes from Jones and
# Indiana, two archaeologists elsewhere. In the Amber chapter (switch 177) the rocks are gone and the door stands open.
module PokeAccess
  module EdasAzureRocks
    MAP = 81
    ORDER = 43
    OPEN = 85
    CHAPTER = 177
    ROCKS = { 8 => :dir_n, 7 => :dir_e, 5 => :dir_o, 6 => :dir_ne, 10 => :dir_so, 16 => :dir_no, 17 => :dir_se,
              18 => :dir_s }
    STEPS = [8, 7, 5, 6]

    # Whether the door is open: the rocks' order done, or the rocks gone with the Amber chapter.
    def self.open?
      $game_switches[OPEN] || $game_switches[CHAPTER] ? true : false
    end

    # How many rocks stand touched in turn.
    def self.step
      [[$game_variables[ORDER].to_i, 0].max, STEPS.length].min
    end

    # A rock's name by where it stands round the middle.
    def self.rock_name(id)
      PokeAccess::I18n.t(:edas_rock, :dir => PokeAccess::I18n.t(ROCKS[id]))
    end
  end
end

PokeAccess::Game.define("edas") do
  rocks = PokeAccess::EdasAzureRocks
  mechanic(:state, rocks::MAP) do
    auto
    name rocks::ROCKS.keys, lambda { |ev| rocks.open? ? nil : rocks.rock_name(ev.id) }, :when => lambda { |_ev| !rocks.open? }
    count :edas_rock_steps, :var => rocks::ORDER, :of => rocks::STEPS.length, :hide_zero => true, :assist => true,
                            :reset => :edas_rock_reset
    solved { rocks.open? }
    rocks::STEPS.each_with_index do |id, i|
      phase lambda { !rocks.open? && rocks.step == i }, :hidden => right_way(id),
                                                        :hint => lambda { PokeAccess::I18n.t(:edas_next, :what => rocks.rock_name(id)) }
    end
  end
end
