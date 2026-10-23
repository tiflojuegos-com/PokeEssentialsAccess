# The Enhanced Battle UI's move panel closes on Confirm, Cancel and Shift (pbHideInfoUI) without a redraw, and the next
# turn's fight menu opens on the same move: hiding it lets go of the panel's last line and makes the next an opening.
class DbkMoveinfoHideGdTest < PokeAccessTest
  BattleScene = PokeAccess::BattleScene

  test "hiding the panel lets the same move's line be read again" do
    scene = Battle::Scene.new
    key = [0, 1, ["Rayo", "Potencia 90"]]
    assert PokeAccess::Cursor.changed?(scene, :dbk_moveinfo, key), "first read"
    refute PokeAccess::Cursor.changed?(scene, :dbk_moveinfo, key), "the same line again, while the panel stays"
    with_panel_state { scene.pbHideInfoUI }
    assert PokeAccess::Cursor.changed?(scene, :dbk_moveinfo, key), "after the panel was hidden"
  end

  test "hiding the panel has its next line said whole" do
    battler = Struct.new(:index).new(0)
    parts = ["Rayo", "Potencia 90", "Precisión 100"]
    with_panel_state do
      BattleScene.panel_shut
      assert_equal parts, BattleScene.unheard(battler, 1, parts), "the panel's first line"
      assert_equal [], BattleScene.unheard(battler, 1, parts), "a repaint with nothing new"
      Battle::Scene.new.pbHideInfoUI
      assert_equal parts, BattleScene.unheard(battler, 1, parts), "the line after the panel was hidden"
    end
  end

  test "the scene's own hiding still runs" do
    scene = Battle::Scene.new
    scene.instance_variable_set(:@enhancedUIToggle, :move)
    with_panel_state { scene.pbHideInfoUI }
    assert_nil scene.instance_variable_get(:@enhancedUIToggle)
  end

  private

  # Runs the block, then puts back the move panel's reading state (opening flag, lines heard, the fight line).
  def with_panel_state
    saved = [:@panel_shut, :@heard, :@fight_line].map { |v| [v, BattleScene.instance_variable_get(v)] }
    yield
  ensure
    saved.each { |v, value| BattleScene.instance_variable_set(v, value) }
  end
end
