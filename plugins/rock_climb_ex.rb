module PokeAccess
  # Overworld Rock Climb EX: facing up or down at its rock, the action button jumps the player onto it, carries them at
  # least one tile further, on to the last rock ahead, and jumps them off past it, $PokemonGlobal.rockclimbing on meanwhile
  # (pbRockClimbMain). One assisted route step; routes leave out the game's climb from the side, which turns up all the same.
  module RockClimbEx
    # True if (x,y) is the plugin's rock, the crest included.
    def self.rock?(x, y)
      PokeAccess::World::Terrain.flag?(x, y, :rock_climb_tag)
    end

    # Where a climb begun from (x,y) facing d sets the player down, as [x, y], or nil. The game looks ahead only after
    # moving on from the first hold, so a lone tile of rock sets the player down two tiles past it.
    def self.climb(x, y, d)
      return nil unless d == 8 || (d == 2 && ::RockClimbSettings::ENABLE_DESCENDING)
      step = d == 8 ? -1 : 1
      return nil unless rock?(x, y + step)
      cy = y + step + step
      steps = 0
      while rock?(x, cy + step)
        cy += step
        steps += 1
        return nil if steps > PokeAccess::Routes::Moves::ARRIVAL_CAP
      end
      PokeAccess::World::Probe.landing(x, cy + step)
    end
  end
end

PokeAccess::Routes::Moves.assist_source(:front_flags => [:rock_climb_tag]) do |x, y, dir, lvl|
  l = PokeAccess::RockClimbEx.climb(x, y, dir[2])
  next nil if l.nil?
  PokeAccess::Routes::Moves::Step.new(l[0], l[1], lvl, 1, { :kind => :field, :label => :loc_rock_climb, :move => :ROCKCLIMB, :x => x + dir[0], :y => y + dir[1] })
end

# The climb moves the player by itself frame after frame: a forced move, told where it left them. The player goes through
# everything only meanwhile, while the flag stays on after a climb whose last jump the map's edge stopped.
PokeAccess::Control.carrier(:rock_climb_ex) { $PokemonGlobal.rockclimbing && $game_player.through }

# The plugin's player passability (Game_Map#playerPassable?) also reads the climb, which joins the probe's mode.
PokeAccess::World::Probe.mode_reader { ($PokemonGlobal.rockclimbing rescue nil) ? true : false }

# The plugin keeps the move's badge in its own settings, not among the game's.
PokeAccess::Hooks.override(PokeAccess::FieldMoves, :badge_for, :tag => "rock_climb_ex") do |_m, original, args|
  next original.call unless args[0] == :ROCKCLIMB && defined?(::RockClimbSettings)
  ::RockClimbSettings::BADGE_FOR_ROCKCLIMB.to_i
end
