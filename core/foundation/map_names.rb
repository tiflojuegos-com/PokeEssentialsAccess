module PokeAccess
  # Player-chosen names for maps, keyed by map id, so a player can rename a place whose own name is unhelpful
  # (an "EV"-style internal name, a duplicate, or just clearer wording). Stored as "mapid=name" lines in
  # map_names.txt, mirroring the tags dictionary. The override is consulted by Locator.map_name, so it also
  # changes how exits to that map are announced (a door's spoken destination uses the same lookup).
  module MapNames
    FILE = "#{PokeAccess::Paths::DATA}/map_names.txt"
    @names = nil

    # The {map_id => name} store, loaded on first use.
    def self.store
      load_file if @names.nil?
      @names
    end

    # The custom name for a map, or nil.
    def self.get(mid)
      n = store[mid]
      (n && !n.to_s.empty?) ? n : nil
    end

    # Sets and persists a custom map name; an empty string clears it.
    def self.set(mid, name)
      if name.nil? || name.to_s.strip.empty?
        store.delete(mid)
      else
        store[mid] = name.to_s.strip
      end
      save
    end

    # Loads map_names.txt into the store.
    def self.load_file
      @names = {}
      PokeAccess::KVFile.each(FILE) do |k, nm|
        mid = k.to_i
        @names[mid] = nm unless nm.empty? || mid <= 0
      end
    rescue StandardError
      @names ||= {}
    end

    # Writes the store back to the ini, sorted by map id.
    def self.save
      File.open(FILE, "w") do |f|
        f.write("# Nombres de mapa personalizados (mapid=nombre). Editable y compartible.\n")
        store.sort.each { |mid, nm| f.write("#{mid}=#{nm}\n") }
      end
    rescue StandardError
      nil
    end
  end
end
