# North Aventurine Woods (map 289): while riding a Tauros (switch 291), events over three ledges let it jump them the
# other way: (84, 17 to 20) eastward, (80 to 82, 15) and (54 to 56, 24) upward. The first two lead to the north-east
# corner, with the Floral Charm's flower, three items and the tile (87, 12) that sends the Tauros away.
module PokeAccess
  module RebornTaurosLedges
    MAP = 289
    RIDING = 291
    LEDGES = [[[83, 18], :rbrd_tauros_ledge_east], [[81, 16], :rbrd_tauros_ledge_up], [[55, 25], :rbrd_tauros_ledge_up]]

    # With the assist, the rule on arriving.
    def self.rule
      PokeAccess::Puzzles.assist? ? :rbrd_tauros_rule : nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  bulls = PokeAccess::RebornTaurosLedges
  mechanic(:state, bulls::MAP, :part => :tauros_ledges) do
    auto
    bulls::LEDGES.each { |xy, label| spot :at => xy, :label => label, :assist => true, :onto => true }
    arrival_hint lambda { bulls.rule }, :once => true
    info { nil }
    active { false }
  end
end
