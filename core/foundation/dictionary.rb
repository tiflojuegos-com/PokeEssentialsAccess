module PokeAccess
  # The plumbing every shareable text dictionary shares (Tags, Marks, MapNames): a "key=value" file per
  # store, a sibling *_import.txt merged ADDING ONLY what the store lacks, and a *_export.txt copy. A store
  # declares FILE, IMPORT and EXPORT and the hooks that know its shape:
  #
  #   header                     -> the comment lines at the top of the file (an Array of Strings)
  #   parse_line(dest, key, val) -> reads one data line into a store hash
  #   each_stored(store)         -> yields (key, value) in file order
  #   has_entry?(store, key)     -> whether the store holds that key (imports never overwrite)
  #   put_entry(store, key, val) -> writes one entry
  #   line_for(key, value)       -> the one-line serialisation of an entry
  #
  # Every file is stamped "# game: <profile>" and import_status refuses another game's: the keys are map
  # ids, which mean something else in every other game.
  module Dictionary
    # The stamp line. The name runs to the END of the line, not to the first space: a game with no profile
    # is stamped "generic:<its own title>", and a title has spaces in it.
    GAME_LINE = /\A#\s*game:\s*(.+?)\s*\z/

    # The loaded store, read (and import-merged) on first use.
    def store
      load_file if @store.nil?
      @store
    end

    # How many times this dictionary has been written, so a reader that CACHES something derived from it can
    # tell in one comparison whether its cache still holds. Every mutation persists through save, which is
    # what makes this exact rather than a guess.
    def rev
      @rev ||= 0
    end

    # Forgets the loaded store, so the next use reads the file again.
    def reload!
      @store = nil
      @rev = rev + 1
    end

    # Values that are neither nil nor blank, as one line of a file needs.
    def blank?(v)
      v.nil? || v.to_s.strip.empty?
    end

    # A player-typed value reduced to ONE line: no tab, which is what the tags format separates its tokens
    # with, and no line break, since every one of these files is read a line at a time. Typing either is
    # unlikely; pasting one is not, and the loss would be silent -- the name comes back truncated on the
    # next load, long after the player typed it.
    def one_line(v)
      v.to_s.gsub(/[\t\r\n]+/, " ").strip
    end

    # Reads FILE into a fresh store, then merges whatever IMPORT holds -- through the same gate as the menu
    # action, so a file from another game is refused here as well -- saving only if it added something.
    def load_file
      @store = {}
      parse_into(@store, const_get(:FILE))
      save if import_status[0] == :ready && merge_new(parse_import) > 0
    rescue StandardError => e
      PokeAccess.log_once("dict_load_#{name}", e)
      @store ||= {}
    end

    # Parses a dictionary file into a store hash through the store's own parse_line. :strip_value false
    # because a value may be tab-structured (each token strips itself).
    def parse_into(dest, path)
      PokeAccess::KVFile.each(path, :strip_value => false) { |key, val| parse_line(dest, key, val) }
    rescue StandardError => e
      PokeAccess.log_once("dict_parse_#{name}", e)
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
      return [:foreign, game] if game && mine && game != mine && !legacy_generic?(game, mine)
      [:ready, game]
    end

    # Whether a bare "generic" stamp may import into this game's qualified one. Every unprofiled install
    # before 0.4.6 stamped that word alone, so a file so stamped may well be this very game's, and refusing
    # it left the player no way to bring their own markers back.
    def legacy_generic?(game, mine)
      game == "generic" && mine.to_s[0, 8] == "generic:"
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
    rescue StandardError => e
      PokeAccess.log_once("dict_export_#{name}", e)
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
      @rev = rev + 1
      mine = (PokeAccess::Game.profile_name rescue nil)
      File.open(const_get(:FILE), "w") do |f|
        header.each { |line| f.write("# #{line}\n") }
        f.write("# game: #{mine}\n") if mine
        each_stored(store) { |key, value| f.write("#{line_for(key, value)}\n") }
      end
    rescue StandardError => e
      PokeAccess.log_once("dict_save_#{name}", e)
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
    rescue StandardError => e
      PokeAccess.log_once("dict_stamp_#{name}", e)
      nil
    end
  end
end
