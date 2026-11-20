# Silph Co. (maps 100 to 102, each holding several floors): pads with no sprite move the player to another part of a
# floor or to another map, and magnetic doors open with the two cards (S197 and S198). The president's office, where
# Giovanni is beaten (V182 at 9), is reached only through pads with the doors open. TOWARDS holds the pads that are the
# first step of a shortest way from their part of the building to the president's office, found on the maps'
# passability with the doors open and the pads and stairs as the ways between parts. CROSSING holds, for each map, the
# tiles of its pads that lead to another of the three: the move off them is told apart from the stairs by where it left.
module PokeAccess
  module AnilSilph
    PADS = { 100 => 11..14, 101 => 33..51, 102 => 30..40 }
    TOWARDS = { 100 => [11, 13], 101 => [34, 36, 42, 44, 45, 49, 51], 102 => [33, 34, 37, 38, 39] }
    CROSSING = {
      100 => [[28, 49], [20, 58], [28, 63], [46, 37]],
      101 => [[23, 9], [44, 31], [11, 31], [69, 20], [59, 22], [26, 43], [16, 45], [26, 54], [5, 65], [92, 45], [68, 65]],
      102 => [[7, 10], [43, 18], [61, 8], [61, 13], [89, 29], [16, 43], [5, 64], [64, 44], [78, 66]]
    }
    CARDS = [197, 198]
    PROGRESS = 182
    BEATEN = 9

    # The pad's name; with the assist and both cards, the ones that lead towards the president are told apart.
    def self.label(ev)
      towards = PokeAccess::Puzzles.assist? && CARDS.all? { |s| $game_switches[s] } &&
                TOWARDS[$game_map.map_id].include?(ev.id)
      towards ? :anil_silph_pad_towards : :anil_pad
    end
  end
end

PokeAccess::Game.define("anil") do
  silph = PokeAccess::AnilSilph
  silph::PADS.each do |map, pads|
    mechanic(:state, map) do
      auto
      name pads, lambda { |ev| silph.label(ev) }
      sent_back :anil_pad_sent, :events => pads
      silph::CROSSING.each do |from, tiles|
        tiles.each { |x, y| sent_back :anil_pad_sent, :maps => [from], :from => [x - 1, x + 1, y - 1, y + 1] }
      end
      hint :anil_silph_hint
      solved(nil) { $game_variables[silph::PROGRESS].to_i >= silph::BEATEN }
    end
  end
end
