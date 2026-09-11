module PokeAccess
  # The one parser for the mod's plain key=value files (lang tables, settings.ini, map_names.txt,
  # tags.txt), which had grown four hand-rolled copies with subtly different stripping. Line protocol:
  # trailing newline removed, blank and #-comment lines skipped (comment test on the stripped line, so an
  # indented comment never parses as a key), split on the FIRST "=", key stripped and non-empty. The one
  # real semantic difference between the old copies survives as :strip_value -- the lang tables pass
  # false because a value's leading spaces are part of the spoken text ("x= hola" speaks " hola").
  module KVFile
    # Yields (key, value) for each data line of path; a missing file yields nothing, an IO failure yields
    # nothing and leaves one line in the marker (guarded, since the tables load before the marker does).
    # A stray non-UTF-8 byte (an ini or a shared tags file saved by an ANSI editor) is replaced rather than
    # raised on: on the modern engines a raise cut the file at that line, and the truncated store was then
    # written back over the original.
    def self.each(path, opts = {})
      return unless File.exist?(path)
      strip_value = !opts.has_key?(:strip_value) || opts[:strip_value]
      File.foreach(path) do |raw|
        if raw.respond_to?(:scrub) && !raw.valid_encoding?
          raw = raw.scrub("?")
          (PokeAccess.log_once("kv_file_bytes_#{File.basename(path.to_s)}", "invalid bytes replaced") rescue nil)
        end
        line = raw.gsub(/\r?\n\z/, "")
        s = line.strip
        next if s.empty? || s[0, 1] == "#"
        i = line.index("=")
        next unless i
        key = line[0, i].strip
        next if key.empty?
        val = line[(i + 1)..-1].to_s
        val = val.strip if strip_value
        yield(key, val)
      end
    rescue StandardError => e
      (PokeAccess.log_once("kv_file_#{File.basename(path.to_s)}", e) rescue nil)
      nil
    end
  end
end
