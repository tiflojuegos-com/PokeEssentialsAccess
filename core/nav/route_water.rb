module PokeAccess
  # Pathfinder, across water: for a target out of walking reach, a search with surfing allowed (Routes::Launch) finds
  # where its way leaves the ground the player walks to for water (Routes::Regions on foot; while they are still being
  # walked, the water's edge), the shore to walk to and push off from.
  module Pathfinder
    # The tiles a surf ends on near (tx,ty): the tile itself and the four beside it.
    SURF_AROUND = [[0, 0], [0, -1], [0, 1], [-1, 0], [1, 0]]
    # How many launches are kept.
    LAUNCHES = 16

    @launches = []
    @surf_company = nil

    # The first launch on the way to (tx,ty) as [shore x, shore y, facing], or nil when surfing gets nowhere
    # near it, the player is already afloat, or the party is known not to be able to surf. One its search finished is
    # kept while what it depends on stands (launch_key): a walker's step leaves it.
    def self.surf_plan(tx, ty)
      return nil if ($PokemonGlobal.surfing rescue false)
      return nil if PokeAccess::FieldMoves.can?(:SURF) == false
      return nil if PokeAccess::MapMeta.always_bicycle?(($game_map.map_id rescue 0))
      tiles = SURF_AROUND.map { |dx, dy| [tx + dx, ty + dy] }
      return nil if Routes::Regions.water.status(tiles)[0] == :no
      foot = Routes::Regions.foot
      key = launch_key(tx, ty, foot)
      hit = @launches.assoc(key)
      return hit[1] && hit[1].dup if hit
      searching do |op|
        cuts = op.cuts
        l = launch(Routes::Goal.new(tiles, tx, ty), foot)
        keep_launch(key, l) if op.cuts == cuts
        l
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The launch toward goal, searched with the walkers the regions lend through lent too
    # (Routes::Regions.lendable_walkers), so that where they stand is no part of it: a tile is walked to when the
    # regions on foot, walked whole, reach it, else when it is no water.
    def self.launch(goal, foot)
      cost = Routes::CostModel.new((PokeAccess::Config.route_style rescue :shortest))
      whole = foot.done?
      PokeAccess::World::Probe.lend_through(Routes::Regions.lendable_walkers) do
        Routes::Launch.toward(goal, cost) do |x, y|
          whole ? foot.known([[x, y]])[0] == :yes : !Routes::Moves.surf_water?(x, y)
        end
      end
    end

    # What a launch toward (tx,ty) depends on: the target, the player's tile and bridge level, the map, the vehicle
    # and the event pages (event_epoch), any change of the events but a walker's the regions lend through
    # (water_event_change), the route style, and whether the regions on foot it reads (foot) are walked whole.
    def self.launch_key(tx, ty, foot)
      [tx, ty, $game_player.x, $game_player.y, bridge_level, event_epoch, @water_events.to_i,
       (PokeAccess::Config.route_style rescue nil), foot.done?]
    end

    # Counts a change of the events (World::Events.on_change) unless it is a walker the regions lend through coming,
    # going or taking a step (Routes::Regions.lent?), which a launch lends through too.
    def self.water_event_change(tiles, r, how)
      return if how != :change && PokeAccess::World::Events.mover?(r) && Routes::Regions.lent?(r, tiles)
      @water_events = @water_events.to_i + 1
    end

    # Keeps a launch, the oldest dropped past LAUNCHES.
    def self.keep_launch(key, l)
      @launches.push([key, l])
      @launches.shift while @launches.length > LAUNCHES
    end

    # Drops the kept launches (new tiles, a reset).
    def self.forget_launches; @launches = []; end

    # True unless the game keeps the player from surfing while someone walks along with them: by the check of its own
    # pbSurf its profile declares (surf_company), else by can_ride_vehicle_with_follower? (from Essentials v20); true
    # in a game with neither.
    def self.surf_with_company?
      kind, lets = @surf_company
      return true if kind == :anyone
      pl = $game_player
      if kind == :dependents && pl.respond_to?(:pbHasDependentEvents?)
        return true unless pl.pbHasDependentEvents?
        return lets && lets.call ? true : false
      end
      return true unless pl.respond_to?(:can_ride_vehicle_with_follower?)
      pl.can_ride_vehicle_with_follower? ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      true
    end

    # Declares the check the game's own pbSurf makes for surfing with someone along, in place of
    # can_ride_vehicle_with_follower?: :anyone, none; :dependents, a refusal while anyone walks along as a dependent
    # event (its pbHasDependentEvents?), unless the block, when given, answers true.
    def self.surf_company(kind, &lets); @surf_company = [kind, lets]; end
  end
end

PokeAccess::World::Events.on_change { |tiles, r, how| PokeAccess::Pathfinder.water_event_change(tiles, r, how) }
PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Pathfinder.forget_launches }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::Pathfinder.forget_launches }
