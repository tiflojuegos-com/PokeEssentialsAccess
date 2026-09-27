module PokeAccess
  # Insurgence's rolling boulders: some 690 events named "boulder" in lower case that, walked into, move one tile the
  # way the player faces by a move route on themselves, asking for no move, badge or switch; only the capitalised
  # "Boulder" goes through Kernel.pbStrength. They are told apart by their live page: touched by the player, moving
  # itself.
  module InsurgenceBoulders
    # True for a rolling boulder: named "boulder", its live page player-touch with a move route on the event itself
    # (209 on character 0).
    def self.rolling?(ev)
      return false unless (ev.name.to_s rescue "") == "boulder"
      return false unless PokeAccess.ivar(ev, :@trigger) == 1
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) && list.any? { |c| (c.code rescue 0) == 209 && (c.parameters[0] rescue nil) == 0 }
    rescue StandardError
      false
    end
  end

  # The Ancient Tower's pitfalls (maps 366 to 368): invisible parallel events named "Pitfall" that drop the player to
  # the floor below unless, riding the bicycle, it goes on without stopping (the page checks the tile again four
  # frames later). On foot they are walls to the route; riding, ground where the direction key must be kept held.
  module InsurgencePits
    # The map's pit tiles as pkeys.
    def self.index
      PokeAccess::Pathfinder.event_index(:ins_pits) do |_mid|
        idx = {}
        ($game_map.events.values rescue []).each do |ev|
          idx[PokeAccess::Pathfinder.pkey(ev.x, ev.y)] = true if (ev.name.to_s rescue "") == "Pitfall"
        end
        idx
      end
    end

    # True if a pitfall waits on (x, y).
    def self.pit?(x, y)
      index[PokeAccess::Pathfinder.pkey(x, y)] ? true : false
    end

    # True while the player rides the bicycle.
    def self.riding?
      ($PokemonGlobal.bicycle rescue false) ? true : false
    end

    # A step arriving on (x, y): nil off the pits, false on foot, the tile itself riding.
    def self.arrival(x, y)
      return nil unless pit?(x, y)
      riding? ? [x, y] : false
    end
  end

  # Insurgence's waterfalls have no crest tile (no map carries tag 9): a surfer whose step ends facing down with a
  # fall below is carried to the water past it (onStepTakenFieldMovement, 086_PokemonField.rb).
  module InsurgenceFalls
    # Where a surfer arriving on (x, y) moving down ends: the water past the fall below as [x, y], false past the map's
    # edge, or nil with no fall below.
    def self.descent(x, y, d)
      return nil unless d == 2 && ($PokemonGlobal.surfing rescue false)
      return nil unless PokeAccess::Terrain.kind(x, y + 1) == :waterfall
      PokeAccess::Pathfinder.fall_end(x, y + 1, 1) || false
    end

    # A planned surf entering the fall at (x, y) moving down: the Step onto the water past it, or nil when that is no
    # water; :none for any other move, which the core decides.
    def self.entered(x, y, d, lvl)
      return :none unless d == 2 && PokeAccess::Terrain.kind(x, y) == :waterfall
      l = PokeAccess::Pathfinder.fall_end(x, y, 1)
      l && PokeAccess::Pathfinder.surf_water?(l[0], l[1]) ? PokeAccess::Pathfinder::Step.new(l[0], l[1], lvl) : nil
    end
  end
end

PokeAccess::Game.define("insurgence") do
  override("PokeAccess::Pathfinder", :push_move) do |_mod, original, args|
    PokeAccess::InsurgenceBoulders.rolling?(args[0]) ? [nil] : original.call
  end
  override("PokeAccess::Locator", :fieldmove_label) do |_mod, original, args|
    PokeAccess::InsurgenceBoulders.rolling?(args[0]) ? :loc_pushable : original.call
  end

  terrain_rule { |x, y, _d| PokeAccess::InsurgencePits.arrival(x, y) }
  held_key_ground { |x, y| PokeAccess::InsurgencePits.riding? && PokeAccess::InsurgencePits.pit?(x, y) }

  terrain_rule { |x, y, d| PokeAccess::InsurgenceFalls.descent(x, y, d) }
  override("PokeAccess::Pathfinder", :falls_step) do |_mod, original, args|
    s = PokeAccess::InsurgenceFalls.entered(args[0], args[1], args[2], args[3])
    s == :none ? original.call : s
  end
end
