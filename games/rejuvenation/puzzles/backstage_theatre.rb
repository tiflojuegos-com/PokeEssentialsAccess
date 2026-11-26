# The Backstage Theatre of Goldenleaf's gym (map 401): a chain along variable 370, from 0 on the way in to 23 (the End
# Door). Lit torches (tiles 1812 and 1814; 1811 is a cold brazier) mark the door or floor that moves the chain on; the
# others send the player back to 0. With the assist the right way is listed per value and walks avoid the setbacks.
module PokeAccess
  module RejuvTheatre
    LIT = [1812, 1814]
    TORCHES = [3, 11, 13, 16, 17, 23, 26, 28, 36, 39, 46, 48, 56, 59]
    # V370 => the events that move it on.
    CHAIN = {
      0 => [8], 1 => [9], 2 => [10], 3 => [12], 4 => [14], 6 => [18, 19, 20], 7 => [21, 22], 8 => [15], 9 => [8],
      10 => [10, 27], 11 => [29], 12 => [14], 13 => [18, 19, 20], 14 => [33, 35, 37, 38], 15 => [42], 16 => [47],
      17 => [49], 18 => [40], 19 => [14], 20 => [57], 21 => [60]
    }
    # Steps with a word of their own besides the right way.
    HINTS = { 10 => :rj_theatre_hint_door, 14 => :rj_theatre_hint_dusclops }
    # The doors and floors that set the chain back, each with the values of 370 its live page does it from.
    TRAPS = {
      8 => [2..8, 11..23], 12 => [0..2, 4..23], 14 => [0..3, 5..11], 15 => [0..7, 9..23], 21 => [0..6, 14..23],
      22 => [0..6, 14..23], 29 => [17..23], 33 => [15..23], 35 => [15..23], 40 => [0..17], 47 => [0..15, 17..23],
      51 => [0..23], 57 => [21..23], 61 => [0..6], 74 => [0..16], 75 => [0..16], 79 => [11..23], 82 => [0..6],
      86 => [0..6], 91 => [0..18], 92 => [0..18]
    }

    def self.value
      $game_variables[370].to_i
    end

    # True when the event would set the chain back from where it stands.
    def self.trap?(ev)
      v = value
      (TRAPS[ev.id] || []).any? { |r| r.include?(v) }
    end

    # A torch's name as it burns now; nil where its page shows none.
    def self.torch_label(ev)
      tile = (ev.tile_id rescue 0).to_i
      return nil if tile <= 0
      LIT.include?(tile) ? :rj_theatre_torch_lit : :rj_theatre_torch_out
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  theatre = PokeAccess::RejuvTheatre
  mechanic(:state, 401, :part => :torches) do
    auto
    name theatre::TORCHES, lambda { |ev| theatre.torch_label(ev) }
    avoid lambda { |ev| theatre.trap?(ev) }, :assist => true
    theatre::CHAIN.each do |v, events|
      opts = { :hidden => right_way(*events) }
      opts[:hint] = theatre::HINTS[v] || :rj_theatre_hint
      opts[:title] = :rj_theatre_start if v == 0
      phase lambda { theatre.value == v && (v == 0 || PokeAccess::Puzzles.assist?) }, opts
    end
    solved { theatre.value >= 23 }
  end
end
