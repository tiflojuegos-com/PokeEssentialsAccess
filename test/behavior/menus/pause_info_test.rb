# The classic pause menu's info box (PokemonMenu_Scene#pbShowInfo: Safari steps and balls, the contest's catch), read
# queued as the menu opens, a piece per line, before the focused command; pause_info_gd_test pins the modern scene.
class PauseInfoTest < PokeAccessTest
  test "the Safari box is said as the menu opens, a piece per line, queued before the focused command" do
    scene = PokemonMenu_Scene.new
    scene.pbStartScene
    scene.pbShowInfo("Pasos: 120/600\nBalls: 30")
    scene.pbShowCommands(["Pokédex", "Bolsa"])
    assert_equal [["Pasos: 120/600, Balls: 30", false], ["Pokédex", false]], SpeakCapture.log
  end

  test "the box's blank lines are left out" do
    PokemonMenu_Scene.new.pbShowInfo("Pasos: 120/600\n\n  \nBalls: 30\n")
    assert_equal [["Pasos: 120/600, Balls: 30", false]], SpeakCapture.log
  end

  test "the box's text codes are left out, and a line of codes alone goes with them" do
    PokemonMenu_Scene.new.pbShowInfo("\\c[2]Pasos: 120/600\n\\c[1]\nBalls: <b>30</b>")
    assert_equal [["Pasos: 120/600, Balls: 30", false]], SpeakCapture.log
  end

  test "an empty box, or none, says nothing" do
    ["", "\n", nil].each do |text|
      SpeakCapture.clear
      PokemonMenu_Scene.new.pbShowInfo(text)
      assert_nothing_spoken "the box #{text.inspect}"
    end
  end

  test "the box still gets its text from the game" do
    scene = PokemonMenu_Scene.new
    scene.pbShowInfo("Pasos: 120/600\nBalls: 30")
    assert_equal "Pasos: 120/600\nBalls: 30", scene.info
  end
end
