# Regression over the real games/catalog.json autodetect patterns. Both consumers (the launcher's
# catalog.rs and installer install.ps1) build the haystack as "folder + exe", lowercase it, and match each
# profile's `detect` regex case-insensitively -- the LONGEST match wins, not the first in file order (the
# layered detection decided 2026-08-01; modelling first-match here would test an algorithm neither
# consumer runs any more, and a future collision that only surfaces under longest-match would pass).
# The pokemon_z pattern used to include a bare \bz\b that matched a "Z:" drive letter and "mkxp-z.exe",
# so pokemon_z shadowed every other game. This asserts the pattern still matches real Pokemon Z folders
# but never a drive letter or mkxp-z, and that another profile still wins on such paths.
CATALOG_JSON = File.join(File.expand_path("../..", __dir__), "games", "catalog.json")

# Builds the match haystack exactly as the launcher/installer do: "<folder> <exe>", lowercased.
def catalog_haystack(path)
  path.downcase
end

# The detect regexp for a profile key, compiled case-insensitively like both consumers, or nil if the
# profile is absent or has a null pattern.
def detect_regexp_for(key)
  raw = File.read(CATALOG_JSON)
  entry = raw[/\{[^{}]*"key"\s*:\s*"#{Regexp.escape(key)}".*?\}/m]
  return nil unless entry
  pat = entry[/"detect"\s*:\s*"((?:[^"\\]|\\.)*)"/, 1]
  return nil if pat.nil?
  Regexp.new(pat.gsub('\\\\', '\\'), Regexp::IGNORECASE)
end

# Resolves which profile key wins for a haystack, mirroring the consumers' layer 2: among every detect
# that matches, the one whose MATCHED TEXT is longest wins (ties keep file order, as both consumers do).
def detect_profile(path)
  raw = File.read(CATALOG_JSON)
  hay = catalog_haystack(path)
  best = nil
  best_len = -1
  raw.scan(/"key"\s*:\s*"([^"]+)"[^{}]*?"detect"\s*:\s*(null|"((?:[^"\\]|\\.)*)")/m).each do |key, detect, pat|
    next if detect == "null"
    m = hay.match(Regexp.new(pat.gsub('\\\\', '\\'), Regexp::IGNORECASE))
    next if m.nil? || m[0].length <= best_len
    best = key
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

# Layer 1 matches the game's DECLARED title, and the declared title is written by a Spanish-speaking
# author: Anil's live mkxp.json says "Pokémon Añil 4.0". Every candidate for it read "pokemon ...", so
# the accent in Poke'mon -- not the one in Anil, which was covered -- made layer 1 miss, on both the
# installer and the launcher. Nothing broke because layer 2 caught it by folder name; rename the folder
# and both would have failed together, which is exactly the kind of fallback that hides a bug until the
# day it cannot.
#
# The fix is data, not code: it is the one place both consumers already read, so no two-language port to
# keep in sync. This keeps it that way as games are added.
Suite.define("catalog: every unaccented pokemon title carries its accented twin") do
  raw = File.read(CATALOG_JSON)
  # Only the titles arrays: the detect patterns are regexps and "pokemon ?z\b" is not a title.
  plain = raw.scan(/"titles"\s*:\s*\[(.*?)\]/m).flatten.join(",").scan(/"(pokemon [^"]*)"/).flatten.uniq
  truthy "the catalog really does list unaccented titles", plain.length >= 5
  missing = plain.reject do |t|
    raw.index("\"" + t.sub(/\Apokemon\b/, [0x70, 0x6f, 0x6b, 0xe9, 0x6d, 0x6f, 0x6e].pack("U*")) + "\"")
  end
  eq "each has its accented twin", missing.sort, []
end
