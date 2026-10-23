# The field-move rules each game profile gives the mod hold against the game's own scripts (field_move_census.txt,
# built from the dumps by build_field_move_census.rb): every function a game clears its obstacles and crosses water
# with asks for its stock move, wraps the one that does, or has its move ruled by the profile, and every item, move
# and switch it reads is one the profile names. So under a game's own profile the mod names what clears an obstacle,
# and says when it is missing, by the game's rules (FieldMoves.named?).
class FieldMovesStaticTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  CENSUS = File.join(File.dirname(__FILE__), "field_move_census.txt")
  # The move each function of the census asks for.
  STOCK = { "pbCut" => "CUT", "pbRockSmash" => "ROCKSMASH", "pbStrength" => "STRENGTH", "pbSurf" => "SURF",
            "pbWaterfall" => "WATERFALL", "pbWaterfallDialogue" => "WATERFALL", "pbDive" => "DIVE" }
  # Dump folders named apart from their profile.
  PROFILE_OF = { "africanvs" => "africanus", "z218" => "pokemon_z" }
  # Plugins whose field functions the core reads by their own rules: Advanced Items' item configurations
  # (FieldMoves.advanced_items_config).
  CORE_PLUGINS = [/Advanced Items/]
  # Switches a field function tests that decide nothing about whether the move can be used, and why.
  INERT_SWITCHES = {
    "Following_Activated_Switch" => "lets the following Pokemon past the refusal while someone follows the player",
    "Cut_Convenience" => "skips the game's question once the move was used on the map",
    "Rock_Smash_Convenience" => "skips the game's question once the move was used on the map",
    "Surf_Convenience" => "skips the game's question once the move was used on the map",
    "Waterfall_Convenience" => "skips the game's question once the move was used on the map",
    "Stop_Arrows_Shooting" => "is set while the move plays",
    "Stop_Icycle_Falling" => "is set while the move plays",
    "Wall_Smash" => "picks the message a breakable wall gets"
  }

  test "static: every field function of a game with its own profile is ruled by that profile" do
    rows = census
    refute rows.empty?, "the census has rows (ruby test/static/build_field_move_census.rb)"
    problems = []
    rows.each do |dump, fn, where, guard, calls, names|
      next unless guard.empty? && CORE_PLUGINS.none? { |re| where =~ re }
      src = sources(PROFILE_OF[dump] || dump)
      stock = STOCK[fn]
      wraps = calls.any? { |c| c != fn && (c.end_with?(fn) || c == "#{fn}Dialogue") }
      unless names.include?(stock) || wraps || src =~ /:#{stock}\b/
        problems.push("#{dump} #{where}: #{fn} asks for no #{stock} and the profile rules no :#{stock}")
      end
      (names - [stock]).each do |n|
        problems.push("#{dump} #{where}: #{fn} reads #{n}, which the profile never names") unless named?(src, n)
      end
    end
    assert_equal [], problems
  end

  test "static: every game with its own profile is in the census" do
    dumps = census.map { |r| PROFILE_OF[r[0]] || r[0] }.uniq
    own = Dir.glob(File.join(ROOT, "games", "*", "manifest.rb")).map { |m| File.basename(File.dirname(m)) }
    own = own.reject { |p| p == "generic" || p =~ /_common\z/ }
    assert_equal [], own - dumps, "each profile's dump is in the census (ruby test/static/build_field_move_census.rb)"
  end

  private

  # The census rows: [dump, function, where, guard, the functions it calls, the names it reads].
  def census
    File.readlines(CENSUS).reject { |l| l.start_with?("#") || l.strip.empty? }.map do |l|
      d, f, w, g, c, n = l.chomp.split("|", -1)
      [d, f, w, g, c.split(","), n.split(",")]
    end
  end

  # The source a profile runs with: its own files, its imports' and its declared plugins'.
  def sources(profile)
    @sources ||= {}
    @sources[profile] ||= begin
      dir = File.join(ROOT, "games", profile)
      man = eval(File.read(File.join(dir, "manifest.rb")))
      dirs = [dir] + (man[:imports] || []).map { |i| File.join(ROOT, "games", i) }
      files = dirs.map { |d| Dir.glob(File.join(d, "**", "*.rb")) }.flatten
      files += (man[:plugins].is_a?(Array) ? man[:plugins] : []).map { |p| File.join(ROOT, "plugins", "#{p}.rb") }
      files.map { |f| File.read(f) }.join("\n")
    end
  end

  # Whether a profile's source names what a field function reads: a switch by its symbol, or tested by its number or a
  # constant holding it, unless it decides nothing (INERT_SWITCHES); an item or move by its symbol or constant.
  def named?(src, name)
    return src =~ /\b#{Regexp.escape(name)}\b/ unless name.start_with?("switch:")
    id = name.sub("switch:", "")
    return true if INERT_SWITCHES.key?(id)
    return src =~ /:#{Regexp.escape(id)}\b/ unless id =~ /\A\d+\z/
    held = src.scan(/\b([A-Z][A-Z0-9_]*)\s*=\s*#{id}\b/).flatten
    ([id] + held).any? { |n| src =~ /\$game_switches\[\s*#{n}\s*\]/ }
  end
end
