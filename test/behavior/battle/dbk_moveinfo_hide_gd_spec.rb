# The move panel closes on Confirm, Cancel and Shift without a redraw and the next turn's fight menu opens on
# the same move, so hiding it lets go of the slot's last line and marks the next line an opening, said whole.
Suite.define("dbk move panel: closing it lets the next opening speak") do
  bs = PokeAccess::BattleScene
  scene = Battle::Scene.new
  PokeAccess::Cursor.changed?(scene, :dbk_moveinfo, [0, 1, "Rayo"])
  bs.instance_variable_set(:@panel_shut, false)
  scene.pbHideInfoUI
  eq "the slot is let go when the panel is hidden", PokeAccess::Cursor.current(scene, :dbk_moveinfo), nil
  eq "and its next line is an opening", bs.instance_variable_get(:@panel_shut), true
end
