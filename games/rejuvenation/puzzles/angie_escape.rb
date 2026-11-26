# The run from Angie on the Battlefield of the Gods (map 346), while variable 772 is 1: a target (event 71) drops on
# the player's tile and, a quarter of a second later, hurts them if they still stand there (event 58, hits in variable
# 505). The countdown running out or the third hit ends the run (772 to 2).
module PokeAccess
  module RejuvAngieEscape
    # True while the run lasts.
    def self.running?
      $game_variables[772].to_i == 1
    end

    # The hits taken in this run, at most the three that end it.
    def self.hits
      running? ? [$game_variables[505].to_i, 3].min : 0
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  run = PokeAccess::RejuvAngieEscape
  mechanic(:state, 346, :part => :escape) do
    auto
    phase lambda { run.running? }, :title => :rjg_an_escape, :hint => :rjg_an_escape_hint
    count :rjg_an_hits, :value => lambda { run.hits }, :of => 3, :hide_zero => true, :assist => true
    active { run.running? }
  end
end
