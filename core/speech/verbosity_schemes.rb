module PokeAccess
  # The player's own verbosity schemes, stored as "name=reading:level,..." lines in verbosity.txt; import and export
  # come from Dictionary, without a game stamp (a scheme means the same in every game).
  module VerbositySchemes
    extend PokeAccess::Dictionary
    FILE   = "#{PokeAccess::Paths::DATA}/verbosity.txt"
    IMPORT = "#{PokeAccess::Paths::DATA}/verbosity_import.txt"
    EXPORT = "#{PokeAccess::Paths::DATA}/verbosity_export.txt"

    def self.game_bound?
      false
    end

    # The levels of a scheme, {reading => level}, or nil when there is none by that name.
    def self.levels(name)
      store[name.to_s]
    end

    # The schemes' names, in order.
    def self.names
      out = []
      each_stored(store) { |name, _levels| out.push(name) }
      out
    end

    # Saves a scheme under a name, replacing one of that name.
    def self.set(name, levels)
      store[clean_name(name)] = levels.dup
      save
    end

    # Forgets a scheme.
    def self.delete(name)
      store.delete(name.to_s)
      save
    end

    # Gives a scheme a new name.
    def self.rename(old, new_name)
      levels = store.delete(old.to_s)
      store[clean_name(new_name)] = levels if levels
      save
    end

    # A name as a file line can hold it: one line, no "=" (the separator), no leading "#"s or spaces (a comment).
    def self.clean_name(name)
      one_line(name).gsub("=", "").sub(/\A[#\s]+/, "").strip
    end

    # Whether a name is a built-in scheme's, as stored (brief) or as said (its spoken name), case aside.
    def self.reserved_name?(name)
      n = name.to_s.downcase
      PokeAccess::Verbosity::LEVELS.any? { |l| n == l.to_s || n == PokeAccess::Verbosity.name_of(l).to_s.downcase }
    end

    # Whether the player may give a scheme this name: not blank, not a built-in's and not another scheme's, case
    # aside; except is the scheme being renamed, whose own name stays free for it.
    def self.valid_name?(name, except = nil)
      n = clean_name(name)
      return false if n.empty? || reserved_name?(n)
      !store.keys.any? { |k| k.downcase == n.downcase && k != except.to_s }
    end

    # ---- the Dictionary hooks ----

    def self.header
      ["Esquemas de verbosidad (nombre=lectura:nivel,...), niveles brief, medium y full. Editable y compartible.",
       "Comparte este archivo; para importar otro, renombralo a verbosity_import.txt"]
    end

    # Reads one "name=reading:level,..." line into a store hash, dropping a line named as a level and a pair with no
    # reading or an unknown level; nothing becomes a Symbol before it is checked (1.8.7 raises on an empty one).
    # A name that only sounds like a built-in scheme is kept: it may be the player's, in another language.
    def self.parse_line(dest, key, val)
      name = clean_name(key)
      names = PokeAccess::Verbosity::LEVELS.map { |l| l.to_s }
      return if name.empty? || names.include?(name)
      levels = {}
      val.to_s.split(",").each do |pair|
        reading, from = pair.split(":", 2).map { |s| s.to_s.strip }
        next if reading.to_s.empty? || !names.include?(from.to_s)
        levels[reading.to_sym] = from.to_sym
      end
      dest[name] = levels
    end

    def self.each_stored(store)
      store.keys.sort.each { |name| yield(name, store[name]) }
    end

    # Whether an import must leave a scheme out: one of that name is there already, or the name is a built-in
    # scheme's, which the menu would not have let the player give.
    def self.has_entry?(store, name)
      store.has_key?(name) || reserved_name?(name)
    end

    def self.put_entry(store, name, levels)
      store[name] = levels
    end

    def self.line_for(name, levels)
      pairs = levels.keys.map { |r| r.to_s }.sort.map { |r| "#{r}:#{levels[r.to_sym]}" }
      "#{name}=#{pairs.join(',')}"
    end
  end
end
