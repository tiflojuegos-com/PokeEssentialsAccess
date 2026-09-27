module PokeAccess
  # The parser for the mod's key=value files (lang tables, settings.ini, the dictionaries): blank and "#" lines
  # skipped, split on the first "=", key stripped; :strip_value false keeps a value's spaces (lang tables).
  module KVFile
    # The bytes of a UTF-8 byte order mark, which Notepad's "UTF-8 with BOM" puts before the first line.
    BOM = [0xEF, 0xBB, 0xBF]

    # Yields (key, value) for each data line of path; a missing or unreadable file yields nothing. Invalid bytes
    # become "?", a leading BOM is dropped, and a line the block raises on is logged and skipped alone.
    def self.each(path, opts = {})
      return unless File.exist?(path)
      strip_value = !opts.has_key?(:strip_value) || opts[:strip_value]
      first = true
      File.foreach(path) do |raw|
        if raw.respond_to?(:scrub) && !raw.valid_encoding?
          raw = raw.scrub("?")
          (PokeAccess.log_once("kv_file_bytes_#{File.basename(path.to_s)}", "invalid bytes replaced") rescue nil)
        end
        raw = drop_bom(raw) if first
        first = false
        line = raw.gsub(/\r?\n\z/, "")
        s = line.strip
        next if s.empty? || s[0, 1] == "#"
        i = line.index("=")
        next unless i
        key = line[0, i].strip
        next if key.empty?
        val = line[(i + 1)..-1].to_s
        val = val.strip if strip_value
        begin
          yield(key, val)
        rescue StandardError => e
          (PokeAccess.log_once("kv_line_#{File.basename(path.to_s)}", e) rescue nil)
        end
      end
    rescue StandardError => e
      (PokeAccess.log_once("kv_file_#{File.basename(path.to_s)}", e) rescue nil)
      nil
    end

    # A line without the byte order mark it may start with, cut by bytes in either Ruby.
    def self.drop_bom(raw)
      return raw unless raw.unpack("C3") == BOM
      raw.respond_to?(:byteslice) ? raw.byteslice(3, raw.bytesize - 3) : raw[3..-1]
    end
  end
end
