# The gen-6 move-detail redraw's move id, the argument after moveToLearn in its three shapes: (pokemon, moveToLearn,
# moveid), Awakening's (moveToLearn, moveid), the oldest (pokemon, moveToLearn, moveid, shouldDrawSecond).
Suite.define("summary gen-6: the move id of a move-detail redraw, in each shape") do
  sg = PokeAccess::SummaryGen6
  scene = Object.new
  scene.instance_variable_set(:@pokemon, :on_scene)
  eq "vanilla", sg.selected_move(scene, [:passed, 0, 33]), [:passed, 33]
  eq "awakening, the Pokemon from the scene", sg.selected_move(scene, [0, 33]), [:on_scene, 33]
  eq "a flag after the id is not the id", sg.selected_move(scene, [:passed, 0, 33, true]), [:passed, 33]
end
