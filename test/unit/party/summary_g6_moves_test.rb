# SummaryGen6's reading of a gen-6 summary redraw's arguments: the Pokemon a page is about, and the Pokemon and move id
# of a move-detail redraw, the id being the argument after moveToLearn in each of its three shapes.
class SummaryG6MovesTest < PokeAccessTest
  test "takes the move id after moveToLearn, and the Pokemon, from each shape of a move-detail redraw" do
    scene = scene_showing(:scene_pokemon)
    [["vanilla (pokemon, moveToLearn, moveid)", [:passed, 0, 33], [:passed, 33]],
     ["Awakening's (moveToLearn, moveid), the Pokemon the scene's", [0, 33], [:scene_pokemon, 33]],
     ["the oldest (pokemon, moveToLearn, moveid, shouldDrawSecond)", [:passed, 0, 33, true], [:passed, 33]]
    ].each do |shape, args, want|
      assert_equal want, PokeAccess::SummaryGen6.selected_move(scene, args), shape
    end
  end

  test "takes a page redraw's Pokemon from its argument, else from the scene, as Awakening passes none" do
    scene = scene_showing(:scene_pokemon)
    assert_equal :passed, PokeAccess::SummaryGen6.subject(scene, [:passed]), "the Pokemon passed"
    assert_equal :scene_pokemon, PokeAccess::SummaryGen6.subject(scene, []), "none passed"
  end

  private

  # A summary scene showing pokemon, kept as its @pokemon.
  def scene_showing(pokemon)
    scene = Object.new
    scene.instance_variable_set(:@pokemon, pokemon)
    scene
  end
end
