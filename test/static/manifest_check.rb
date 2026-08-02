# Checks EVERY manifest.rb against the files on disk -- core/manifest.rb and each games/<profile>/manifest.rb.
# In each of those folders every **/*.rb (except its own manifest.rb) must be listed exactly once, and every
# listed entry must have a file. Catches the two failure modes that have bitten releases -- a new reader added
# but not registered (loads nowhere) and a manifest entry whose file was moved or renamed (NameError at boot).
# The profiles need the same net as core and had none: the loader evals games/<key>/<entry>.rb for each listed
# entry, so a renamed profile file half-wires that ONE game (its menus go silent) while every other game and
# the whole test suite stay green -- invisible until a player reports it. Syntax is not re-checked here; the
# real 1.8.7 interpreter already parses these files (check187_real.rb).
# A pure-filesystem check, no engine stubs needed; exits non-zero on any gap, naming the culprit folder.
ROOT = File.expand_path("../..", __dir__)
CORE = File.join(ROOT, "core")
GAMES = File.join(ROOT, "games")

# The module entries listed in a manifest file, as "subsystem/name" strings, or nil when the file carries no
# %w[...] list at all (a manifest the loader cannot turn into a module list, so its whole folder loads nothing).
#
# A profile that declares third-party plugin readers has TWO lists ({:modules => %w[], :plugins => %w[]}),
# and only the first is this folder's own files. Anchoring on ":modules =>" instead of taking whichever
# %w[...] comes first is the difference between checking the right list and checking whichever one someone
# happened to write above the other -- which would pass while validating nothing.
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

# The manifest<->disk gaps of one folder as problem lines, each prefixed with the folder that owns it so a
# failure names the culprit instead of leaving core plus a dozen profiles to be diffed by hand.
def folder_problems(label, dir)
  entries = manifest_entries(File.join(dir, "manifest.rb"))
  return ["#{label}: manifest.rb has no %w[...] module list"] if entries.nil?
  missing_file = entries.reject { |e| File.file?(File.join(dir, "#{e}.rb")) }
  not_listed   = disk_modules(dir) - entries
  dupes        = entries.select { |e| entries.count(e) > 1 }.uniq
  out = []
  out << "#{label}: listed but no file: #{missing_file.join(', ')}" unless missing_file.empty?
  out << "#{label}: on disk but not listed: #{not_listed.join(', ')}" unless not_listed.empty?
  out << "#{label}: listed more than once: #{dupes.join(', ')}" unless dupes.empty?
  out
end

profiles = Dir.glob(File.join(GAMES, "*", "manifest.rb")).sort.map { |p| File.dirname(p) }
problems = folder_problems("core", CORE)
profiles.each { |dir| problems.concat(folder_problems("games/#{File.basename(dir)}", dir)) }
entries = (manifest_entries(File.join(CORE, "manifest.rb")) || [])

# The profile<->installer contract (games/catalog.json is the single source both installers read):
# (a) every games/<key>/ folder with a manifest has a catalog entry and vice versa; (c) the LAYERED
# detection both installers implement must resolve each profile's own signals to itself -- every
# declared title picks its owner under longest-declared-match, every display resolves its owner under
# longest-regex-match, and no distinctive exe is claimed twice. An over-broad new regex or a colliding
# title breaks CI here with the culprit named, instead of misdetecting a player's game in silence.
require "json"
begin
  catalog = JSON.parse(File.read(File.join(GAMES, "catalog.json")))["profiles"]
  keys = catalog.map { |p| p["key"] }
  folders = Dir.glob(File.join(GAMES, "*", "manifest.rb")).map { |p| File.basename(File.dirname(p)) }
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

  # Folder names in the wild are accent-free, so probes run on a de-accented lowercase form of the
  # display ("Pokémon Z" -> "pokemon z"); a detect regex that cannot even match that form is dead.
  normalize = lambda { |s| s.to_s.downcase.tr("áéíóúüñ", "aeiouun") }

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
