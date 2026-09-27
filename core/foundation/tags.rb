module PokeAccess
  # Player overrides for map objects by map and event id (name, category, hidden), stored as "mapid:eventid=name"
  # lines in tags.txt with optional tab-separated "cat=<symbol>" and "hide" tokens.
  module Tags
    extend PokeAccess::Dictionary
    FILE   = "#{PokeAccess::Paths::DATA}/tags.txt"
    IMPORT = "#{PokeAccess::Paths::DATA}/tags_import.txt"
    EXPORT = "#{PokeAccess::Paths::DATA}/tags_export.txt"

    # The record hash for an object, or nil. A record is {"name" => String, "cat" => String or nil,
    # "hidden" => true or nil} inside the {map_id => {event_id => record}} store.
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
      rec!(mid, eid)["name"] = one_line(label)
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

    # Forgets an object's whole record (name, category, hidden) and persists; set with "" clears only the name.
    def self.delete(mid, eid)
      evs = store[mid]
      return unless evs && evs.has_key?(eid)
      evs.delete(eid)
      store.delete(mid) if evs.empty?
      save
    end

    # Drops a record with no name, category or hidden flag, and the map's hash when it empties.
    def self.prune(mid, eid)
      r = rec(mid, eid)
      return unless r
      r.delete("name") if r["name"].to_s.empty?
      store[mid].delete(eid) if r.empty?
      store.delete(mid) if store[mid] && store[mid].empty?
    end

    # Yields (map_id, event_id, record) for every record, in file order.
    def self.each_record
      each_stored(store) { |key, r| yield(key[0], key[1], r) }
    end

    # ---- the Dictionary hooks: the record shape and the line format ----

    def self.header
      ["PokeAccess: overrides de objetos. Formato: mapa:evento=nombre, con tabulador cat=categoria y hide",
       "Comparte este archivo; para importar otro, renombralo a tags_import.txt"]
    end

    # One "mapid:eventid=name<TAB>cat=x<TAB>hide" line into the store; the tokens are optional.
    def self.parse_line(dest, key, val)
      colon = key.index(":")
      return if colon.nil?
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
      return if r.empty?
      (dest[mid] ||= {})[eid] = r
    end

    def self.each_stored(store)
      store.sort.each do |mid, evs|
        evs.sort.each { |eid, r| yield([mid, eid], r) }
      end
    end

    def self.has_entry?(store, key)
      !!(store[key[0]] && store[key[0]].has_key?(key[1]))
    end

    def self.put_entry(store, key, r)
      (store[key[0]] ||= {})[key[1]] = r
    end

    def self.line_for(key, r)
      out = "#{key[0]}:#{key[1]}=#{r['name']}"
      out += "\tcat=#{r['cat']}" if r["cat"] && !r["cat"].to_s.empty?
      out += "\thide" if r["hidden"]
      out
    end
  end
end
