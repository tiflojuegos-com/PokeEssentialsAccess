# games/catalog.json's patterns, matched as the launcher matches them: a declared title by the longest catalog title it
# contains, else "<folder> <exe>" lowercased by the longest detect match (ties to the first profile); pokemon_z takes
# real Z folders, never a "Z:" drive letter or mkxp-z.
require "json"

class CatalogDetectTest < PokeAccessTest
  CATALOG = File.expand_path("../../games/catalog.json", File.dirname(__FILE__))

  test "the Z pattern matches a real Pokemon Z folder or exe" do
    ["f:/fangames/pokemon z v2.18 game.exe", "f:/juegos/pokemon z/game.exe", "c:/games/pokemonz/game.exe",
     "pokemonz", "pokemon z"].each do |path|
      assert_match detect_pattern("pokemon_z"), path
    end
  end

  test "the Z pattern matches no Z: drive, mkxp-z exe or other game whose name starts with Z" do
    ["z:/juegos/opalo game.exe", "z:/pokemon opalo/game.exe", "d:/games/reminiscenciav2 mkxp-z.exe",
     "c:/mkxp-z/reminiscencia game.exe", "d:/games/pokemon zafiro/game.exe",
     "d:/games/pokemon zeta/game.exe"].each do |path|
      refute_match detect_pattern("pokemon_z"), path
    end
  end

  test "a game on a Z: drive or run by mkxp-z goes to its own profile, and Z's folder to pokemon_z" do
    { "z:/juegos/opalo/game.exe" => "opalo",
      "d:/games/reminiscenciav2 mkxp-z.exe" => "reminiscencia",
      "z:/games/reminiscenciav2/mkxp-z.exe" => "reminiscencia",
      "f:/POKEMON Z V2.18/game.exe" => "pokemon_z" }.each do |path, key|
      assert_equal key, by_folder(path), "for #{path}"
    end
  end

  test "the first Soulstones and its sequel keep apart by folder" do
    { "f:/descargas/soulstones1/soulstones game-z.exe" => "soulstones1",
      "d:/games/soulstones-2 game.exe" => "soulstones2",
      "d:/games/pokemon soulstones 2 game.exe" => "soulstones2",
      "d:/games/soulstones2/game.exe" => "soulstones2",
      "d:/games/time wardens/game.exe" => "soulstones2" }.each do |path, key|
      assert_equal key, by_folder(path), "for #{path}"
    end
  end

  test "the first Soulstones and its sequel keep apart by declared title, the longer title winning" do
    { "Pokemon Soulstones" => "soulstones1", "Pokemon Soulstones 2" => "soulstones2",
      "Pok\u00e9mon Soulstones 2" => "soulstones2" }.each do |title, key|
      assert_equal key, by_title(title), "for #{title.inspect}"
    end
  end

  test "a folder no profile names goes to none, as the generic profile is never detected" do
    ["d:/games/my fangame/game.exe", "c:/juegos/pokemon esmeralda/game.exe", "e:/rpg/generic/game.exe"].each do |path|
      assert_nil by_folder(path), "for #{path}"
    end
    assert_nil by_title("Pokemon Essentials"), "and a stock title"
  end

  test "every unaccented pokemon title carries its accented twin" do
    titles = profiles.map { |e| e["titles"] || [] }.flatten
    assert_operator titles.select { |t| t =~ /\Apokemon / }.uniq.length, :>=, 5, "the catalog lists unaccented titles"
    assert_equal [], titles_without_twin(profiles)
  end

  test "reports an unaccented title whose accented twin is missing" do
    planted = [{ "key" => "a", "titles" => ["pokemon alpha", "pok\u00e9mon alpha", "pokemon beta"] },
               { "key" => "b", "titles" => ["alpha only", "pokemonbeta"] }]
    assert_equal ["pokemon beta"], titles_without_twin(planted)
  end

  private

  # The catalog's profiles, through a real JSON parser as the launcher reads it.
  def profiles
    JSON.parse(File.read(CATALOG))["profiles"]
  end

  # The case-insensitive detect pattern of the profile key.
  def detect_pattern(key)
    entry = profiles.find { |e| e["key"] == key }
    Regexp.new(entry["detect"], Regexp::IGNORECASE)
  end

  # The profile the launcher's folder layer picks for "<folder> <exe>": the longest match in bytes, ties to the first.
  def by_folder(path)
    hay = path.downcase
    best = nil
    profiles.each do |e|
      next unless e["detect"]
      m = hay.match(Regexp.new(e["detect"], Regexp::IGNORECASE))
      best = [e["key"], m[0].bytesize] if m && (best.nil? || m[0].bytesize > best[1])
    end
    best && best[0]
  end

  # The profile the launcher's title layer picks: the longest catalog title the declared one contains, ties to the
  # first.
  def by_title(title)
    tl = title.downcase
    best = nil
    profiles.each do |e|
      (e["titles"] || []).each do |t|
        c = t.downcase
        best = [e["key"], c.bytesize] if !c.empty? && tl.include?(c) && (best.nil? || c.bytesize > best[1])
      end
    end
    best && best[0]
  end

  # The unaccented "pokemon ..." titles of the profiles whose "pokémon ..." twin no profile lists.
  def titles_without_twin(list)
    titles = list.map { |e| e["titles"] || [] }.flatten
    plain = titles.select { |t| t =~ /\Apokemon / }.uniq
    plain.reject { |t| titles.include?(t.sub(/\Apokemon\b/, "pok\u00e9mon")) }.sort
  end
end
