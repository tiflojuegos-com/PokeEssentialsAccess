# Relict's Destiny Tower floors (games/relict/tower.rb), gamedata pass: the events Create events.rb copies onto a floor
# (<template>_copy<id>_<suffix>) are named by what their sprite draws and filed as objects, a dialogue Pokemon by its
# species, the stairs are held back until the minimap shows them, and the Event Indicators bubble is said as a mark.
class RelictTowerGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "relict", "tower.rb")

  # An indicator sprite as Event Indicators keeps it, per event id, on the map's spriteset.
  Indicator = Struct.new(:visible, :gone) do
    def disposed?; gone; end
  end
  # Indicator sprites that cannot tell: one with no disposed? of its own, one with no visibility of its own.
  Undisposable = Struct.new(:visible)
  Unseeable = Struct.new(:gone) do
    def disposed?; gone; end
  end

  # A data provider that names no species and no item.
  class Nameless
    def species_name(_id); " "; end
    def item_id(sym); [sym, ""]; end
  end

  class << self
    # The locator rules the profile's file registered, by kind, kept aside between tests: the file is evaluated once
    # per process.
    attr_accessor :tower_rules
  end

  test "without the tower's rules, the core reads a floor copy by its raw name, among the people" do
    potion = floor_event(12, "item_copy12_POTION", "item_potion")
    assert_equal ["item_copy12_POTION", :people], [loc.target_name(potion), loc.event_category(potion)]
  end

  test "names a floor item by the item it gives while item names are on" do
    potion = floor_event(12, "item_copy12_POTION", "item_potion")
    with_tower do
      assert_equal t(:loc_object_named, :name => PokeAccess::Data.item_name(:POTION)), loc.target_name(potion)
    end
  end

  test "with item names off, names a floor item by the class its sprite draws" do
    sprites = { "item_potion" => :rel_item_potion, "item_ball" => :rel_item_ball, "item_tm" => :rel_item_tm,
                "item_berry" => :rel_item_berry, "item_usual" => :loc_object }
    events = sprites.keys.each_with_index.map { |sprite, i| floor_event(20 + i, "item_copy#{20 + i}_POTION", sprite) }
    with_tower do
      PokeAccess::Config.name_items = false
      assert_equal sprites.values.map { |key| t(key) }, events.map { |e| loc.target_name(e) }
    end
  end

  test "a floor item the game has no name for is named by the class its sprite draws" do
    potion = floor_event(12, "item_copy12_POTION", "item_potion")
    with_tower do
      Harness.with_provider(Nameless.new, 30) { assert_equal t(:rel_item_potion), loc.target_name(potion) }
    end
  end

  test "names the gold by its sprite, never by the amount in its name" do
    gold = floor_event(13, "gold_copy13_GOLD_130", "item_gold", "getGoldDungeonEvent")
    with_tower do
      said = [true, false].map { |on| PokeAccess::Config.name_items = on; loc.target_name(gold) }
      assert_equal [t(:rel_item_gold)] * 2, said, "with item names on and off"
    end
  end

  test "a starter's ball, not a floor copy, is named by its sprite" do
    starter = floor_event(4, "pokeball0", "item_ball", "askPokeStarter(0)")
    with_tower { assert_equal t(:rel_item_ball), loc.target_name(starter) }
  end

  test "a floor copy picked up keeps its class, never its internal name" do
    gold = floor_event(13, "gold_copy13_GOLD_130", "", "getGoldDungeonEvent")
    item = floor_event(12, "item_copy12_POTION", "")
    with_tower do
      PokeAccess::Config.name_items = false
      assert_equal [t(:rel_item_gold), t(:loc_object)], [loc.target_name(gold), loc.target_name(item)]
    end
  end

  test "an event neither copied onto the floor nor drawn as an item keeps the core's name" do
    nurse = World.event(:kind => :npc, :id => 30, :name => "Enfermera", :sprite => "nurse")
    with_tower { assert_equal "Enfermera", loc.target_name(nurse) }
  end

  test "names a dialogue Pokemon by the species its name ends in, form and all" do
    poke = floor_event(15, "dialogue_poke_copy15_SLOWKING_1", "Followers/SLOWKING_1", "dialoguePokeEvent")
    with_tower { assert_equal PokeAccess::Data.species_name(:SLOWKING_1), loc.target_name(poke) }
  end

  test "a dialogue Pokemon whose species has no name is named by the first part of its symbol" do
    poke = floor_event(15, "dialogue_poke_copy15_SLOWKING_1", "Followers/SLOWKING_1", "dialoguePokeEvent")
    with_tower do
      Harness.with_provider(Nameless.new, 30) { assert_equal "Slowking", loc.target_name(poke) }
    end
  end

  test "files the floor's item sprites with the objects, whatever they run" do
    events = [floor_event(12, "item_copy12_POTION", "item_potion"),
              floor_event(13, "gold_copy13_GOLD_130", "item_gold", "getGoldDungeonEvent"),
              floor_event(4, "pokeball0", "item_ball", "askPokeStarter(0)")]
    with_tower { assert_equal [:objects] * 3, events.map { |e| loc.event_category(e) } }
  end

  test "a dialogue Pokemon stays among the people" do
    poke = floor_event(15, "dialogue_poke_copy15_SLOWKING_1", "Followers/SLOWKING_1", "dialoguePokeEvent")
    with_tower { assert_equal :people, loc.event_category(poke) }
  end

  test "the objects list holds the floor's items, the people list none of them" do
    events = [floor_event(12, "item_copy12_POTION", "item_potion"),
              floor_event(13, "gold_copy13_GOLD_130", "item_gold", "getGoldDungeonEvent"),
              floor_event(14, "item_copy14_ULTRABALL", "item_ball"),
              floor_event(4, "pokeball0", "item_ball", "askPokeStarter(0)")]
    with_tower do
      ids = lambda { |cat| (listed(cat) & events).map { |e| e.id }.sort }
      assert_equal [[4, 12, 13, 14], []], [ids.call(:objects), ids.call(:people)]
    end
  end

  test "an item picked up leaves the objects list" do
    gold = floor_event(13, "gold_copy13_GOLD_130", "item_gold", "getGoldDungeonEvent")
    with_tower do
      gold.character_name = ""
      refute listed(:objects).include?(gold)
    end
  end

  test "hides the stairs of a tower floor whose minimap has not shown them, from the list and the sonar" do
    stairs = floor_event(1, "stairs", "stairs", "pbCommonEvent(3)")
    with_tower do
      on_floor(true, false) do
        assert_equal [true, false, nil],
                     [loc.hidden?(stairs), listed(:all).include?(stairs), PokeAccess::Sound::Scene.family_of(stairs)]
      end
    end
  end

  test "shows the stairs once the minimap has them" do
    stairs = floor_event(1, "stairs", "stairs", "pbCommonEvent(3)")
    with_tower do
      on_floor(true, true) { assert_equal [false, true], [loc.hidden?(stairs), listed(:all).include?(stairs)] }
    end
  end

  test "never hides the stairs off a tower floor, nor where the game keeps no minimap record" do
    stairs = floor_event(1, "stairs", "stairs", "pbCommonEvent(3)")
    with_tower do
      { "a map without the minimap" => [false, false], "a map with no metadata" => [nil, false],
        "no sawStairs record" => [true, :none] }.each do |what, (flagged, saw)|
        on_floor(flagged, saw) { refute loc.hidden?(stairs), what }
      end
    end
  end

  test "hides only the events named stairs" do
    door = floor_event(2, "exit", "door", "pbCommonEvent(4)")
    with_tower { on_floor(true, false) { refute loc.hidden?(door) } }
  end

  test "a shown Event Indicators bubble is said as a mark after the name" do
    azelf = World.event(:kind => :npc, :id => 2, :name => "azelf", :sprite => "Azelf")
    with_tower do
      with_indicators(2 => Indicator.new(true, false)) do
        assert_equal ["azelf", [t(:rel_indicator)]], [loc.target_name(azelf), loc.name_marks(azelf)]
      end
    end
  end

  test "a bubble hidden, disposed, missing or that cannot tell is no mark" do
    azelf = World.event(:kind => :npc, :id => 2, :name => "azelf", :sprite => "Azelf")
    with_tower do
      { "hidden" => Indicator.new(false, false), "disposed" => Indicator.new(true, true), "missing" => nil,
        "with no disposed?" => Undisposable.new(true), "with no visibility" => Unseeable.new(false) }.each do |what, sprite|
        with_indicators(2 => sprite) { assert_equal [], loc.name_marks(azelf), what }
      end
    end
  end

  test "without the plugin's sprites, no mark is said" do
    azelf = World.event(:kind => :npc, :id => 2, :name => "azelf", :sprite => "Azelf")
    with_tower { assert_equal [], loc.name_marks(azelf) }
  end

  test "a target that is no event is never marked" do
    surface = PokeAccess::Locator::SurfaceTarget.new(5, 5, "Agua", :water, nil)
    with_tower do
      with_indicators(0 => Indicator.new(true, false)) { assert_equal [], loc.name_marks(surface) }
    end
  end

  test "asking whether a target that is no event carries a bubble records no failure" do
    targets = [PokeAccess::Locator::SurfaceTarget.new(5, 5, "Agua", :water, nil),
               PokeAccess::Locator::SurfaceTarget.new(0, 5, "Salida", :exit, nil)]
    with_tower do
      with_indicators(0 => Indicator.new(true, false)) do
        before = PokeAccess.swallowed_sites.map { |site, n, _first| [site, n] }
        assert_equal [[], []], targets.map { |tg| loc.name_marks(tg) }
        assert_equal before, PokeAccess.swallowed_sites.map { |site, n, _first| [site, n] }
      end
    end
  end

  private

  def loc
    PokeAccess::Locator
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Runs the block with the profile's event rules registered after the locator's own, and takes them back after.
  def with_tower
    rules = loc.instance_variable_get(:@rules)
    mine = (self.class.tower_rules ||= load_tower(rules))
    mine.each { |kind, list| rules[kind].concat(list) }
    yield
  ensure
    mine.each { |kind, list| rules[kind].reject! { |r| list.any? { |m| m.equal?(r) } } } if mine
  end

  # Evaluates the profile's file as the harness loads one and takes back what it declares: the profile's name, and
  # the rules it registered, which it returns by kind.
  def load_tower(rules)
    game = PokeAccess::Game
    kept = [rules.map { |kind, list| [kind, list.length] }, game.profiles.dup, game.instance_variable_get(:@profile_name)]
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    game.profiles.replace(kept[1])
    game.instance_variable_set(:@profile_name, kept[2])
    kept[0].map { |kind, n| [kind, rules[kind].slice!(n..-1)] }
  end

  # A floor event as Create events.rb leaves it, placed on the map: a template's page (touch, one script call) under
  # a copy's name.
  def floor_event(id, name, sprite, script = "getItemDungeonEvent")
    page = TestPage.new(:trigger => 1, :sprite => sprite, :list => [TestCmd.new(355, [script]), TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => 5 + id, :y => 5, :name => name, :pages => [page])
  end

  # The locator's list for one category, rebuilt now, the category shown put back after.
  def listed(cat)
    was = loc.instance_variable_get(:@cat_id)
    loc.instance_variable_set(:@cat_id, cat)
    loc.rebuild_targets
    loc.instance_variable_get(:@targets).dup
  ensure
    loc.instance_variable_set(:@cat_id, was)
  end

  # Runs the block on a map whose metadata has the dungeonDisplay flag (flagged; nil for a map with no metadata) and
  # with the minimap's sawStairs as saw (:none for a game with no such record).
  def on_floor(flagged, saw)
    unless flagged.nil?
      meta = Object.new
      meta.define_singleton_method(:has_flag?) { |f| flagged && f == "dungeonDisplay" }
      $game_map.define_singleton_method(:metadata) { meta }
    end
    $PokemonGlobal.define_singleton_method(:sawStairs) { saw } unless saw == :none
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :metadata) if $game_map.singleton_methods.include?(:metadata)
    $PokemonGlobal.singleton_class.send(:remove_method, :sawStairs) if $PokemonGlobal.singleton_methods.include?(:sawStairs)
  end

  # Runs the block with the scene's spriteset carrying the indicator sprites given by event id.
  def with_indicators(by_id)
    sprites = []
    by_id.each { |id, sp| sprites[id] = sp }
    set = Object.new
    set.define_singleton_method(:event_indicator_sprites) { sprites }
    $scene.define_singleton_method(:spriteset) { |*_a| set }
    yield
  ensure
    $scene.singleton_class.send(:remove_method, :spriteset)
  end
end
