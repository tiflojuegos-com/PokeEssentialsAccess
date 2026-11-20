# Indus Ruins (map 320) and Indus Shrine (map 24), the quest "Ruined Riddles" (V86). Each ruin tablet asks a riddle as a menu in
# the message (V192): the option the page compares with adds to V86, any other sends a Bronzor. In the shrine, once Barry has
# spoken (V86 13), each Gliscor statue takes its own berry from the bag, the left one (event 7) a Yache, the middle one
# (event 8) a Chople and the right one (event 9) a Shuca, setting S232 to S234; Barry names them, left to right.
module PokeAccess
  module SS2Indus
    STATUES = { 7 => [:left, :YACHEBERRY, 232], 8 => [:middle, :CHOPLEBERRY, 233], 9 => [:right, :SHUCABERRY, 234] }

    # A statue's name by its place; with the assist, the berry it takes and whether the bag holds one.
    def self.statue(ev)
      side, berry, switch = STATUES[ev.id]
      t = PokeAccess::I18n
      name = t.t("ss2_pz_indus_statue_#{side}".to_sym)
      return name unless PokeAccess::Puzzles.assist? && !$game_switches[switch]
      held = ($bag.quantity(berry) > 0 rescue false)
      item = (GameData::Item.get(berry).name rescue berry.to_s)
      PokeAccess.sentences([name, t.t(held ? :ss2_pz_indus_berry_held : :ss2_pz_indus_berry_missing, :item => item)])
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  mechanic(:state, 320) do
    auto
    name(/^Riddle/, :ss2_pz_indus_riddle,
         :when => lambda { |ev| $game_variables[86] >= 1 && !$game_self_switches[[320, ev.id, "A"]] })
    right_choice(/^Riddle/, :takes => { :var => 86 })
  end

  mechanic(:state, 24) do
    auto
    name PokeAccess::SS2Indus::STATUES.keys, lambda { |ev| PokeAccess::SS2Indus.statue(ev) },
         :when => lambda { |ev| $game_variables[86] >= 13 && !$game_switches[PokeAccess::SS2Indus::STATUES[ev.id][2]] }
  end
end
