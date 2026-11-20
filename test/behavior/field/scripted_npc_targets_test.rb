# Someone whose live page talks by script (pbMessage, a battle, a speech call) counts as talking, as one with Show Text
# does: a person on a touch page who takes the player elsewhere is a person, not an exit, and a page that fights keeps
# its name alone, its transfer being where the battle leaves the player rather than a ride.
class ScriptedNpcTargetsTest < PokeAccessTest
  Loc = PokeAccess::Locator

  test "a trainer who notices, talks and fights by script, moved only on defeat, is a person" do
    commands = [TestCmd.new(355, ["Kernel.pbNoticePlayer(get_character(0))"]),
                TestCmd.new(355, ['fbText("Let us battle!")']),
                TestCmd.new(111, [12, 'pbTrainerBattle(:CAMPER, "Cam", "Well done", false, 0, true)']),
                TestCmd.new(123, ["A", 0], 1), TestCmd.new(411),
                TestCmd.new(201, [0, 28, 21, 7, 0, 0], 1), TestCmd.new(412)]
    assert_person event(commands, "allenatore-campeggiatore")
  end

  test "someone who takes the player elsewhere after a scripted line is a person" do
    ['Kernel.pbMessage("All aboard!")', 'fbText("Follow me.")'].each do |line|
      assert_person event([TestCmd.new(355, [line]), transfer])
    end
  end

  test "a line split over script continuations, or a battle in a branch's condition, is talk" do
    [[TestCmd.new(355, ["fbText("]), TestCmd.new(655, ['"Follow me.")'])],
     [TestCmd.new(111, [12, "pbTrainerBattle(:CAMPER)"]), TestCmd.new(412)]].each do |commands|
      assert_person event(commands + [transfer])
    end
  end

  test "someone who talks with Show Text and takes the player elsewhere is still a person" do
    assert_person event([TestCmd.new(101, ["Follow me."]), transfer])
  end

  test "a door, or a tile with no sprite, that says a line before it moves the player stays an exit" do
    ["", "door_001"].each do |sprite|
      ev = event([TestCmd.new(355, ['pbMessage("Entering.")']), transfer], sprite, 1)
      seen do
        assert_equal [true, true, false], [Loc.transfer_event?(ev), Loc.in_category?(ev, :exits),
                                           Loc.in_category?(ev, :people)], sprite
      end
    end
  end

  test "a silent portal, or one not drawn, stays an exit" do
    portal = event([transfer], "Lightbeam")
    seen { assert_equal [false, true], [Loc.live_talks?(portal), Loc.transfer_event?(portal)] }
    hidden = event([TestCmd.new(355, ['fbText("Entering.")']), transfer])
    seen(false) { assert Loc.transfer_event?(hidden) }
  end

  test "a line on a page that is not the live one does not make a portal a person" do
    other = TestPage.new(:trigger => 2, :sprite => "NPC_Guide",
                         :list => [TestCmd.new(355, ['fbText("Not on the active page.")'])])
    ev = event([transfer], "Lightbeam", 2, other)
    seen { assert_equal [false, true], [Loc.live_talks?(ev), Loc.transfer_event?(ev)] }
  end

  test "an item ball is still an object, and someone who talks before handing one over a person" do
    pickup = [TestCmd.new(355, ["pbItemBall(:POTION)"])]
    ball = event(pickup, "item_ball", 0)
    giver = event([TestCmd.new(355, ['fbText("Take this gift.")'])] + pickup, "NPC_Guide", 0)
    assert_equal [true, :objects], [Loc.item_ball?(ball), Loc.event_category(ball)]
    assert_equal [false, :people], [Loc.item_ball?(giver), Loc.event_category(giver)]
  end

  test "a pickup whose message comes after it, or that fights first, is still an object named by its item" do
    flowers = event(pickup_then([TestCmd.new(355, ['pbMessageBlack("Nectar!")'])]), "OBJ_Flores", 0, nil, "EV012")
    shadow = event([TestCmd.new(355, ["WildBattle.start(:WEEDLE, 2)"])] + pickup_then([]), "shadow", 0, nil, "EV013")
    [flowers, shadow].each do |ev|
      assert_equal [true, :objects, PokeAccess::I18n.t(:loc_object_named, :name => Loc.item_name(ev))],
                   [Loc.item_ball?(ev), Loc.event_category(ev), Loc.event_name(ev)], ev.character_name
    end
  end

  test "a page that fights keeps its name alone, its transfer being where the battle leaves the player" do
    [[TestCmd.new(111, [12, "pbTrainerBattle(:CAMPER)"])],
     [TestCmd.new(355, ["TrainerBattle.start(:CAMPER)"])],
     [TestCmd.new(355, ["WildBattle.start("]), TestCmd.new(655, [":WEEDLE, 2)"])]].each do |battle|
      ev = event([TestCmd.new(355, ['fbText("Let us battle!")'])] + battle + [transfer])
      named_harbor { seen { assert_equal Loc.event_name(ev), Loc.target_name(ev), battle.first.parameters.inspect } }
    end
  end

  test "someone who takes the player elsewhere, without fighting on the live page, says where" do
    other = TestPage.new(:trigger => 2, :sprite => "NPC_Guide",
                         :list => [TestCmd.new(111, [12, "pbTrainerBattle(:CAMPER)"])])
    [event([TestCmd.new(355, ['pbMessage("All aboard!")']), transfer]),
     event([TestCmd.new(355, ['pbMessage("All aboard!")']), transfer], "NPC_Guide", 2, other)].each do |ev|
      named_harbor do
        seen do
          assert_equal "#{Loc.event_name(ev)}, #{PokeAccess::I18n.t(:loc_takes_to, :map => 'Harbor')}",
                       Loc.target_name(ev)
        end
      end
    end
  end

  private

  # A new event whose live page, with that sprite and trigger, holds the commands; another page after it if given.
  def event(commands, sprite = "NPC_Guide", trigger = 2, other = nil, name = "Guide")
    @next_id = (@next_id || 80) + 1
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => commands)
    TestGameEvent.new(:id => @next_id, :name => name, :pages => [page, other].compact, :active_page => page)
  end

  # A Potion ball followed by the given commands.
  def pickup_then(after)
    [TestCmd.new(355, ["pbItemBall(:POTION)"])] + after
  end

  # A transfer to map 28.
  def transfer
    TestCmd.new(201, [0, 28, 21, 7, 0, 0])
  end

  # Runs the block with every sprite drawn (or none), put back after.
  def seen(visible = true)
    original = Loc.method(:sprite_seen?)
    Loc.define_singleton_method(:sprite_seen?) { |_ev| visible }
    yield
  ensure
    Loc.define_singleton_method(:sprite_seen?, original)
  end

  # Runs the block with map 28 named Harbor, put back after.
  def named_harbor
    previous = PokeAccess::MapNames.get(28)
    PokeAccess::MapNames.set(28, "Harbor")
    yield
  ensure
    previous ? PokeAccess::MapNames.set(28, previous) : PokeAccess::MapNames.delete(28)
  end

  # Asserts the event talks, is no exit and stands with the people.
  def assert_person(ev)
    seen do
      assert_equal [true, false, true, false], [Loc.live_talks?(ev), Loc.transfer_event?(ev),
                                                Loc.in_category?(ev, :people), Loc.in_category?(ev, :exits)]
    end
  end
end
