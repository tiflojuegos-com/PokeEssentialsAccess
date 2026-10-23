# Failures kept for the diagnostic: the marker file, failures logged once per key and failures a rescue swallows,
# counted by where they came from. Loaded first, so every rescue of the mod can report.
module PokeAccess
  # A frame of the mod's own code in a backtrace: the path from its last core/, games/ or plugins/ folder and the line,
  # as "core/nav/guide.rb:120" (a game installed under a games/ folder keeps that part out).
  MOD_FRAME = %r{\A(?:.*[/\\])?((?:core|games|plugins)/[^:\s]+\.rb:\d+)}

  # The marker file diagnostic lines go to, once the data folder is known; nil before.
  def self.marker_file
    return nil unless defined?(PokeAccess::Paths) && PokeAccess::Paths.const_defined?(:DATA)
    "#{PokeAccess::Paths::DATA}/hook_loaded.txt"
  end

  # Appends a diagnostic line to the marker file; before the data folder is known, nothing.
  def self.write_marker(extra = "")
    path = marker_file
    File.open(path, "a") { |f| f.write("#{Time.now}: #{extra}") } if path
  rescue StandardError
  end

  # Formats an error for a diagnostic line: an exception as "Class: message @ frame <- frame <- frame" (its top three
  # backtrace frames), any other value as its string.
  def self.format_error(e)
    return e.to_s unless e.respond_to?(:backtrace)
    "#{e.class}: #{e.message} @ #{((e.backtrace || [])[0, 3]).join(' <- ')}"
  end

  # Writes the first failure (exception or string) for a key to the marker, and nothing more for it; never raises.
  def self.log_once(key, e)
    @logged_once ||= {}
    return if @logged_once[key]
    @logged_once[key] = format_error(e)
    write_marker("#{key}: #{@logged_once[key]}\n")
  rescue StandardError
    nil
  end

  # The failures log_once wrote this session, key => line, for the diagnostic.
  def self.logged; @logged_once || {}; end

  # Returns value, logging once when nil: only where the object must exist, never where nil is a normal state.
  def self.expect!(key, value)
    log_once("expect.#{key}", "expected but absent") if value.nil?
    value
  rescue StandardError
    value
  end

  # Where a failure comes from: the innermost frame of the mod's own code in its backtrace, else its top frame.
  def self.failure_site(e)
    bt = e.respond_to?(:backtrace) ? (e.backtrace || []) : []
    bt.each do |line|
      m = MOD_FRAME.match(line.to_s)
      return m[1] if m
    end
    bt[0].to_s
  end

  # Records a failure a rescue swallows: the first one from each place in the mod is written to the marker, and every
  # one is counted, for the diagnostic. Returns nil; never raises.
  def self.swallowed(e)
    @swallowed ||= {}
    site = failure_site(e)
    rec = @swallowed[site]
    if rec
      rec[0] += 1
    else
      @swallowed[site] = [1, format_error(e)]
      write_marker("swallowed #{site}: #{@swallowed[site][1]}\n")
    end
    nil
  rescue StandardError
    nil
  end

  # The failures swallowed this session, most frequent first, as [site, count, first failure].
  def self.swallowed_sites
    (@swallowed || {}).map { |site, rec| [site, rec[0], rec[1]] }.sort_by { |site, n, _f| [-n, site] }
  end
end
