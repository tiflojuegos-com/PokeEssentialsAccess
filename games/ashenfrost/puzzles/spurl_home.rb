# Eclipse - Graham, Radon Gas in Spurl Home: Graham, shut in his room (map 66), must reach the meeting door (68, event
# 4). A teacup (map 72, events 3 and 4) filled at the foyer (map 68, event 6) puts out his fireplace (map 66, event 3,
# self switch A); the roof (map 70) leads to the study (map 71) and the foyer. Counter(3) guards send him back (7, 12).
module PokeAccess
  module AshenSpurlHome
    ROOM = 66
    FOYER = 68
    STUDY = 71
    MAPS = [66, 68, 70, 71, 72]
    HINTS = [:afg_gr_cup, :afg_gr_water, :afg_gr_fire, :afg_gr_chimney, :afg_gr_meeting, :afg_gr_either]

    @crossed = nil
    @save = nil

    # Whether the bag holds an item.
    def self.has?(item)
      ($bag.has?(item) rescue false) ? true : false
    end

    # Notes the map Graham stands on: past the roof is the study, his room restarts (a guard's catch, map 71's fireplace
    # EV2). The roof's variable 133 resets by the study, so it is kept in $PokemonGlobal; a loaded save forgets it.
    def self.note
      save = ($PokemonGlobal.object_id rescue nil)
      @crossed = nil unless save == @save
      @save = save
      id = ($game_map.map_id rescue nil)
      @crossed = true if id == STUDY
      @crossed = false if id == ROOM
    end

    # Where Graham stands in the way out, by HINTS: no cup, a cup, water, the fire out, past the roof, or in the foyer
    # of a loaded save with the fire out, either of the last two.
    def self.stage
      note
      return 4 if @crossed
      if $game_self_switches[[ROOM, 3, "A"]]
        return @crossed.nil? && ($game_map.map_id rescue nil) == FOYER ? 5 : 3
      end
      return 2 if has?(:CUPWATER)
      has?(:TEACUP) ? 1 : 0
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::AshenSpurlHome.note }

PokeAccess::Game.define("ashenfrost") do
  sh = PokeAccess::AshenSpurlHome
  watchers(sh::FOYER)
  sh::MAPS.each do |map|
    mechanic(:state, map, :part => :graham) do
      auto
      sent_back :afg_gr_caught, :maps => [68, 70], :to => [7, 12] if map == sh::ROOM
      sh::HINTS.each_with_index do |hint, k|
        spots = map == sh::FOYER && k >= 4 ? [{ :at => [12, 6], :label => :afg_gr_meeting_door }] : []
        phase lambda { PokeAccess::Puzzles.assist? && sh.stage == k }, :hint => hint, :spots => spots
      end
    end
  end
end
