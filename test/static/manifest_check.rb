# Checks core/manifest.rb and every games/<profile>/manifest.rb against the disk (each **/*.rb but the manifest
# listed exactly once, each entry with its file) and games/catalog.json against the profiles and their detection.
# A pure-filesystem check; exits non-zero on any gap, naming the folder.
ROOT = File.expand_path("../..", __dir__)
CORE = File.join(ROOT, "core")
GAMES = File.join(ROOT, "games")

# The entries of a manifest's :modules list (else its first %w[...]) as "subsystem/name" strings, or nil with no
# list; a profile's :plugins list is not its folder's files.
def manifest_entries(mf)
  text = File.read(mf)
  body = text[/:modules\s*=>\s*%w\[(.*?)\]/m, 1] || text[/%w\[(.*?)\]/m, 1]
  body && body.split(/\s+/).reject { |s| s.empty? }
end

# Every <dir>/**/*.rb as a manifest-relative path (no extension), excluding the folder's own manifest.
def disk_modules(dir)
  Dir.glob(File.join(dir, "**", "*.rb")).map do |p|
    p[(dir.length + 1)..-1].sub(/\.rb\z/, "").tr("\\", "/")
  end.reject { |r| r == "manifest" }
end

# The compat script each catalog profile names ("compat"), by profile key and without .rb: mkxp.json's preloadScript
# runs it, so it is no module and its manifest does not list it.
def compat_modules
  require "json"
  out = {}
  JSON.parse(File.read(File.join(GAMES, "catalog.json")))["profiles"].each do |p|
    out[p["key"]] = p["compat"].to_s.sub(/\.rb\z/, "") if p["compat"]
  end
  out
rescue StandardError
  {}
end

# The manifest<->disk gaps of one folder as problem lines, each prefixed with that folder's label; skip lists the
# files on disk that are not modules.
def folder_problems(label, dir, skip = [])
  entries = manifest_entries(File.join(dir, "manifest.rb"))
  return ["#{label}: manifest.rb has no %w[...] module list"] if entries.nil?
  missing_file = entries.reject { |e| File.file?(File.join(dir, "#{e}.rb")) }
  not_listed   = disk_modules(dir) - entries - skip
  dupes        = entries.select { |e| entries.count(e) > 1 }.uniq
  out = []
  out << "#{label}: listed but no file: #{missing_file.join(', ')}" unless missing_file.empty?
  out << "#{label}: on disk but not listed: #{not_listed.join(', ')}" unless not_listed.empty?
  out << "#{label}: listed more than once: #{dupes.join(', ')}" unless dupes.empty?
  out
end

profiles = Dir.glob(File.join(GAMES, "*", "manifest.rb")).sort.map { |p| File.dirname(p) }
problems = folder_problems("core", CORE)
compat = compat_modules
profiles.each do |dir|
  key = File.basename(dir)
  problems.concat(folder_problems("games/#{key}", dir, [compat[key]].compact))
end
entries = (manifest_entries(File.join(CORE, "manifest.rb")) || [])

# games/catalog.json against the profiles: one entry per games/<key>/ folder but the commons (<key>_common, which are
# never detected), and the layered detection resolving each profile's own titles and display to itself, with no exe
# claimed twice.
# - detect probes run on the display lowercased and de-accented, as folder names come.
# - every profile needs a valid engine and, but for generic, at least one identity layer (titles, detect or exes).
# - a compat names a bare .rb file of the profile's own folder (the launcher deploys it to accessibility/game/).
# - a convert names an engine folder of assets/engine, and its markers the bare file names the launcher looks for in
#   the game's folder before converting it; some profile has to offer one.
require "json"
begin
  catalog = JSON.parse(File.read(File.join(GAMES, "catalog.json")))["profiles"]
  keys = catalog.map { |p| p["key"] }
  folders = Dir.glob(File.join(GAMES, "*", "manifest.rb")).map { |p| File.basename(File.dirname(p)) }
  folders = folders.reject { |k| k =~ /_common\z/ }
  problems << "games/ folder without a catalog entry: #{(folders - keys).join(', ')}" unless (folders - keys).empty?
  problems << "catalog entry without a games/ folder: #{(keys - folders).join(', ')}" unless (keys - folders).empty?

  best_title = lambda do |title|
    tl = title.downcase
    pairs = []
    catalog.each do |q|
      (q["titles"] || []).each do |cand|
        c = cand.to_s.downcase
        pairs.push([c.length, q]) if !c.empty? && tl.include?(c)
      end
    end
    pair = pairs.max_by { |len, _q| len }
    pair ? pair[1] : nil
  end

  normalize = lambda { |s| s.to_s.downcase.tr("áéíóúüñ", "aeiouun") }

  valid_engines = ["gen6", "gamedata", "any"]
  catalog.each do |q|
    e = q["engine"]
    problems << "profile #{q['key']} engine invalid or missing (#{e.inspect})" unless valid_engines.include?(e)
  end

  catalog.each do |q|
    next unless q.key?("compat")
    c = q["compat"].to_s
    ok = c =~ /\A[a-z0-9_]+\.rb\z/ && File.file?(File.join(GAMES, q["key"].to_s, c))
    problems << "profile #{q['key']} compat is not a .rb file of its folder (#{c.inspect})" unless ok
  end

  converts = catalog.select { |q| q["convert"] }
  problems << "no catalog profile offers a conversion" if converts.empty?
  converts.each do |q|
    marks = q["markers"]
    ok = q["convert"].to_s =~ /\A[a-z0-9][a-z0-9.\-]*\z/ && marks.is_a?(Array) && !marks.empty? &&
         marks.all? { |m| m.is_a?(String) && m !~ %r{[\\/]|\.\.} && !m.strip.empty? }
    problems << "profile #{q['key']} convert does not name an engine and the files that mark the game" unless ok
  end

  catalog.each do |q|
    next if q["key"] == "generic"
    layers = [q["titles"], q["exes"]].map { |a| a.is_a?(Array) ? a.length : 0 }.inject(0) { |s, n| s + n }
    layers += 1 if q["detect"] && !q["detect"].to_s.empty?
    problems << "profile #{q['key']} has no identity layer (titles/detect/exes all empty)" if layers == 0
  end

  catalog.each do |q|
    next unless q["detect"]
    begin
      Regexp.new(q["detect"], Regexp::IGNORECASE)
    rescue RegexpError => e
      problems << "invalid detect regex (#{q['key']}): #{e.message}"
    end
  end

  best_regex = lambda do |hay|
    hl = normalize.call(hay)
    pairs = catalog.map do |q|
      next nil unless q["detect"]
      m = (hl.match(/#{q["detect"]}/i) rescue nil)
      m ? [m[0].length, q] : nil
    end
    pair = pairs.compact.max_by { |len, _q| len }
    pair ? pair[1] : nil
  end

  catalog.each do |p|
    (p["titles"] || []).each do |t|
      owner = best_title.call(t)
      if owner && owner["key"] != p["key"]
        problems << "title collision: '#{t}' (#{p['key']}) resolves to '#{owner['key']}' under longest-match"
      end
    end
    if p["detect"]
      owner = best_regex.call(p["display"].to_s)
      if owner.nil?
        problems << "dead detect: '#{p['detect']}' (#{p['key']}) matches nothing, not even its own display (a JSON escape like \\b eaten down to a control char looks exactly like this)"
      elsif owner["key"] != p["key"]
        problems << "detect collision: display '#{p['display']}' resolves to '#{owner['key']}', not its own '#{p['key']}'"
      end
    end
  end

  claimed = {}
  catalog.each do |p|
    (p["exes"] || []).each do |x|
      xl = x.to_s.downcase
      next if xl.empty?
      problems << "generic exe in catalog: '#{x}' (#{p['key']}) can never identify a game" if xl == "game.exe"
      problems << "exe claimed twice: '#{x}' by #{claimed[xl]} and #{p['key']}" if claimed[xl]
      claimed[xl] = p["key"]
    end
  end
rescue StandardError => e
  problems << "catalog check failed to run: #{e.class}: #{e.message}"
end

if problems.empty?
  puts "manifest_check: OK (core #{entries.length} entries + #{profiles.length} profile manifests, all match disk; " \
       "catalog in sync, detect order sound)"
else
  puts "manifest_check: FAIL"
  problems.each { |p| puts "  - #{p}" }
  exit 1
end
