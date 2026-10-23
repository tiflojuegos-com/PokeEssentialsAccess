# Battle.announce_target in doubles: the highlighted battler by name and side as the choosing battler sees it, said
# once until the cursor moves or leaves; a spread move names every slot it lights.
class AnnounceTargetTest < PokeAccessTest
  # A battler at a global index (0 and 2 the player's side, 1 and 3 the foe's); pokemon nil is an empty slot.
  Battler = Struct.new(:name, :index, :pokemon)

  # The gen-6 fight window, on which pbChooseTarget leaves the choosing battler.
  FightWindow = Struct.new(:battler)

  # A gen-6 battle over its battlers, double by its flag.
  FlagBattle = Struct.new(:battlers, :doublebattle)

  # A v18+ battle, which tells a double by the size of the player's side; sizes by side.
  SizedBattle = Struct.new(:battlers, :sizes) do
    def pbSideSize(side); sizes[side]; end
  end

  # The names of the four battlers full_field places, by slot.
  NAMES = ["Bulba", "Rattata", "Char", "Pidgey"]

  test "names each slot with its side as the fight window's battler sees it" do
    sides = { [0, 0] => :bt_target_self, [0, 1] => :bt_target_foe, [0, 2] => :bt_target_ally, [0, 3] => :bt_target_foe,
              [2, 0] => :bt_target_ally, [2, 1] => :bt_target_foe, [2, 2] => :bt_target_self, [2, 3] => :bt_target_foe }
    sides.each do |(chooser, index), side|
      field = full_field
      scene = scene_of(double(field), "fightwindow" => FightWindow.new(field[chooser]))
      assert_equal [["#{NAMES[index]}, #{t(side)}", true]], target_line(scene, index),
                   "slot #{index} chosen by slot #{chooser}"
    end
  end

  test "reads the chooser from a fight window kept under its other spelling" do
    field = full_field
    scene = scene_of(double(field), "fightWindow" => FightWindow.new(field[2]))
    assert_equal [["Char, #{t(:bt_target_self)}", true]], target_line(scene, 2)
  end

  test "without a fight window the chooser is slot 0" do
    scene = scene_of(double(full_field))
    { 0 => :bt_target_self, 2 => :bt_target_ally }.each do |index, side|
      assert_equal [["#{NAMES[index]}, #{t(side)}", true]], target_line(scene, index), "slot #{index}"
    end
  end

  test "the battler pbChooseTarget was called for wins over the fight window's" do
    field = full_field
    scene = scene_of(double(field), "fightwindow" => FightWindow.new(field[0]))
    scene.instance_variable_set(:@access_target_chooser, 2)
    assert_equal [["Char, #{t(:bt_target_self)}", true]], target_line(scene, 2), "its own slot"
    assert_equal [["Bulba, #{t(:bt_target_ally)}", true]], target_line(scene, 0), "its partner's"
  end

  test "a kept chooser that is not a slot number is passed over for the fight window's" do
    field = full_field
    scene = scene_of(double(field), "fightwindow" => FightWindow.new(field[2]))
    scene.instance_variable_set(:@access_target_chooser, field[0])
    assert_equal [["Char, #{t(:bt_target_self)}", true]], target_line(scene, 2)
  end

  test "an empty highlighted slot is said as empty, on its side" do
    field = full_field
    field[2] = Battler.new("", 2, nil)
    scene = scene_of(double(field), "fightwindow" => FightWindow.new(field[0]))
    assert_equal [["#{t(:bt_empty_slot)}, #{t(:bt_target_ally)}", true]], target_line(scene, 2)
  end

  test "reads only in a double, by the gen-6 flag or by the player's side size" do
    foe = [["Rattata, #{t(:bt_target_foe)}", true]]
    { "the flag on" => [FlagBattle.new(full_field, true), foe],
      "the flag off" => [FlagBattle.new(full_field, false), []],
      "two on the player's side" => [SizedBattle.new(full_field, [2, 1]), foe],
      "one on the player's side" => [SizedBattle.new(full_field, [1, 2]), []],
      "a side size that is no number" => [SizedBattle.new(full_field, [:two, :two]), []] }.each do |what, (battle, log)|
      assert_equal log, target_line(scene_of(battle), 1), "with #{what}"
    end
  end

  test "says nothing for a scene without a battle" do
    [1, [nil, :lit, nil, :lit]].each do |index|
      assert_equal [], target_line(scene_of(nil), index), "for #{index.inspect}"
    end
  end

  test "says nothing as the cursor leaves a slot" do
    scene = scene_of(double(full_field))
    [-1, nil].each do |index|
      target_line(scene, 1)
      assert_equal [], moved_line(scene, index), "leaving with #{index.inspect}"
    end
  end

  test "the same slot again says nothing" do
    scene = scene_of(double(full_field))
    target_line(scene, 1)
    assert_equal [], moved_line(scene, 1)
  end

  test "the cursor moving to another slot says the new one" do
    scene = scene_of(double(full_field))
    target_line(scene, 1)
    assert_equal [["Pidgey, #{t(:bt_target_foe)}", true]], moved_line(scene, 3)
  end

  test "coming back to a slot after the cursor left says it again" do
    scene = scene_of(double(full_field))
    target_line(scene, 1)
    assert_equal [["Rattata, #{t(:bt_target_foe)}", true]], target_line(scene, 1)
  end

  test "a spread move names every slot it lights, in slot order, each with its side" do
    field = full_field
    field[2] = Battler.new("", 2, nil)
    scene = scene_of(double(field), "fightwindow" => FightWindow.new(field[0]))
    line = ["Rattata, #{t(:bt_target_foe)}", "#{t(:bt_empty_slot)}, #{t(:bt_target_ally)}",
            "Pidgey, #{t(:bt_target_foe)}"].join(". ")
    assert_equal [[line, true]], target_line(scene, [nil, :lit, :lit, :lit])
  end

  test "a spread move lighting the same slots again says nothing" do
    scene = scene_of(double(full_field))
    target_line(scene, [nil, :lit, nil, :lit])
    assert_equal [], moved_line(scene, [nil, :lit, nil, :lit])
  end

  test "a spread move lighting nothing says nothing" do
    assert_equal [], target_line(scene_of(double(full_field)), [nil, nil, nil, nil])
  end

  private

  # Four battlers: the player's in slots 0 and 2, the foe's in 1 and 3.
  def full_field
    NAMES.each_with_index.map { |name, i| Battler.new(name, i, :mon) }
  end

  # A gen-6 double battle over these battlers.
  def double(field)
    FlagBattle.new(field, true)
  end

  # A gen-6 scene over battle, with the given sprites.
  def scene_of(battle, sprites = {})
    scene = Object.new
    scene.instance_variable_set(:@battle, battle)
    scene.instance_variable_set(:@sprites, sprites)
    scene
  end

  # What the target cursor says on index, freshly entered, as [text, interrupt] pairs.
  def target_line(scene, index)
    PokeAccess::Battle.announce_target(scene, -1)
    moved_line(scene, index)
  end

  # What the target cursor says going on to index from where it stands, as [text, interrupt] pairs.
  def moved_line(scene, index)
    SpeakCapture.clear
    PokeAccess::Battle.announce_target(scene, index)
    SpeakCapture.log.dup
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
