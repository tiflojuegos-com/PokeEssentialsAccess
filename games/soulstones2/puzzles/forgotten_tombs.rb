# Forgotten Tombs (map 192): six wall tablets (events 15 and 24 to 28) add to V114 and seven tomb inscriptions (events 17 to
# 23) to V113, each setting its self switch A; the sixth tablet and the seventh inscription reviewed, whichever it is, each add
# to V37, which Sienna (event 12) and the entrance scene (event 13) leave at 17, and at 19 the game sends the player back to
# Cara. The two tombs Sienna already searched (events 14 and 16) count for nothing: with the assist they leave the list.
module PokeAccess
  module SS2Tombs
    TABLETS = [15, 24, 25, 26, 27, 28]
    INSCRIPTIONS = [17, 18, 19, 20, 21, 22, 23]

    # True while the search runs: from Sienna's task until both kinds are done.
    def self.running?
      v = $game_variables[37]
      v >= 16 && v < 19
    end

    # True once an event has been read.
    def self.read?(id)
      $game_self_switches[[192, id, "A"]] ? true : false
    end

    # The hint: how many of each kind are left, and that the last inscription reviewed is always the one.
    def self.hint
      t = PokeAccess::I18n
      tablets = TABLETS.reject { |id| read?(id) }.length
      inscriptions = [7 - $game_variables[113], 0].max
      PokeAccess.sentences([t.t(:ss2_pz_tomb_h_left, :tablets => tablets, :inscriptions => inscriptions), t.t(:ss2_pz_tomb_h_rule)])
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  mechanic(:state, 192) do
    auto
    unread = lambda { |ev| PokeAccess::SS2Tombs.running? && !PokeAccess::SS2Tombs.read?(ev.id) }
    name PokeAccess::SS2Tombs::TABLETS, :ss2_pz_tomb_tablet, :when => unread
    name PokeAccess::SS2Tombs::INSCRIPTIONS, :ss2_pz_tomb_inscription, :when => unread
    name [14, 16], :ss2_pz_tomb_inscription, :when => lambda { |_ev| PokeAccess::SS2Tombs.running? && !PokeAccess::Puzzles.assist? }
    watch :var => 114, :label => :ss2_pz_tomb_tablets, :number => true
    watch :var => 113, :label => :ss2_pz_tomb_inscriptions, :number => true
    active { PokeAccess::SS2Tombs.running? }
    solved { $game_variables[37] >= 19 }
    hint lambda { PokeAccess::SS2Tombs.hint }
  end
end
