# Each episode opens with a title card (common event 5): the picture EpisodeTitel<n> (variable 75) paints the number and
# title, then the picture "start" paints PRESS ENTER and waits for confirm. TITLES are the words each picture paints, in
# the game's English; the title interrupts, the prompt is queued behind it.
module PokeAccess
  module SlldEpisodes
    TITLES = {
      1 => "Episode 1: Stranded in Rikoto!",
      2 => "Episode 2: Bad Cheeping Budcheep!",
      3 => "Episode 3: A new Hamstar is Born!",
      4 => "Episode 4: Forest Heroes!",
      5 => "Episode 5: Holes 'n Memories!",
      6 => "Episode 6: Serpentine Gym - A Storm of Thorns!",
      7 => "Episode 7: A Tangle of Troubles in Dullfern Forst!",
      8 => "Episode 8: A Lesson in the Art of Chirping!",
      9 => "Episode 9: Deep Water Rescue Mission!",
      10 => "Episode 10: Thief Chase in Blackleaf Woods!",
      11 => "Episode 11: Straw Hat Platyplat!",
      12 => "Episode 12: Crestlight Gym - Twilight Fights!",
      13 => "Episode 13: Psychic-Type Contest: Moonky Business!"
    }
    PROMPT = "Press Enter"

    # Says what a picture just shown paints, if it is a title card or its prompt.
    def self.shown(name)
      n = name.to_s
      if n =~ /\AEpisodeTitel(\d+)\z/
        title = TITLES[$1.to_i]
        PokeAccess.speak(title, true) if title
      elsif n == "start"
        PokeAccess.speak(PROMPT, false)
      end
    end
  end
end

PokeAccess::Game.define("slld_anime") do
  on_picture { |name, _args| PokeAccess::SlldEpisodes.shown(name) }
end
