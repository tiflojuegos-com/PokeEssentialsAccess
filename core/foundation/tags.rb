module PokeAccess
  # Player overrides for map objects, keyed by map and event id, so players (and the community) can
  # name, recategorise or hide objects. Stored as shareable "mapid:eventid=name" lines in tags.txt, with
  # optional tab-separated "cat=<symbol>" and "hide" tokens. Merges tags_import.txt on load.
  module Tags
    FILE   = "#{PokeAccess::Paths::DATA}/tags.txt"
    IMPORT = "#{PokeAccess::Paths::DATA}/tags_import.txt"
    EXPORT = "#{PokeAccess::Paths::DATA}/tags_export.txt"
    @tags = nil

    # The {map_id => {event_id => record}} store, loaded (and import-merged) on first use. A record is
    # {"name" => String, "cat" => String or nil, "hidden" => true or nil}.
    def self.store
      load_file if @tags.nil?
      @tags
    end

    # The record hash for an object, or nil.
    def self.rec(mid, eid)
      (store[mid] && store[mid][eid]) rescue nil
    end

    # The mutable record for an object, created if absent.
    def self.rec!(mid, eid)
      (store[mid] ||= {})[eid] ||= {}
    end

    # The custom label for an object, or nil.
    def self.get(mid, eid)
      r = rec(mid, eid)
      (r && r["name"] && !r["name"].to_s.empty?) ? r["name"] : nil
    end

    # The category-override symbol for an object (:people/:objects/:exits/:signs), or nil for auto.
    def self.category(mid, eid)
      r = rec(mid, eid)
      (r && r["cat"] && !r["cat"].to_s.empty?) ? r["cat"].to_sym : nil
    end

    # True if the object was hidden by the player.
    def self.hidden?(mid, eid)
      r = rec(mid, eid)
      !!(r && r["hidden"])
    end

    # Sets and persists a custom label (empty string clears the name but keeps cat/hidden).
    def self.set(mid, eid, label)
      rec!(mid, eid)["name"] = label.to_s
      prune(mid, eid); save
    end

    # Sets the category override (nil = back to automatic) and persists.
    def self.set_category(mid, eid, cat)
      r = rec!(mid, eid)
      if cat.nil? then r.delete("cat") else r["cat"] = cat.to_s end
      prune(mid, eid); save
    end

    # Hides or shows an object and persists.
    def self.set_hidden(mid, eid, val)
      r = rec!(mid, eid)
      if val then r["hidden"] = true else r.delete("hidden") end
      prune(mid, eid); save
    end

    # Removes an object's whole record.
    def self.remove(mid, eid)
      store[mid].delete(eid) if store[mid]
      save
    end

    # Drops a record that no longer carries a name, a category or the hidden flag.
    def self.prune(mid, eid)
      r = store[mid] && store[mid][eid]
      return unless r
      empty = (r["name"].nil? || r["name"].to_s.empty?) && (r["cat"].nil? || r["cat"].to_s.empty?) && !r["hidden"]
      store[mid].delete(eid) if empty
    end

    # Yields [map_id, event_id, record] for every hidden object, so the config menu can un-hide them.
    def self.each_hidden
      store.each do |mid, evs|
        evs.each { |eid, r| yield(mid, eid, r) if r["hidden"] }
      end
    end

    # Loads tags.txt, then merges tags_import.txt keeping existing entries.
    def self.load_file
      @tags = {}
      parse_into(@tags, FILE)
      save if File.exist?(IMPORT) && merge_new(parse_import) > 0
    rescue StandardError
      @tags ||= {}
    end

    # Parses tags_import.txt into a fresh store hash.
    def self.parse_import
      imported = {}
      parse_into(imported, IMPORT)
      imported
    end

    # Merges an imported store into the live one, keeping existing entries. Returns how many were added.
    def self.merge_new(imported)
      added = 0
      dest = store
      imported.each do |mid, evs|
        evs.each do |eid, r|
          next if dest[mid] && dest[mid].has_key?(eid)
          (dest[mid] ||= {})[eid] = r
          added += 1
        end
      end
      added
    end

    # Parses a tags file into a store hash: "mapid:eventid=name" lines with optional tab-separated
    # "cat=<symbol>" and "hide" tokens. Old name-only lines load unchanged. :strip_value false because
    # the value is tab-structured (each token strips itself).
    def self.parse_into(dest, path)
      PokeAccess::KVFile.each(path, :strip_value => false) do |key, val|
        colon = key.index(":")
        next if colon.nil?
        mid = key[0, colon].to_i
        eid = key[(colon + 1)..-1].to_i
        parts = val.split("\t")
        r = {}
        nm = parts[0].to_s.strip
        r["name"] = nm unless nm.empty?
        (parts[1..-1] || []).each do |tok|
          tok = tok.strip
          if tok == "hide"
            r["hidden"] = true
          elsif tok =~ /\Acat=(.+)\z/
            r["cat"] = $1
          end
        end
        next if r.empty?
        (dest[mid] ||= {})[eid] = r
      end
    rescue StandardError
      nil
    end

    # Merges tags_import.txt into the live store now (config-menu action), adding only new entries.
    # Returns how many were added.
    def self.import_now
      return 0 unless File.exist?(IMPORT)
      added = merge_new(parse_import)
      save if added > 0
      added
    end

    # Copies tags.txt to tags_export.txt to hand to other players. Returns the entry count, or nil if none.
    def self.export
      total = (store.values.inject(0) { |n, evs| n + evs.size } rescue 0)
      return nil if total == 0
      save
      File.open(EXPORT, "w") { |f| f.write(File.read(FILE)) }
      total
    rescue StandardError
      nil
    end

    # The one-line serialisation of a record: "name" plus optional "\tcat=..." and "\thide".
    def self.line_for(mid, eid, r)
      out = "#{mid}:#{eid}=#{r['name']}"
      out += "\tcat=#{r['cat']}" if r["cat"] && !r["cat"].to_s.empty?
      out += "\thide" if r["hidden"]
      out
    end

    # Writes the whole store back to tags.txt (sorted, shareable).
    def self.save
      File.open(FILE, "w") do |f|
        f.write("# PokeAccess: overrides de objetos. Formato: mapa:evento=nombre, con tabulador cat=categoria y hide\n")
        f.write("# Comparte este archivo; para importar otro, renombralo a tags_import.txt\n")
        (@tags || {}).sort.each do |mid, evs|
          evs.sort.each { |eid, r| f.write("#{line_for(mid, eid, r)}\n") }
        end
      end
    rescue StandardError
      nil
    end
  end
end
