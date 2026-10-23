# The Poke Radar's shaking grass from v20, kept in $game_temp.poke_radar_data: the same patches, read from there.
class PokeradarGrassGdTest < PokeAccessTest
  test "says the patches kept in $game_temp, queued, the same way" do
    with_radar_data([:PIDGEY, 5, 2, [[5, 4, 0, 2], [7, 5, 1, 0]]]) { pbPokeRadarHighlightGrass }
    assert_equal [["#{patch(:radar_kind_shiny, "1 #{t(:dir_up)}")}; #{patch(:radar_kind_normal, "2 #{t(:dir_right)}")}",
                   false]],
                 SpeakCapture.log
  end

  test "reads $game_temp's data over an older $PokemonTemp's" do
    with_pokemon_temp([:PIDGEY, 5, 0, [[5, 6, 0, 1]]]) do
      with_radar_data([:PIDGEY, 5, 2, [[5, 4, 0, 2]]]) { pbPokeRadarHighlightGrass }
    end
    assert_equal [patch(:radar_kind_shiny, "1 #{t(:dir_up)}")], SpeakCapture.lines
  end

  test "with the radar switched off, says nothing" do
    with_radar_data(nil) { pbPokeRadarHighlightGrass }
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

  # Runs the block with $game_temp.poke_radar_data answering data, the player at (5, 5) as Reset leaves them.
  def with_radar_data(data)
    $game_temp.define_singleton_method(:poke_radar_data) { data }
    yield
  ensure
    $game_temp.singleton_class.send(:remove_method, :poke_radar_data)
  end

  # Runs the block with an older engine's $PokemonTemp.pokeradar holding data, the global put back after.
  def with_pokemon_temp(data)
    old = $PokemonTemp
    $PokemonTemp = Struct.new(:pokeradar).new(data)
    yield
  ensure
    $PokemonTemp = old
  end
end
