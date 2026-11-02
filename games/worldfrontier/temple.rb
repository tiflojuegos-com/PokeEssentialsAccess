# World Frontier's Battle Temple (Templo Batalla): its dungeon floors paint the counters of the room's items and of the
# trainers beaten in a corner (BattleTemple::RoomItemLabel), repainted when one changes; each that changed is said then,
# queued.
module PokeAccess
  module WfTemple
    @said = []

    # Says the counters that differ from the last ones said.
    # param counters the texts as painted
    def self.painted(counters)
      counters.each_with_index { |text, i| PokeAccess.speak_clean(text.to_s, false) unless text == @said[i] }
      @said = counters
    end

    # Forgets the counters said, as the mod's per-map state goes.
    def self.forget
      @said = []
    end
  end
end

PokeAccess::Caches.register(:wf_temple) { PokeAccess::WfTemple.forget }

PokeAccess::Game.define("worldfrontier") do
  before("BattleTemple::RoomItemLabel", :paint) { |_label, args| PokeAccess::WfTemple.painted(args) }
end
