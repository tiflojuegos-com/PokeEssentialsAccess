# Menus.poll_sprite_menu, the reader of sprite-driven menus: it polls @index over the entry list and speaks the
# focused entry, as the caller's block names it, once per change; the dedup lives on the scene under the caller's slot.
class PollSpriteMenuTest < PokeAccessTest
  ENTRIES = [[1, "Map"], [2, "Radio"]].freeze

  test "speaks the focused entry by the name its block gives it" do
    poll(menu(0))
    assert_equal [["Map", true]], SpeakCapture.log
  end

  test "says nothing more while the cursor stays on the entry" do
    scene = menu(0)
    3.times { poll(scene) }
    assert_equal ["Map"], SpeakCapture.lines
  end

  test "speaks the entry the cursor moves to, once" do
    scene = menu(0)
    poll(scene)
    scene.instance_variable_set(:@index, 1)
    2.times { poll(scene) }
    assert_equal ["Map", "Radio"], SpeakCapture.lines
  end

  test "keeps its dedup on the scene, so another scene on the same entry speaks it again" do
    poll(menu(1))
    poll(menu(1))
    assert_equal ["Radio", "Radio"], SpeakCapture.lines
  end

  test "asks its block for no entry and says nothing when the cursor is off the list or the list is missing" do
    cases = { "no cursor" => menu(nil), "a cursor before the first entry" => menu(-1),
              "a cursor past the last entry" => menu(2), "a cursor that is not a number" => menu("0"),
              "no list" => World.stub_scene(:@index => 0),
              "a list that is not an Array" => World.stub_scene(:@commands => "Map", :@index => 0) }
    heard = cases.map do |what, scene|
      SpeakCapture.clear
      asked = []
      poll(scene) { |entry| asked.push(entry); entry[1] }
      [what, asked, SpeakCapture.lines]
    end
    assert_equal cases.keys.map { |what| [what, [], []] }, heard
  end

  test "says nothing for an entry its block names as nothing" do
    poll(menu(0)) { |_entry| nil }
    assert_nothing_spoken
  end

  test "survives a block that raises, saying nothing" do
    poll(menu(0)) { |_entry| raise "no name" }
    assert_nothing_spoken
  end

  test "takes a dedup slot spelled with a leading @ as the bare slot" do
    scene = menu(0)
    poll(scene, :@access_ready_last)
    poll(scene, :access_ready_last)
    scene.instance_variable_set(:@index, 1)
    poll(scene, :access_ready_last)
    poll(scene, :@access_ready_last)
    assert_equal ["Map", "Radio"], SpeakCapture.lines
  end

  private

  # A sprite menu with the two entries and its cursor on index.
  def menu(index)
    World.stub_scene(:@commands => ENTRIES, :@index => index)
  end

  # One poll of scene's entries in @commands under slot, the entry named by the block (its caption by default).
  def poll(scene, slot = :pg_last, &name)
    name ||= lambda { |entry| entry[1] }
    PokeAccess::Menus.poll_sprite_menu(scene, :@commands, slot, &name)
  end
end
