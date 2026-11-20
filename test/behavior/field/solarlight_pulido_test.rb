# Solar Light's Victory Isle on the shipped profile: the hint for each side of the isle, with the assist alone.
class SolarlightPulidoTest < PokeAccessTest
  test "Victory Isle's hint follows the side of the isle, with the assist alone" do
    on_map(227)
    stand(176, 46)
    refute_includes info_key.to_s, t(:solar_isle_h_east)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:solar_isle_h_east)
    stand(84, 21)
    assert_includes info_key, t(:solar_isle_h_east)
    stand(62, 47)
    assert_includes info_key, t(:solar_isle_h_west)
    stand(88, 35)
    assert_includes info_key, t(:solar_isle_h_west)
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def on_map(map)
    Harness.load_puzzles("solarlight")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    stand(1, 1)
  end

  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
    World.next_frame
  end

  def info_key
    PokeAccess::Info.map_text
  end
end
