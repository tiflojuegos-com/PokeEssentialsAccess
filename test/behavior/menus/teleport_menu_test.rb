# PokéLiberty's teleport menu (plugins/teleport_menu.rb, Teleport_Scene): the destination under @select as the screen
# writes it, its name and description lines or unknown while locked, with its place in the list.
class TeleportMenuTest < PokeAccessTest
  test "an unlocked destination is its name and description lines, then its place" do
    text = PokeAccess::TeleportMenu.text(menu([0, 1]), 1)
    expected = ["Pueblo Brisa", "Un pueblo junto al mar.", "Tiene puerto.", PokeAccess::Verbosity.position(2, 3)]
    assert_equal PokeAccess.sentences(expected.compact), text, "the empty description lines are left out"
  end

  test "a locked destination is unknown, as its question marks say" do
    text = PokeAccess::TeleportMenu.text(menu([0]), 2)
    expected = [PokeAccess::DexEntry.unknown_marks("???"), PokeAccess::Verbosity.position(3, 3)]
    assert_equal PokeAccess.sentences(expected.compact), text
  end

  test "the cursor's destination is polled from the menu's loop and said on each move" do
    scene = menu([0, 1, 2])
    reader = PokeAccess::TeleportMenu::READER
    reader.watch(scene)
    reader.poll
    scene.instance_variable_set(:@select, 1)
    reader.poll
    reader.unwatch
    assert_equal [false, true], SpeakCapture.log.map { |l| l[1] }, "the opening read queued, the move interrupting"
  end

  private

  # A teleport menu over three destinations, the given ones unlocked, cursor on the first.
  def menu(unlocked)
    s = World.stub_scene(:@select => 0, :@mapnames => ["Ciudad Roca", "Pueblo Brisa", "Isla Lejana"],
                         :@map_descs => [["Una ciudad.", "", "", "", ""],
                                         ["Un pueblo junto al mar.", "Tiene puerto.", "", " ", ""],
                                         ["", "", "", "", ""]])
    s.define_singleton_method(:pbTpUnlocked?) { |i| unlocked.include?(i) }
    s
  end
end
