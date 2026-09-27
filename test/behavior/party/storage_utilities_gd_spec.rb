# The PC's multi-select (Storage System Utilities) draws a green rectangle over the slots and carries the block it
# lifts, neither of which the slot line under the arrow says.
Suite.define("storage utilities: the rectangle's count and the carried block are said as they change") do
  t = PokeAccess::I18n
  grabber = Struct.new(:mons, :mock_pivot, :carrying, :carried_mons) do
    def holding_anything?; !mons.empty?; end
  end
  g = grabber.new([[0, 0], [1, 0], [0, 1]], 0, false, [])
  store = Object.new
  def store.currentBox; 0; end
  def store.[](box, i); [0, 1].include?(i) ? :mon : nil; end
  scene = World.stub_scene(:@grabber => g, :@multi => true, :@storage => store)
  su = PokeAccess::StorageUtilities
  SpeakCapture.clear
  su.poll(scene)
  su.flush
  eq "the rectangle takes in two Pokemon of its three slots", SpeakCapture.lines, [t.t(:su_selected, :n => 2)]
  su.poll(scene)
  su.flush
  eq "and is not said again unchanged", SpeakCapture.lines.length, 1
  g.carrying = true
  g.carried_mons = [[:mon, 0, 0], [:mon, 1, 0], [nil, 0, 1]]
  SpeakCapture.clear
  su.poll(scene)
  su.flush
  eq "lifted, the block carried counts its Pokemon, not its empty slots", SpeakCapture.lines, [t.t(:su_carrying, :n => 2)]
  g.carrying = false
  g.carried_mons = []
  g.mons = []
  su.poll(scene)
  su.flush
  g.mons = [[0, 0], [1, 0], [0, 1]]
  SpeakCapture.clear
  su.poll(scene)
  su.flush
  eq "a new rectangle after the last one ended is said even with the same count", SpeakCapture.lines,
     [t.t(:su_selected, :n => 2)]
end

# The same, off the arrow's own move, which is where the plugin's reader listens.
Suite.define("storage utilities: the rectangle is followed through the arrow's move") do
  t = PokeAccess::I18n
  grabber = Struct.new(:mons, :mock_pivot, :carrying, :carried_mons) do
    def holding_anything?; !mons.empty?; end
  end
  store = Object.new
  def store.currentBox; 0; end
  def store.[](box, i); [0, 1].include?(i) ? :mon : nil; end
  scene = PokemonStorageScene.new(store)
  scene.instance_variable_set(:@grabber, grabber.new([[0, 0], [1, 0]], 0, false, []))
  scene.instance_variable_set(:@multi, true)
  SpeakCapture.clear
  eq "the arrow keeps its own return", scene.pbSetArrow(nil, 0), :arrow
  PokeAccess.speak("Bulba, fila 1, columna 1", true)
  PokeAccess::Keys.run_frame_pollers
  eq "the rectangle's count, said after the slot line the same move repaints, which would cut it",
     SpeakCapture.lines, ["Bulba, fila 1, columna 1", t.t(:su_selected, :n => 2)]
end
