# Covers the real games/catalog.json autodetect patterns. Both consumers (the launcher's
# catalog.rs and installer install.ps1) build the haystack as "folder + exe", lowercase it, and match each
# profile's `detect` regex case-insensitively -- the LONGEST match wins, not the first in file order (the
# layered detection decided 2026-08-01; modelling first-match here would test an algorithm neither
# consumer runs any more, and a future collision that only surfaces under longest-match would pass).
# A bare \bz\b in the pokemon_z pattern matches a "Z:" drive letter and "mkxp-z.exe", which makes pokemon_z
# shadow every other game. This asserts the pattern still matches real Pokemon Z folders
# but never a drive letter or mkxp-z, and that another profile still wins on such paths.
require "json"

CATALOG_JSON = File.join(File.expand_path("../..", __dir__), "games", "catalog.json")

# Builds the match haystack exactly as the launcher/installer do: "<folder> <exe>", lowercased.
def catalog_haystack(path)
  path.downcase
end

# The catalog through a real JSON parser, like both consumers (ConvertFrom-Json, serde_json). The old
# readers scraped the RAW text with regexps and undid the escapes by hand, so a broken escape in a detect
# pattern handed this spec a different regexp than the one either consumer would run; parsed, all three
# see the same string, and a catalog that stops parsing fails loudly here too.
def catalog_profiles
  JSON.parse(File.read(CATALOG_JSON))["profiles"]
end

# The detect regexp for a profile key, compiled case-insensitively like both consumers, or nil if the
# profile is absent or has a null pattern.
def detect_regexp_for(key)
  entry = catalog_profiles.find { |e| e["key"] == key }
  return nil unless entry && entry["detect"]
  Regexp.new(entry["detect"], Regexp::IGNORECASE)
end

# Resolves which profile key wins for a haystack, mirroring the consumers' layer 2: among every detect
# that matches, the one whose MATCHED TEXT is longest wins (ties keep file order, as both consumers do).
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

# Layer 1 matches the game's DECLARED title, and the declared title is written by a Spanish-speaking
# author: Anil's live mkxp.json says "Pokémon Añil 4.0". Every candidate for it read "pokemon ...", so
# the accent in Poke'mon -- not the one in Anil, which was covered -- made layer 1 miss, on both the
# installer and the launcher. Layer 2 catches it by folder name, so a rename breaks both at once -- exactly
# the kind of fallback that hides a fault until the day it cannot.
#
# Data and not code: catalog.json is the one place both consumers already read, so there is no two-language
# port to keep in sync. This keeps it that way as games are added.
Suite.define("catalog: every unaccented pokemon title carries its accented twin") do
  titles = catalog_profiles.map { |e| e["titles"] || [] }.flatten
  plain = titles.select { |t| t =~ /\Apokemon / }.uniq
  truthy "the catalog really does list unaccented titles", plain.length >= 5
  accented = [0x70, 0x6f, 0x6b, 0xe9, 0x6d, 0x6f, 0x6e].pack("U*")
  missing = plain.reject { |t| titles.include?(t.sub(/\Apokemon\b/, accented)) }
  eq "each has its accented twin", missing.sort, []
end
