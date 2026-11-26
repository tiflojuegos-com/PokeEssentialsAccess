# Ashen Frost's Sableye chase in Fogdale Village (map 658, Case Sixteen): variable 238 says which of six Sableye (EV31
# to EV36) stands. Spoken to facing the right way each runs on and 238 grows; any other way sends it back. The first and
# last take any way; the sixth hands over the necklace (238 at 7).
module PokeAccess
  module AshenSableye
    MAP = 658
    STAGE = 238
    FIRST = 31
    # The stages that ask for a facing: the step from the Sableye to the tile to speak from, and the way to face.
    SIDES = { 2 => [1, 0, :afe_face_left], 3 => [-1, 0, :afe_face_right], 4 => [0, 1, :afe_face_up],
              5 => [-1, 0, :afe_face_right] }

    # The stage of the chase, 1 to 6 while a Sableye stands; anything else outside it.
    def self.stage
      $game_variables[STAGE].to_i
    end

    # Whether a Sableye stands to be chased.
    def self.chasing?
      stage.between?(1, 6)
    end

    # The line as a Sableye runs off: while the chase goes on, and as it starts.
    def self.ran
      chasing? ? :afe_sableye_ran : nil
    end

    # The assist's hint for the stage: the side to speak from, or any.
    def self.hint
      side = SIDES[stage]
      return :afe_sableye_any_side unless side
      [:afe_sableye_side, { :way => PokeAccess::I18n.t(side[2]) }]
    end

    # The tile the assist leads to for the stage, beside the Sableye standing now, or nil where any side does.
    def self.tile
      side = SIDES[stage]
      ev = side && $game_map.events[FIRST + stage - 1]
      ev ? [ev.x + side[0], ev.y + side[1]] : nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  sab = PokeAccess::AshenSableye
  mechanic(:state, sab::MAP, :part => :afe_sableye) do
    auto
    active { PokeAccess::Puzzles.assist? && sab.chasing? }
    watch :var => sab::STAGE, :say => lambda { sab.ran }
    phase lambda { sab.chasing? }, :hint => lambda { sab.hint }
    spot :at => lambda { sab.tile }, :label => :afe_sableye_spot, :assist => true, :onto => true,
         :when => lambda { sab.chasing? && !sab.tile.nil? }
  end
end
