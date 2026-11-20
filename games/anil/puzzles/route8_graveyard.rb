# Route 8's graveyard (map 71): three tombs with no sprite are read in order, EV17, then EV18 (EV20 beside it does the
# same and is left out), then EV34; V176 counts the right ones and a wrong one clears them with no word. At 3 an autorun
# event plays a sound and sets S119, which shows a TM on EV36. The order is the picture mapaCemen, shown by the witch
# Marian in Celadon (map 76) once beaten (S115).
module PokeAccess
  module AnilGraveyard
    MAP = 71
    ORDER = { 17 => 1, 18 => 2, 34 => 3 }
    TWIN = 20
    SEEN = 115
    STEP = 176
    DONE = 119

    # A tomb's name: with its number in the picture once the player has seen it, or with the assist.
    def self.label(ev)
      return :anil_tomb unless $game_switches[SEEN] || PokeAccess::Puzzles.assist?
      [:anil_tomb_marked, { :n => ORDER[ev.id] }]
    end
  end
end

PokeAccess::Game.define("anil") do
  grave = PokeAccess::AnilGraveyard
  picture_texts("mapaCemen" => :anil_graveyard_picture)
  mechanic(:state, grave::MAP) do
    auto
    name grave::ORDER.keys, lambda { |ev| grave.label(ev) }
    hide grave::TWIN
    count :anil_tombs_read, :var => grave::STEP, :of => 3, :assist => true
    hint :anil_graveyard_hint
    solved(:anil_graveyard_item) { $game_switches[grave::DONE] }
  end
end
