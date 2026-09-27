module PokeAccess
  # Player-chosen map names by map id ("mapid=name" in map_names.txt), used by Locator.map_name and so by the
  # spoken exit destinations; imported and exported through Dictionary.
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
        store[mid] = one_line(name)
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
