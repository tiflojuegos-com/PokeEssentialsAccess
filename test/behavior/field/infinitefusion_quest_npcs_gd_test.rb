# Infinite Fusion's quest givers (games/infinitefusion_common/quest_npcs.rb): an event named questNPC("<quest id>") in
# the editor is named as an unnamed one with its sprite, in Kanto and in Hoenn; after another name the tag is dropped
# and that name kept; and a name a puzzle declares for one, as Saffron Nightclub's dancer, still wins. Hoenn's rival, the
# events named HOENN_RIVAL with a tag or without (games/infinitefusion_hoenn/rival.rb), is named as the player called it.
# Gamedata pass.
quest_npcs = File.join(Harness::ROOT, "games", "infinitefusion_common", "quest_npcs.rb")
eval(Harness.source(quest_npcs), TOPLEVEL_BINDING, quest_npcs)
ifh_rival = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "rival.rb")
eval(Harness.source(ifh_rival), TOPLEVEL_BINDING, ifh_rival)

class InfinitefusionQuestNpcsGdTest < PokeAccessTest
  Locator = PokeAccess::Locator

  def setup
    super
    @defs = PokeAccess::World::Mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
  end

  def teardown
    World.clear_events
    PokeAccess::World::Mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "a quest giver of either game is named by its sprite, as one left as EV###" do
    { 39 => ['questNPC("route109_tanning")', "NPC_Hoenn_Triathlete_F"], 114 => ['questNPC("saffron_field_1")', "trchar001"] }.each do |map, (name, sprite)|
      $game_map.map_id = map
      quest = put(5, name, sprite)
      named = Locator.target_name(quest)
      plain = Locator.target_name(put(6, "EV006", sprite))
      assert_equal plain, named
      refute_includes named, "questNPC"
    end
    assert Locator.placeholder_name?('questNPC("rt109_beachballQuest")')
    assert Locator.placeholder_name?('questNPC( "goldenrod_2")'), "a tag spaced as the mapper left it"
    refute Locator.placeholder_name?("BeachBallKid_Left")
  end

  test "a quest tag after another name is dropped, and the event is named as one with that name alone" do
    $game_map.map_id = 12
    tagged = put(16, 'HOENN_RIVAL questNPC("route104_rivalWeather")', "NPC_template")
    plain = put(17, "HOENN_RIVAL", "NPC_template")
    assert_equal "HOENN_RIVAL", Locator.own_name(tagged)
    assert_equal Locator.target_name(plain), Locator.target_name(tagged)
    refute Locator.placeholder_name?('HOENN_RIVAL questNPC("route104_rivalWeather")')
  end

  test "Hoenn's rival is named as the player called it, before that by the game's default, and no other event so" do
    $game_map.map_id = 12
    rival = PokeAccess::IF2Rival
    tagged = put(16, 'HOENN_RIVAL questNPC("route104_rivalWeather")', "NPC_template")
    plain = put(17, "HOENN_RIVAL", "NPC_template")
    others = [put(18, "HOENN_RIVALS", "NPC_template"), put(19, "RIVAL", "NPC_template"), put(20, "the HOENN_RIVAL", "NPC")]
    $game_variables[12] = " Aqua "
    assert_equal ["Aqua", "Aqua"], [tagged, plain].map { |ev| Locator.target_name(ev) }
    others.each { |ev| assert_nil rival.name_of(ev), ev.name }
    $game_variables[12] = 0
    assert_nil rival.name_of(plain), "no name yet and no default from the game"
    rival.define_singleton_method(:get_default_rival_name) { "May" }
    assert_equal "May", Locator.target_name(tagged)
    $game_variables[12] = ""
    assert_equal "May", rival.name_of(plain)
  ensure
    rival.singleton_class.send(:remove_method, :get_default_rival_name) if rival.singleton_methods.include?(:get_default_rival_name)
    $game_variables[12] = 0
  end

  test "the Saffron Nightclub's dancer keeps the name its puzzle declares" do
    Harness.load_puzzles("infinitefusion")
    $game_map.map_id = 114
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    dancer = put(7, 'questNPC("saffron_field_1")', "trchar001")
    assert_equal PokeAccess::I18n.t(:ifq_dance_copycat), Locator.target_name(dancer)
  end

  private

  def put(id, name, sprite)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, ["Hi!"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => 3 + id, :y => 4, :name => name, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end
end
