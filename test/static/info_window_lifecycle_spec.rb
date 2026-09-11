# Every watched information window belongs to a scene the mod can actually ENTER.
#
# InfoWindow.watch binds the scene's open and close by name. A name no game answers to binds nothing, and
# the failure leaves no trace anywhere: the class is there, the windows are there, the hook registrations
# all return quietly, and the screen is simply never entered. Nothing in the suite could see it, because
# a stub written for the reader gives it whatever lifecycle the reader asked for -- which is exactly how the
# mart's two windows shipped dead in all fifteen games, declared against pbStartScene/pbEndScene on a screen
# that has neither and names both ends after the mode instead.
#
# The census (lifecycle_census.txt, rebuilt by build_reader_census.rb) holds two sets per class: what the
# mod declares and what the games define. This asks the one question with a single right answer -- do they
# meet? A class no source defines has an empty games set and is skipped: absent is variance, and
# hooked_classes_spec already asks whether anything anywhere answers to the name.
Suite.define("static: every watched information window has a lifecycle its games really have") do
  path = File.join(File.dirname(__FILE__), "lifecycle_census.txt")
  rows = {}
  PokeAccess::KVFile.each(path) do |cls, v|
    decl, games = v.split(";").map { |p| p.to_s.strip }
    rows[cls] = [decl.to_s.sub("declared:", "").split("|").reject { |x| x.empty? },
                 games.to_s.sub("games:", "").split(",").map { |m| m.sub(/\(\d+\)\z/, "") }.reject { |x| x.empty? }]
  end
  truthy "the lifecycle census loaded (#{rows.length} escenas vigiladas)", rows.length >= 6

  # A guard on the guard: the census must actually carry the two sets, or every check below passes on air.
  filled = rows.values.count { |d, g| !d.empty? && !g.empty? }
  truthy "and it carries both sets for most of them (#{filled})", filled >= rows.length - 1

  dead = rows.keys.sort.select { |c| !rows[c][1].empty? && (rows[c][0] & rows[c][1]).empty? }
  eq "no watched scene is declared against a lifecycle no game defines", dead, []

  # The mart is the case that shipped broken, pinned by name so a future edit that drops its :open list
  # fails here rather than going quiet again.
  %w[PokemonMartScene PokemonMart_Scene].each do |cls|
    next unless rows[cls]
    truthy "#{cls} is entered by its own buy scene, not by the engine's opener",
           rows[cls][0].include?("pbStartBuyScene") && rows[cls][1].include?("pbStartBuyScene")
  end
end
