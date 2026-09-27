# games/catalog.json's detect patterns, matched as the launcher does (lowercased, case-insensitive, longest match
# wins): pokemon_z matches real Z folders, never a "Z:" drive letter or mkxp-z.
require "json"

CATALOG_JSON = File.join(File.expand_path("../..", __dir__), "games", "catalog.json")

# Builds the match haystack exactly as the launcher does: "<folder> <exe>", lowercased.
def catalog_haystack(path)
  path.downcase
end

# The catalog's profiles through a real JSON parser, as the launcher reads it (serde_json).
def catalog_profiles
  JSON.parse(File.read(CATALOG_JSON))["profiles"]
end

# The detect regexp for a profile key, compiled case-insensitively like the launcher, or nil if the
# profile is absent or has a null pattern.
def detect_regexp_for(key)
  entry = catalog_profiles.find { |e| e["key"] == key }
  return nil unless entry && entry["detect"]
  Regexp.new(entry["detect"], Regexp::IGNORECASE)
end

# The winning profile key for a path, as the launcher's layer 2 picks it: longest matched text, ties in file order.
def detect_profile(path)
  hay = catalog_haystack(path)
  best = nil
  best_len = -1
  catalog_profiles.each do |e|
    next unless e["detect"]
    m = hay.match(Regexp.new(e["detect"], Regexp::IGNORECASE))
    next if m.nil? || m[0].length <= best_len
    best = e["key"]
    best_len = m[0].length
  end
  best
end

Suite.define("catalog: pokemon_z detect matches real Z folders, not drive letter or mkxp-z") do
  rx = detect_regexp_for("pokemon_z")
  truthy "pokemon_z profile present with a detect pattern", rx

  ["f:/fangames/pokemon z v2.18 game.exe",
   "f:/juegos/pokemon z/game.exe",
   "c:/games/pokemonz/game.exe",
   "pokemonz",
   "pokemon z"].each do |p|
    truthy "matches real Z path: #{p}", (rx =~ catalog_haystack(p) ? true : false)
  end

  ["z:/juegos/opalo game.exe",
   "z:/pokemon opalo/game.exe",
   "d:/games/reminiscenciav2 mkxp-z.exe",
   "c:/mkxp-z/reminiscencia game.exe",
   "d:/games/pokemon zafiro/game.exe",
   "d:/games/pokemon zeta/game.exe"].each do |p|
    falsy "does not match trap path: #{p}", (rx =~ catalog_haystack(p) ? true : false)
  end
end

Suite.define("catalog: pokemon_z no longer shadows other profiles on Z-drive or mkxp-z paths") do
  eq "opalo on a Z: drive resolves to opalo", detect_profile("z:/juegos/opalo/game.exe"), "opalo"
  eq "reminiscencia via mkxp-z.exe resolves to reminiscencia", detect_profile("d:/games/reminiscenciav2 mkxp-z.exe"), "reminiscencia"
  eq "reminiscencia on Z: drive with mkxp-z resolves to reminiscencia", detect_profile("z:/games/reminiscenciav2/mkxp-z.exe"), "reminiscencia"
  eq "real Pokemon Z folder still resolves to pokemon_z", detect_profile("f:/POKEMON Z V2.18/game.exe"), "pokemon_z"
end

Suite.define("catalog: the first Soulstones and its sequel keep apart, by folder and by title") do
  eq "the first game's own folder resolves to soulstones1",
     detect_profile("f:/descargas/soulstones1/soulstones game-z.exe"), "soulstones1"
  ["d:/games/soulstones-2 game.exe", "d:/games/pokemon soulstones 2 game.exe", "d:/games/soulstones2/game.exe",
   "d:/games/time wardens/game.exe"].each do |p|
    eq "the sequel's folder stays with soulstones2: #{p}", detect_profile(p), "soulstones2"
  end
  longest = lambda do |title|
    tl = title.downcase
    hits = catalog_profiles.map { |e| [e["key"], (e["titles"] || []).select { |t| tl.include?(t) }.map { |t| t.length }.max] }
    hits.reject { |_k, n| n.nil? }.sort_by { |_k, n| -n }.map { |k, _n| k }.first
  end
  eq "the first game's Game.ini title declares it", longest.call("Pokemon Soulstones"), "soulstones1"
  eq "and the sequel's longer title still wins its own game", longest.call("Pokemon Soulstones 2"), "soulstones2"
end

# Layer 1 matches the declared title, which may be accented: each unaccented "pokemon" title has its accented twin.
Suite.define("catalog: every unaccented pokemon title carries its accented twin") do
  titles = catalog_profiles.map { |e| e["titles"] || [] }.flatten
  plain = titles.select { |t| t =~ /\Apokemon / }.uniq
  truthy "the catalog really does list unaccented titles", plain.length >= 5
  accented = [0x70, 0x6f, 0x6b, 0xe9, 0x6d, 0x6f, 0x6e].pack("U*")
  missing = plain.reject { |t| titles.include?(t.sub(/\Apokemon\b/, accented)) }
  eq "each has its accented twin", missing.sort, []
end
