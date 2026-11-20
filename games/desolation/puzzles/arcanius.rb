# Arcanius. Settler's Ruins (map 98): eight shining finds add to variable 257 (six one each, events 52 and 55 two), and
# at 10 the ghosts come out and the story goes on. Visinite Current (map 470): three crystals (37, 38, 39) shatter once the
# Fossil Quest takes variable 203 to 8, each leaving a glowing fragment (switches 781, 780, 782) by a light. The Secret
# Lair of Overgrown Woods (map 473): the box with bars (event 54) hides a switch on its roof (switch 740). The Secret Lab
# (map 481): once variable 234 is 1, stepping on the purple circle (event 41's last page, at 30,24) with an Umbreon in the
# party takes the player to the room with the Black Piece.
#
# The runaway Skitty (variable 210) flees from spot to spot as the player steps on the tile by it, with no sprite: Fairbale
# Woods (map 455) events 9 and 5, Visinite Current events 42, 45, 48 and 51; the Skitty itself, drawn, waits by each one.
# The chase ends through the way into Fairbale Town (map 468, event 4), an exit the lists give already.
module PokeAccess
  module DesolationArcanius
    FRAGMENTS = [[37, 781], [38, 780], [39, 782]]
    # The tile that scares the Skitty on, by map: [event, value of variable 210 it answers to].
    SKITTY_STEPS = { 455 => [[9, 1], [5, 2]], 470 => [[42, 3], [45, 4], [48, 5], [51, 6]] }
    SKITTY_SPRITES = { 455 => [8, 6], 470 => [40, 47, 50] }

    # True while a find of the ruins still shines.
    def self.shining?(ev)
      ev.character_name.to_s == "sparkle"
    end

    # A Visinite crystal's name: a glowing fragment once the quest has shattered it and until it is taken.
    def self.crystal(switch)
      $game_variables[203].to_i >= 8 && !$game_switches[switch] ? :deso_visinite_fragment : :deso_visinite_crystal
    end

    # The purple circle's name, while its page is the one that runs.
    def self.circle(_ev)
      $game_variables[234].to_i >= 1 ? :deso_lab_circle : nil
    end
  end
end

PokeAccess::Game.define("desolation") do
  arc = PokeAccess::DesolationArcanius
  mechanic(:state, 98) do
    auto
    name [42, 46, 47, 49, 50, 52, 54, 55], :deso_ruins_find, :when => lambda { |ev| arc.shining?(ev) }
    count :deso_ruins_finds, :var => 257, :of => 10, :assist => true
    hint :deso_ruins_hint
    solved { $game_variables[257].to_i >= 10 }
  end
  mechanic(:state, 470, :part => :fragments) do
    auto
    arc::FRAGMENTS.each { |ev, s| name ev, lambda { |_e| arc.crystal(s) } }
    count :deso_visinite_fragments, :switches => [780, 781, 782], :assist => true, :hide_zero => true
    hint :deso_visinite_hint
    active { $game_variables[203].to_i >= 8 && ![780, 781, 782].all? { |s| $game_switches[s] } }
  end
  mechanic(:state, 473) do
    auto
    name 54, :deso_lair_box, :when => lambda { |_ev| !$game_switches[740] }
    right_choice 54, :takes => { :switch => 740 }
  end
  mechanic(:state, 481) do
    auto
    name 41, lambda { |ev| arc.circle(ev) }, :when => lambda { |_ev| $game_variables[234].to_i >= 1 }
    hint :deso_lab_circle_hint
    active { $game_variables[234].to_i >= 1 }
  end
  arc::SKITTY_STEPS.each do |map, steps|
    mechanic(:state, map, :part => :skitty) do
      auto
      (arc::SKITTY_SPRITES[map] || []).each { |id| name id, :deso_skitty_runaway }
      steps.each do |ev, value|
        spot(:event => ev, :label => :deso_skitty_step, :assist => true, :onto => true,
             :when => lambda { $game_variables[210].to_i == value })
      end
      hint :deso_skitty_hint
      active { $game_variables[210].to_i >= 1 && $game_variables[210].to_i < 8 }
    end
  end
end
