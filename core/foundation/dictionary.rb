module PokeAccess
  # Shared plumbing for the shareable text dictionaries (Tags, Marks, MapNames): a "key=value" FILE per store, an
  # IMPORT merged adding only what the store lacks (then renamed *_import.imported.txt) and an EXPORT copy. A
  # store declares FILE, IMPORT and EXPORT and these hooks:
  #
  #   header                     -> the comment lines at the top of the file (an Array of Strings)
  #   parse_line(dest, key, val) -> reads one data line into a store hash
  #   each_stored(store)         -> yields (key, value) in file order
  #   has_entry?(store, key)     -> whether the store holds that key (imports never overwrite)
  #   put_entry(store, key, val) -> writes one entry
  #   line_for(key, value)       -> the one-line serialisation of an entry
  #
  # Files are stamped "# game: <profile>" and another game's import is refused (its keys are map ids); a store
  # with game_bound? false does neither.
  module Dictionary
    # Whether the store's keys belong to one game, so its files are stamped and another game's refused.
    def game_bound?
      true
    end

    # The stamp line; the name runs to the end of the line, since a "generic:<title>" stamp holds spaces.
    GAME_LINE = /\A#\s*game:\s*(.+?)\s*\z/

    # The loaded store, read (and import-merged) on first use.
    def store
      load_file if @store.nil?
      @store
    end

    # Bumped by every save and reload!, so a reader caching something derived from the store can tell it is stale.
    def rev
      @rev ||= 0
    end

    # Forgets the loaded store, so the next use reads the file again.
    def reload!
      @store = nil
      @rev = rev + 1
    end

    # True for nil or a blank value.
    def blank?(v)
      v.nil? || v.to_s.strip.empty?
    end

    # A player-typed value on one line: tabs (the tags format's separator) and line breaks become a space.
    def one_line(v)
      v.to_s.gsub(/[\t\r\n]+/, " ").strip
    end

    # Reads FILE into a fresh store, then merges IMPORT when import_status allows it, saving only if that added
    # something, and retires the merged file.
    def load_file
      @store = {}
      parse_into(@store, const_get(:FILE))
      if import_status[0] == :ready
        save if merge_new(parse_import) > 0
        retire_import
      end
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

    # Adds the imported entries the live store lacks; returns how many.
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

    # Whether IMPORT can be merged now: [:none] with no file, [:foreign, game] when stamped with another game's
    # name, else [:ready, game] (game nil for an unstamped file, which imports).
    def import_status
      path = const_get(:IMPORT)
      return [:none] unless File.exist?(path)
      game = file_game(path)
      mine = (PokeAccess::Game.profile_name rescue nil)
      foreign = game_bound? && game && mine && game != mine && !legacy_generic?(game, mine)
      return [:foreign, game] if foreign
      [:ready, game]
    end

    # Whether a bare "generic" stamp may import into this "generic:<title>" game: unprofiled installs before
    # 0.4.6 stamped the word alone.
    def legacy_generic?(game, mine)
      game == "generic" && mine.to_s[0, 8] == "generic:"
    end

    # The menu's import: merges a ready IMPORT and retires it; returns how many entries it added.
    def import_now
      return 0 unless import_status[0] == :ready
      added = merge_new(parse_import)
      save if added > 0
      retire_import
      added
    end

    # Where a merged IMPORT goes: the same name with .imported before the extension.
    def imported_path
      const_get(:IMPORT).sub(/\.txt\z/, ".imported.txt")
    end

    # Renames the merged IMPORT to imported_path, replacing an earlier one, so no later load merges it again.
    def retire_import
      path = const_get(:IMPORT)
      done = imported_path
      File.delete(done) if File.exist?(done)
      File.rename(path, done)
    rescue StandardError => e
      PokeAccess.log_once("dict_retire_#{name}", e)
      nil
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
        f.write("# game: #{mine}\n") if mine && game_bound?
        each_stored(store) { |key, value| f.write("#{line_for(key, value)}\n") }
      end
    rescue StandardError => e
      PokeAccess.log_once("dict_save_#{name}", e)
      nil
    end

    # The game a dictionary file is stamped with, or nil; only the leading comment block is read.
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
