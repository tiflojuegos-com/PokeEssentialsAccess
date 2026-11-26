# The Aerodactyl's shadow in the Fossil Lab (Dark) (map 802), variable 399: a spot with no graphic below the first eyes
# (event 18, under 17) gives Truffles the scent (399 to 2); the eyes then show on the west (event 19, 399 to 3) and last
# in the north-east (event 22), the friend that joins the party (399 to 4).
module PokeAccess
  module AshenFossilLab
    MAP = 802
    STEPS = [[18, :afg_fl_step1], [19, :afg_fl_step2], [22, :afg_fl_step3]]

    # The quest's stage on this map: 0 before the scent, then one per eyes, 3 for the last.
    def self.stage
      [[$game_variables[399].to_i - 1, 0].max, 3].min
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  fl = PokeAccess::AshenFossilLab
  mechanic(:state, fl::MAP, :part => :shadow) do
    auto
    name [17, 19, 22], :afg_fl_eyes
    name 18, :afg_fl_scent, :assist => true
    fl::STEPS.each_with_index do |step, k|
      phase lambda { PokeAccess::Puzzles.assist? && fl.stage == k },
            :hint => step[1], :spots => [{ :event => step[0], :label => k == 0 ? :afg_fl_scent : :afg_fl_eyes }]
    end
    solved(nil, :quiet => true) { $game_variables[399].to_i >= 4 }
  end
end
