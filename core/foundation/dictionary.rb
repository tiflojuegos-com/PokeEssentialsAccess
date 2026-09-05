module PokeAccess
  # The plumbing every shareable text dictionary has in common: Tags (object overrides), Marks (the player's
  # own markers) and MapNames (renamed maps) each keep a different shape of key, but load, save, import and
  # export the same way -- a "key=value" file per store, a sibling *_import.txt merged ADDING ONLY what the
  # store lacks, and a *_export.txt copy to hand to other players. Three copies of that plumbing had begun to
  # drift (two of them had no import or export at all), so it lives once here and each store extends it.
  #
  # A store module declares three path constants (FILE, IMPORT, EXPORT) and the hooks that know its shape:
  #
  #   header                    -> the comment lines written at the top of the file (an Array of Strings)
  #   parse_line(dest, key, val) -> reads one data line into a store hash
  #   each_stored(store)          -> yields (key, value) for every entry, in the order the file is written
  #   has_entry?(store, key)     -> whether the store already holds that key (imports never overwrite)
  #   put_entry(store, key, val) -> writes one entry
  #   line_for(key, value)       -> the one-line serialisation of an entry
  #
  # Every file carries the game it belongs to. The keys are map ids, and a map id means something else in
  # every other game: a Pokemon Z tag file dropped into Anil imports without a single error and names random
  # events all over the region. So save stamps "# game: <profile>" and import_status refuses a file stamped
  # with a different game -- silently doing the wrong thing is the one failure a shared file must not have.
  module Dictionary
    GAME_LINE = /\A#\s*game:\s*(\S+)/

    # The loaded store, read (and import-merged) on first use.
    def store
      load_file if @store.nil?
      @store
    end

    # Forgets the loaded store, so the next use reads the file again.
    def reload!
      @store = nil
    end

    # Values that are neither nil nor blank, as one line of a file needs.
    def blank?(v)
      v.nil? || v.to_s.strip.empty?
    end

    # Reads FILE into a fresh store, then merges whatever IMPORT holds -- through the same gate as the menu
    # action, so a file from another game is refused here as well -- saving only if it added something.
    def load_file
      @store = {}
      parse_into(@store, const_get(:FILE))
      save if import_status[0] == :ready && merge_new(parse_import) > 0
    rescue StandardError
      @store ||= {}
    end

    # Parses a dictionary file into a store hash through the store's own parse_line. :strip_value false
    # because a value may be tab-structured (each token strips itself).
    def parse_into(dest, path)
      PokeAccess::KVFile.each(path, :strip_value => false) { |key, val| parse_line(dest, key, val) }
    rescue StandardError
      nil
    end

    # The IMPORT file as a fresh store hash.
    def parse_import
      imported = {}
      parse_into(imported, const_get(:IMPORT))
      imported
    end

    # Merges an imported store into the live one, keeping every entry the store already has. Returns how
    # many were added.
    def merge_new(imported)
      added = 0
      dest = store
      each_stored(imported) do |key, value|
        next if has_entry?(dest, key)
        put_entry(dest, key, value)
        added += 1
      end
      added
    end

    # Whether IMPORT can be merged now: [:none] when there is no file, [:foreign, game] when it is stamped
    # with another game's name, [:ready, game] otherwise (game is nil for a file with no stamp -- one written
    # before the stamp existed, which imports as it always did).
    def import_status
      path = const_get(:IMPORT)
      return [:none] unless File.exist?(path)
      game = file_game(path)
      mine = (PokeAccess::Game.profile_name rescue nil)
      return [:foreign, game] if game && mine && game != mine
      [:ready, game]
    end

    # Merges IMPORT into the live store now (the menu action). Adds only what the store lacks and refuses a
    # file from another game. Returns how many entries were added.
    def import_now
      return 0 unless import_status[0] == :ready
      added = merge_new(parse_import)
      save if added > 0
      added
    end

    # Copies FILE to EXPORT to hand to other players. Returns the entry count, or nil if there is nothing.
    def export
      total = count
      return nil if total == 0
      save
      File.open(const_get(:EXPORT), "w") { |f| f.write(File.read(const_get(:FILE))) }
      total
    rescue StandardError
      nil
    end

    # How many entries the store holds.
    def count
      n = 0
      each_stored(store) { |_k, _v| n += 1 }
      n
    end

    # Writes the whole store back to FILE: the header, the game stamp, then every entry in each_stored order.
    def save
      mine = (PokeAccess::Game.profile_name rescue nil)
      File.open(const_get(:FILE), "w") do |f|
        header.each { |line| f.write("# #{line}\n") }
        f.write("# game: #{mine}\n") if mine
        each_stored(store) { |key, value| f.write("#{line_for(key, value)}\n") }
      end
    rescue StandardError
      nil
    end

    # The game a dictionary file is stamped with, or nil. Only the leading comment block is read: the stamp
    # is written there, and a data line is never a stamp.
    def file_game(path)
      File.foreach(path) do |raw|
        line = raw.strip
        next if line.empty?
        return nil unless line[0, 1] == "#"
        return $1 if line =~ GAME_LINE
      end
      nil
    rescue StandardError
      nil
    end
  end
end
