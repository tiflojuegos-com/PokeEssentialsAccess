# The Poke Radar's shaking grass up to v19, kept in $PokemonTemp.pokeradar: after each search every patch it shook is
# said, queued, by how it shakes and where it lies from the player, in the game's ring order.
class PokeradarGrassTest < PokeAccessTest
  test "says each patch a search shook by its shaking and its place, queued, in ring order" do
    stand_at(10, 10)
    with_radar([[11, 9, 0, 0], [8, 10, 1, 1], [10, 13, 2, 2]]) { pbPokeRadarHighlightGrass }
    assert_equal [[[patch(:radar_kind_normal, "1 #{t(:dir_right)}, 1 #{t(:dir_up)}"),
                    patch(:radar_kind_vigorous, "2 #{t(:dir_left)}"),
                    patch(:radar_kind_shiny, "3 #{t(:dir_down)}")].join("; "), false]],
                 SpeakCapture.log
  end

  test "a patch under the player is said to be right there" do
    stand_at(4, 4)
    with_radar([[4, 4, 0, 1]]) { pbPokeRadarHighlightGrass }
    assert_equal [patch(:radar_kind_vigorous, t(:loc_here))], SpeakCapture.lines
  end

  test "a rarity the radar does not name is said as plain shaking grass" do
    stand_at(4, 4)
    { 7 => "a rarity past the shiny one", nil => "no rarity at all" }.each do |rarity, what|
      SpeakCapture.clear
      with_radar([[5, 4, 0, rarity]]) { pbPokeRadarHighlightGrass }
      assert_equal [patch(:radar_kind_normal, "1 #{t(:dir_right)}")], SpeakCapture.lines, what
    end
  end

  test "an entry without the stock place and ring is left out, the rest still said" do
    stand_at(4, 4)
    patches = [[3, 4], [4, nil, 0, 0], [nil, 4, 0, 0], ["5", 4, 0, 0], [5, 6, nil, 1], :grass, [4, 5, 0, 2]]
    with_radar(patches) { pbPokeRadarHighlightGrass }
    assert_equal [patch(:radar_kind_shiny, "1 #{t(:dir_down)}")], SpeakCapture.lines
  end

  test "a search that shook nothing, or a radar switched off, says nothing" do
    { "no patches" => [], "patches without the stock ring" => [[3, 4]], "the radar off" => nil }.each do |what, patches|
      SpeakCapture.clear
      with_radar(patches) { pbPokeRadarHighlightGrass }
      assert_nothing_spoken what
    end
  end

  test "radar state with no patch list says nothing" do
    with_temp([:PIDGEY, 5, 0, nil]) { pbPokeRadarHighlightGrass }
    assert_nothing_spoken
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # One patch as said: its kind of shaking and where it lies.
  def patch(kind, where)
    t(:radar_patch, :kind => t(kind), :where => where)
  end

  # Puts the player at (x, y); Reset puts them back.
  def stand_at(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # Runs the block with the radar's last search having shaken the given patches ([x, y, ring, rarity] each), or with
  # the radar off for nil.
  def with_radar(patches, &blk)
    with_temp(patches.nil? ? nil : [:PIDGEY, 5, 0, patches], &blk)
  end

  # Runs the block with $PokemonTemp.pokeradar holding data, the game's $PokemonTemp put back after.
  def with_temp(data)
    old = $PokemonTemp
    $PokemonTemp = Struct.new(:pokeradar).new(data)
    yield
  ensure
    $PokemonTemp = old
  end
end
