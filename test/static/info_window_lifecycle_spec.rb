# Every watched information window belongs to a scene the mod can enter: per lifecycle_census.txt, the lifecycle
# the mod declares meets one the games define; a class no source defines is left to hooked_classes_spec.
Suite.define("static: every watched information window has a lifecycle its games really have") do
  path = File.join(File.dirname(__FILE__), "lifecycle_census.txt")
  rows = {}
  PokeAccess::KVFile.each(path) do |cls, v|
    decl, games = v.split(";").map { |p| p.to_s.strip }
    rows[cls] = [decl.to_s.sub("declared:", "").split("|").reject { |x| x.empty? },
                 games.to_s.sub("games:", "").split(",").map { |m| m.sub(/\(\d+\)\z/, "") }.reject { |x| x.empty? }]
  end
  truthy "the lifecycle census loaded (#{rows.length} escenas vigiladas)", rows.length >= 6

  filled = rows.values.count { |d, g| !d.empty? && !g.empty? }
  truthy "and it carries both sets for most of them (#{filled})", filled >= rows.length - 1

  dead = rows.keys.sort.select { |c| !rows[c][1].empty? && (rows[c][0] & rows[c][1]).empty? }
  eq "no watched scene is declared against a lifecycle no game defines", dead, []

  %w[PokemonMartScene PokemonMart_Scene].each do |cls|
    next unless rows[cls]
    truthy "#{cls} is entered by its own buy scene, not by the engine's opener",
           rows[cls][0].include?("pbStartBuyScene") && rows[cls][1].include?("pbStartBuyScene")
  end
end
