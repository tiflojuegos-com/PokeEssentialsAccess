# Twist Mountain (outside map 721, caves 722 to 724): fifteen cave mouths outside, each to a separate area of a cave, and
# ledges that only go down. From Route 7 to Icirrus City (map 725) the fewest transfers are thirteen, through 3F, the
# outside, 3F, the outside, 3F, 2F, the outside, 2F, the outside, 2F, 1F, the outside and 1F.
# WAYS holds each map's mouths on a shortest way, the nearest to Icirrus first. Each part of a map reaches one of them on
# foot, the part of 2F that reaches mouth 12 also mouth 10 past a ledge: the right way is the first the player can walk to.
# Reaching Icirrus City (its map visited) ends it.
module PokeAccess
  module FireAshTwist
    WAYS = { 721 => [19, 17, 14, 20, 21, 12, 9, 10], 722 => [9, 7], 723 => [12, 10, 9, 7], 724 => [13, 11, 8, 6] }

    # Whether Icirrus City has been reached.
    def self.done?
      $PokemonGlobal && $PokemonGlobal.visitedMaps[725] ? true : false
    end

    # The mouth to take, with the puzzle assist alone, or nil. Found on arriving and again after a move of more than a
    # tile (a ledge hop, the one move that changes which mouths can be walked to here), kept till then; while the walk
    # cannot tell yet, asked again once a frame.
    def self.way
      unless PokeAccess::Puzzles.assist?
        forget
        return nil
      end
      at = [$game_player.x, $game_player.y]
      forget if @at && (at[0] - @at[0]).abs + (at[1] - @at[1]).abs > 1
      @at = at
      return @way if @known
      now = PokeAccess::Frame.serial
      return @way if @asked == now
      @asked = now
      @way, @known = first_open($game_map.map_id)
      @way
    end

    # The first of the map's mouths the player can walk to, and whether the answer is sure; none once Icirrus is reached,
    # nor while the walk cannot tell yet.
    def self.first_open(map)
      return [nil, true] if done?
      (WAYS[map] || []).each do |id|
        s = status(id)
        return [id, true] if s == :yes
        return [nil, false] if s == :unknown
      end
      [nil, true]
    end

    # Whether the player can walk to where a mouth is entered from: :yes, :no or :unknown.
    def self.status(id)
      ev = $game_map.events[id]
      return :no unless ev
      planner = PokeAccess::Routes::Planner
      planner.reach(planner.goal_for(ev.x, ev.y, false))[0]
    end

    # Forgets the way found, to be found again.
    def self.forget
      @known = false
      @way = nil
      @asked = nil
      @at = nil
    end
  end
end

PokeAccess::Game.define("fireash") do
  [:map, :reset].each { |epoch| PokeAccess::World::Epoch.on(epoch) { PokeAccess::FireAshTwist.forget } }
  PokeAccess::FireAshTwist::WAYS.each do |map, mouths|
    mechanic(:state, map) do
      auto
      arrival_hint :fa_twist_rule, :once => true
      mouths.each do |id|
        phase lambda { PokeAccess::FireAshTwist.way == id }, :hint => :fa_twist_hint, :hidden => right_way(id)
      end
      solved { PokeAccess::FireAshTwist.done? }
    end
  end
end
