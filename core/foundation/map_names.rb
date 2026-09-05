module PokeAccess
  # Player-chosen names for maps, keyed by map id, so a player can rename a place whose own name is unhelpful
  # (an "EV"-style internal name, a duplicate, or just clearer wording). Stored as "mapid=name" lines in
  # map_names.txt. The override is consulted by Locator.map_name, so it also changes how exits to that map are
  # announced (a door's spoken destination uses the same lookup). Import and export are Dictionary's, the
  # same as the tags: a player who renamed a whole dungeon can hand the file on.
  module MapNames
    extend PokeAccess::Dictionary
    FILE   = "#{PokeAccess::Paths::DATA}/map_names.txt"
    IMPORT = "#{PokeAccess::Paths::DATA}/map_names_import.txt"
    EXPORT = "#{PokeAccess::Paths::DATA}/map_names_export.txt"

    # The custom name for a map, or nil.
    def self.get(mid)
      n = store[mid]
      (n && !n.to_s.empty?) ? n : nil
    end

    # Sets and persists a custom map name; an empty string clears it.
    def self.set(mid, name)
      if blank?(name)
        store.delete(mid)
      else
        store[mid] = name.to_s.strip
      end
      save
    end

    # Forgets a map's custom name and persists (the management menu's "delete").
    def self.delete(mid)
      set(mid, "")
    end

    # Yields (map_id, name) for every renamed map, by map id.
    def self.each_name
      each_stored(store) { |mid, name| yield(mid, name) }
    end

    # ---- the Dictionary hooks ----

    def self.header
      ["Nombres de mapa personalizados (mapid=nombre). Editable y compartible.",
       "Comparte este archivo; para importar otro, renombralo a map_names_import.txt"]
    end

    def self.parse_line(dest, key, val)
      mid = key.to_i
      name = val.strip
      dest[mid] = name unless name.empty? || mid <= 0
    end

    def self.each_stored(store)
      store.sort.each { |mid, name| yield(mid, name) }
    end

    def self.has_entry?(store, mid)
      store.has_key?(mid)
    end

    def self.put_entry(store, mid, name)
      store[mid] = name
    end

    def self.line_for(mid, name)
      "#{mid}=#{name}"
    end
  end
end
