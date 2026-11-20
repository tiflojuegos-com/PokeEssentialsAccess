# Republican Media HQ (map 377): the employee of the fourth floor (event 55) tells of the voice password and sets variable
# 230 to 5; a hidden switch on the floor before a bookcase of the third floor (event 50, a touch) turns the audio feeds on
# (switch 137); then the sprite-less terminal of the sixth floor (event 59) takes the voice password and opens the security
# door (switch 136).
module PokeAccess
  module SoulstonesMediaHq
    # The step left, as the assist's hint.
    def self.hint
      return :ss1_media_hint_employee if $game_variables[230].to_i < 5
      return :ss1_media_hint_feeds unless $game_switches[137]
      :ss1_media_hint_terminal
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  mechanic(:state, 377) do
    auto
    name 50, :ss1_media_bookcase_switch, :assist => true, :when => lambda { |_ev| !$game_switches[137] }
    name 59, :ss1_media_terminal, :when => lambda { |_ev| !$game_switches[136] }
    hint lambda { PokeAccess::SoulstonesMediaHq.hint }
    active { PokeAccess::Puzzles.assist? && !$game_switches[136] }
    solved { $game_switches[136] }
  end
end
