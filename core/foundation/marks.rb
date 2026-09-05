module PokeAccess
  # The player's own markers: a named tile, keyed by map and coordinates, that the locator lists in a
  # category of its own so the pathfinder and both guides can lead back to it. Where the tags describe what
  # the GAME put on a tile, a mark is the player's note about the tile itself -- "the shop", "where I
  # stopped", "the exit that works" -- which is why it is a dictionary of its own and not a tag with no
  # event: the two are keyed differently, shared with different people, and a tag line parsed as a mark
  # (or the reverse) silently lands on the wrong thing. Stored as "mapid:x,y=name" lines in marks.txt.
  module Marks
    extend PokeAccess::Dictionary
    FILE   = "#{PokeAccess::Paths::DATA}/marks.txt"
    IMPORT = "#{PokeAccess::Paths::DATA}/marks_import.txt"
    EXPORT = "#{PokeAccess::Paths::DATA}/marks_export.txt"
    KEY_RE = /\A(\d+):(\d+),(\d+)\z/

    # The name of the mark on a tile, or nil.
    def self.get(mid, x, y)
      tiles = store[mid]
      tiles && tiles[[x, y]]
    end

    # Names the mark on a tile and persists; a blank name removes it.
    def self.set(mid, x, y, name)
      if blank?(name)
        delete(mid, x, y)
      else
        (store[mid] ||= {})[[x, y]] = name.to_s.strip
        save
      end
    end

    # Removes the mark on a tile, if any, and persists.
    def self.delete(mid, x, y)
      tiles = store[mid]
      return unless tiles && tiles.has_key?([x, y])
      tiles.delete([x, y])
      store.delete(mid) if tiles.empty?
      save
    end

    # The marks of one map as [x, y, name] triples, in reading order (row by row).
    def self.on_map(mid)
      tiles = store[mid] || {}
      tiles.keys.sort_by { |xy| [xy[1], xy[0]] }.map { |xy| [xy[0], xy[1], tiles[xy]] }
    end

    # True if a map has at least one mark, which is what makes the locator offer the category there.
    def self.any_on?(mid)
      tiles = store[mid]
      !!(tiles && !tiles.empty?)
    end

    # Yields (map_id, x, y, name) for every mark, by map and then in reading order.
    def self.each_mark
      each_stored(store) { |key, name| yield(key[0], key[1], key[2], name) }
    end

    # ---- the Dictionary hooks ----

    def self.header
      ["PokeAccess: marcadores del jugador. Formato: mapa:x,y=nombre",
       "Comparte este archivo; para importar otro, renombralo a marks_import.txt"]
    end

    def self.parse_line(dest, key, val)
      return unless key =~ KEY_RE
      name = val.strip
      return if name.empty?
      (dest[$1.to_i] ||= {})[[$2.to_i, $3.to_i]] = name
    end

    def self.each_stored(store)
      store.sort.each do |mid, tiles|
        tiles.keys.sort_by { |xy| [xy[1], xy[0]] }.each { |xy| yield([mid, xy[0], xy[1]], tiles[xy]) }
      end
    end

    def self.has_entry?(store, key)
      !!(store[key[0]] && store[key[0]].has_key?([key[1], key[2]]))
    end

    def self.put_entry(store, key, name)
      (store[key[0]] ||= {})[[key[1], key[2]]] = name
    end

    def self.line_for(key, name)
      "#{key[0]}:#{key[1]},#{key[2]}=#{name}"
    end
  end
end
