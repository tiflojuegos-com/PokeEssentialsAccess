module PokeAccess
  # Routes: what one move does (Moves) and what the map's events do to it (Effects), for the searches (Pathfinder)
  # and the guide. This file holds what they all use: the tile key and the four steps.
  module Routes
    # Tile-coordinate packing stride: a tile packs as x*PKEY_STRIDE+y into one Integer hash key (HPA* reuses the same
    # stride to pack cluster ids). Map dimensions stay well under it.
    PKEY_STRIDE = 100000

    # Packs a tile coordinate into a single hash key.
    def self.pkey(x, y); x * PKEY_STRIDE + y; end

    # The four orthogonal steps as [dx, dy, rpg direction code], in the order the searches and the regions try them,
    # and the same steps by direction code.
    DIRS = [8, 2, 4, 6].map { |d| PokeAccess::DIR_DELTA[d].dup.push(d) }
    DIR_OF = DIRS.inject({}) { |h, s| h[s[2]] = s; h }
  end
end
