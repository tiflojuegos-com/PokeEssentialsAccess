# Edas' Fragments of the Heart: each of three rooms gives a fragment the altar of the cosmos (map 87) wants. The sphinxes of
# the room of omnipotence (map 48) and Alter in the room of omniscience (map 79) ask for a written answer (passCheck), which
# the assist says. In the room of omnipresence (map 39) one floor portal of each room leads on and the other back to the
# entrance, whatever the signs say; the portals on the way are the assist's, until the last room (from row 50 down).
module PokeAccess
  module EdasFragments
    POWER = 48
    SPHINXES = [1, 2, 4, 12]
    SPHINX_WORD = "Shean"
    WISDOM = 79
    ALTER = 3
    TYPE_WORD = "Volador"
    PRESENCE = 39
    ON_PORTALS = [12, 18, 19, 20, 21]
    BACK_PORTALS = [13, 14, 15, 16, 17]
    ENTRANCE = [19, 20, 33, 33]
    LAST_ROW = 50

    # Whether the player is still in the portals' rooms of the room of omnipresence.
    def self.among_portals?
      $game_player.y < LAST_ROW
    end
  end
end

PokeAccess::Game.define("edas") do
  frag = PokeAccess::EdasFragments
  mechanic(:state, frag::POWER) do
    auto
    answer frag::SPHINXES, frag::SPHINX_WORD
  end

  mechanic(:state, frag::WISDOM) do
    auto
    on_reach frag::ALTER, { :text => /Enigma/ }, [:puzzle_answer, { :a => frag::TYPE_WORD }], :assist => true
  end

  mechanic(:state, frag::PRESENCE) do
    auto
    sent_back :edas_omni_back, :to => frag::ENTRANCE, :events => frag::BACK_PORTALS
    active { PokeAccess::Puzzles.assist? && frag.among_portals? }
    phase lambda { frag.among_portals? }, :hint => :edas_omni_hint, :hidden => right_way(*frag::ON_PORTALS)
  end
end
