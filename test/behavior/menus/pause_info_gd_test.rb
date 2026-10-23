# The modern pause menu's info box (PokemonPauseMenu_Scene#pbShowInfo, v19 on): the contest's catch and balls, read
# queued as the menu opens, a piece per line; pause_info_test pins the edge cases on the classic scene.
class PauseInfoGdTest < PokeAccessTest
  test "the contest box is said as the menu opens, a piece per line, queued" do
    scene = PokemonPauseMenu_Scene.new
    scene.pbStartScene
    scene.pbShowInfo("Caught: Caterpie\nLevel: 7\nBalls: 12")
    assert_equal [["Caught: Caterpie, Level: 7, Balls: 12", false]], SpeakCapture.log
  end

  test "an empty box says nothing" do
    PokemonPauseMenu_Scene.new.pbShowInfo("")
    assert_nothing_spoken
  end
end
