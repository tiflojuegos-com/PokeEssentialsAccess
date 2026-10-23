# The PC's multi-select (Storage System Utilities): how many Pokemon the green rectangle takes in and how many the
# lifted block carries, said when the count changes, queued on the next frame behind the slot line.
class StorageUtilitiesGdTest < PokeAccessTest
  SU = PokeAccess::StorageUtilities
  # The plugin's grabber as the reader asks it: the rectangle's slot offsets from its pivot slot, and the block lifted.
  Grabber = Struct.new(:mons, :mock_pivot, :carrying, :carried_mons) do
    def holding_anything?; !mons.empty?; end
  end
  # A three-slot rectangle: the pivot, the slot right of it and the one below it.
  CORNER = [[0, 0], [1, 0], [0, 1]].freeze

  test "says how many Pokemon the rectangle takes in, its empty slots left out" do
    assert_equal [[PokeAccess::I18n.t(:su_selected, :n => 2), false]], poll_and_flush(rectangle(CORNER, [0, 1]))
  end

  test "counts the rectangle's slots from its pivot, six slots to a box row" do
    assert_equal [[PokeAccess::I18n.t(:su_selected, :n => 2), false]], poll_and_flush(rectangle(CORNER, [8, 13], 7)),
                 "from slot 7 the rectangle covers slots 7, 8 and 13, the last two filled"
  end

  test "says the count again only when it changes" do
    scene = rectangle([[0, 0], [1, 0]], [0, 1, 6])
    said = [poll_and_flush(scene), poll_and_flush(scene)]
    scene.instance_variable_get(:@grabber).mons = CORNER
    said.push(poll_and_flush(scene))
    two = PokeAccess::I18n.t(:su_selected, :n => 2)
    three = PokeAccess::I18n.t(:su_selected, :n => 3)
    assert_equal [[[two, false]], [], [[three, false]]], said,
                 "two, the same two unsaid, then three as the rectangle grows over slot 6"
  end

  test "says a new rectangle after the last one ended, even with the same count" do
    scene = rectangle(CORNER, [0, 1])
    poll_and_flush(scene)
    grabber = scene.instance_variable_get(:@grabber)
    grabber.mons = []
    assert_equal [], poll_and_flush(scene), "the rectangle let go says nothing"
    grabber.mons = CORNER
    assert_equal [[PokeAccess::I18n.t(:su_selected, :n => 2), false]], poll_and_flush(scene)
  end

  test "counts the lifted block's Pokemon, not its empty slots" do
    scene = rectangle(CORNER, [0, 1])
    grabber = scene.instance_variable_get(:@grabber)
    grabber.carrying = true
    grabber.carried_mons = [[Poke.build, 0, 0], [Poke.build, 1, 0], [nil, 0, 1]]
    assert_equal [[PokeAccess::I18n.t(:su_carrying, :n => 2), false]], poll_and_flush(scene)
  end

  test "says nothing of a rectangle outside multi-select" do
    assert_equal [], poll_and_flush(rectangle(CORNER, [0, 1], 0, false))
  end

  test "says nothing while the grabber holds no rectangle" do
    assert_equal [], poll_and_flush(rectangle([], [0, 1]))
  end

  test "drops a count still unsaid when multi-select ends before the next frame" do
    scene = rectangle(CORNER, [0, 1])
    SU.poll(scene)
    scene.instance_variable_set(:@multi, false)
    assert_equal [], poll_and_flush(scene)
  end

  test "says nothing when the storage cannot be read" do
    scene = rectangle(CORNER, [0, 1])
    def (scene.instance_variable_get(:@storage)).currentBox; raise "the box is gone"; end
    assert_equal [], poll_and_flush(scene)
  end

  test "says the count on the frame after the arrow's move, behind the slot line that move repaints" do
    scene = PokemonStorageScene.new(storage([0, 1]))
    scene.instance_variable_set(:@grabber, Grabber.new([[0, 0], [1, 0]], 0, false, []))
    scene.instance_variable_set(:@multi, true)
    assert_equal :arrow, scene.pbSetArrow(nil, 0), "the arrow's move keeps its own return"
    PokeAccess.speak("Bulba, fila 1, columna 1", true)
    PokeAccess::Frame.run_pollers
    assert_equal [["Bulba, fila 1, columna 1", true], [PokeAccess::I18n.t(:su_selected, :n => 2), false]], SpeakCapture.log
  end

  private

  # A one-box PC whose given slots hold a Pokemon, as the scene's @storage answers storage[box, slot].
  def storage(filled)
    TestStorage.new([TestBox.new("Alpha", Array.new(30) { |i| filled.include?(i) ? Poke.build(:name => "Slot#{i}") : nil })])
  end

  # A PC scene drawing a rectangle of offsets from pivot over a box with the filled slots, in multi-select or not.
  def rectangle(offsets, filled, pivot = 0, multi = true)
    World.stub_scene(:@grabber => Grabber.new(offsets, pivot, false, []), :@multi => multi, :@storage => storage(filled))
  end

  # What one poll of the scene says once the next frame flushes it, as [text, interrupt] pairs.
  def poll_and_flush(scene)
    SpeakCapture.clear
    SU.poll(scene)
    SU.flush
    SpeakCapture.log.dup
  end
end
