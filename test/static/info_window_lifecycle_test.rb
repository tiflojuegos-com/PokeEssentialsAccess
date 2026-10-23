# Every watched information window belongs to a scene the mod can enter: per lifecycle_census.txt, the lifecycle
# the mod declares meets one the games define; a class no source defines is left to hooked_classes_test.
class InfoWindowLifecycleTest < PokeAccessTest
  CENSUS = File.join(File.dirname(__FILE__), "lifecycle_census.txt")

  test "no watched scene is declared against a lifecycle no game defines" do
    rows = census
    assert_operator rows.length, :>=, 6, "the census lists the watched scenes"
    assert_equal [], dead(rows)
  end

  test "the census knows both lifecycles of all but one watched scene at most" do
    rows = census
    assert_operator rows.values.count { |d, g| !d.empty? && !g.empty? }, :>=, rows.length - 1
  end

  test "the marts are entered by their own buy scene, not by the engine's opener" do
    rows = census
    %w[PokemonMartScene PokemonMart_Scene].each do |cls|
      refute_nil rows[cls], "#{cls} is watched"
      assert_includes rows[cls][0], "pbStartBuyScene", "#{cls}: the mod declares the buy scene"
      assert_includes rows[cls][1], "pbStartBuyScene", "#{cls}: the games define it"
    end
  end

  test "a watch whose declared lifecycle meets none its games define is dead, one no source defines is not" do
    rows = {
      "Met" => [["pbStartScene", "start"], ["pbEndScene", "pbStartScene"]],
      "Missed" => [["pbStartScene", "start"], ["pbEndScene", "pbStartBuyScene"]],
      "Undefined" => [["pbStartScene"], []]
    }
    assert_equal ["Missed"], dead(rows)
  end

  test "a census line reads as the declared lifecycle and the games' methods, their counts dropped" do
    {
      "declared:pbStartScene|start ; games:pbEndScene(5),pbStartScene(11)" =>
        [["pbStartScene", "start"], ["pbEndScene", "pbStartScene"]],
      "declared:start ; games:" => [["start"], []],
      "declared: ; games:start(15)" => [[], ["start"]]
    }.each { |value, want| assert_equal want, row(value), "for #{value}" }
  end

  private

  # { class => [declared lifecycle, games' methods] } from the census.
  def census
    rows = {}
    PokeAccess::KVFile.each(CENSUS) { |cls, v| rows[cls] = row(v) }
    rows
  end

  # One census value, "declared:a|b ; games:a(n),b(n)", as [declared, games' methods without their counts].
  def row(value)
    decl, games = value.split(";").map { |p| p.to_s.strip }
    [decl.to_s.sub("declared:", "").split("|").reject { |x| x.empty? },
     games.to_s.sub("games:", "").split(",").map { |m| m.sub(/\(\d+\)\z/, "") }.reject { |x| x.empty? }]
  end

  # The watched classes, sorted, whose games define methods none of which the mod declares.
  def dead(rows)
    rows.keys.sort.select { |c| !rows[c][1].empty? && (rows[c][0] & rows[c][1]).empty? }
  end
end
