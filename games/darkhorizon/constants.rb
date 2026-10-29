# Pokemon Dark Horizon (Essentials v21.1 on mkxp-z, Ruby 3.1): only what differs from core/foundation/config.rb. Its
# field moves are the stock handlers, its Surf asks Following Pokemon EX's can_ride_vehicle_with_follower?, its
# Shadow Sky is the core's weather, and its key hints name buttons (USE, BACK), never letters.
module PokeAccess
  # What the Dark Horizon readers share.
  module DarkHorizon
    # text followed by hint while hints are said, joined as sentences: a text that already ends its own (a painted
    # "Choose your Pokemon.") takes no second period.
    def self.hinted(text, hint)
      PokeAccess::Verbosity.hints? ? PokeAccess.sentences([text, hint]) : text.to_s
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  # No map or common event of the game hands out a badge; its trainer card shows the Colosseum Points, CP, instead
  # (37_DH_TrainerCard.rb), so the trainer line says those where the badges would go.
  trainer_part(:cp) do |tr|
    n = (tr.battle_points rescue nil)
    n.nil? ? nil : PokeAccess::I18n.t(:dh_tr_cp, :n => n)
  end
  trainer_order [:name, :money, :cp, :pokedex, :playtime]
end
