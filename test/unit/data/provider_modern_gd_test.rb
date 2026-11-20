# The GameData data provider (DataV21) as PokeAccess::Data serves it on a GameData engine: each datum from its
# registry, under the names and lookups v19 to v21 and the Infinite Fusion games give that data.
class ProviderModernGdTest < PokeAccessTest
  LAYER = PokeAccess::Data
  V21 = PokeAccess::DataV21
  Named = Struct.new(:name)

  test "serves on a GameData engine, above gen-6's provider" do
    assert_equal [V21, 20], [LAYER.active, LAYER.active_priority]
  end

  test "names moves, types, items, species, abilities, natures, statuses and stats through their registries" do
    { [:move_name, 7] => "Move7", [:move_type_name, 7] => "TypeTYPE1", [:move_description, 7] => "desc7",
      [:type_name, :FIRE] => "TypeFIRE", [:item_name, :POTION] => "ItemPOTION",
      [:item_description, :POTION] => "idescPOTION", [:species_name, :PIKACHU] => "SpeciesPIKACHU",
      [:ability_name, :STATIC] => "AbilitySTATIC", [:nature_name, :BOLD] => "NatureBOLD",
      [:status_name, :BURN] => "StatusBURN", [:stat_name, :ATTACK] => "StatATTACK" }.each do |(method, id), want|
      assert_equal want, LAYER.send(method, id), "#{method}(#{id.inspect})"
    end
  end

  test "reads a move's power, accuracy, pp and category under v21's names or the Infinite Fusion games' older ones" do
    moves = { :THUNDERBOLT => datum(:power => 90, :accuracy => 100, :total_pp => 15, :category => 1),
              :VINEWHIP => datum(:base_damage => 45, :accuracy => 95, :totalpp => 25, :category => 0) }
    with_registry(:Move, registry(moves)) do
      { :THUNDERBOLT => [90, 100, 15, 1], :VINEWHIP => [45, 95, 25, 0] }.each do |id, want|
        assert_equal want, [LAYER.move_power(id), LAYER.move_accuracy(id), LAYER.move_total_pp(id), LAYER.move_category(id)],
                     "power, accuracy, pp and category of #{id}"
      end
    end
  end

  test "an item's plural is its name_plural, else its portion plural, else its portion name, else its name" do
    items = { :FUSION => datum(:name => "Pocion", :name_plural => "Pociones"),
              :V21 => datum(:name => "Pocion", :portion_name => "Pocion", :portion_name_plural => "Pociones"),
              :PORTION => datum(:name => "Baya", :portion_name => "Racimo de bayas"),
              :PLAIN => datum(:name => "Ticket") }
    with_registry(:Item, registry(items)) do
      { :FUSION => "Pociones", :V21 => "Pociones", :PORTION => "Racimo de bayas", :PLAIN => "Ticket" }.each do |id, want|
        assert_equal want, LAYER.item_name_plural(id), "for an item shaped as #{id}"
      end
    end
  end

  test "reads an ability's description from its registry" do
    abilities = { :STATIC => datum(:name => "Elec. Estatica", :description => "Puede paralizar al contacto.") }
    with_registry(:Ability, registry(abilities)) do
      assert_equal "Puede paralizar al contacto.", LAYER.ability_description(:STATIC)
    end
  end

  test "a species entry is its name, category and dex entry, any part its data lacks left empty" do
    assert_equal ["SpeciesPIKACHU", "catPIKACHU", "dexPIKACHU"], LAYER.species_entry(:PIKACHU), "a species with all three"
    with_registry(:Species, registry(:MISSINGNO => datum(:name => "MissingNo."))) do
      assert_equal ["MissingNo.", nil, nil], LAYER.species_entry(:MISSINGNO), "one with a name only"
    end
  end

  test "names a species' types from its types or v19's type1 and type2, each once, skipping one the game cannot name" do
    species = { :CHARIZARD => datum(:types => [:FIRE, :FLYING]), :PIKACHU => datum(:types => [:ELECTRIC]),
                :ODDISH => datum(:type1 => :GRASS, :type2 => :POISON), :MAGIKARP => datum(:type1 => :WATER, :type2 => :WATER),
                :SHADOWMON => datum(:types => [:FIRE, :SHADOW]) }
    with_registry(:Species, registry(species)) do
      { :CHARIZARD => ["TypeFIRE", "TypeFLYING"], :PIKACHU => ["TypeELECTRIC"], :ODDISH => ["TypeGRASS", "TypePOISON"],
        :MAGIKARP => ["TypeWATER"] }.each do |id, want|
        assert_equal want, LAYER.species_types(id), "for #{id}"
      end
      with_registry(:Type, registry(:FIRE => Named.new("Fuego"))) do
        assert_equal ["Fuego"], LAYER.species_types(:SHADOWMON), "a type the game cannot name"
      end
    end
  end

  test "names a pokemon's types from its symbols, skipping one the game cannot name" do
    with_registry(:Type, registry(:FIRE => Named.new("Fuego"), :FLYING => Named.new("Volador"))) do
      { [:FIRE, :FLYING] => ["Fuego", "Volador"], [:FIRE, :SHADOW] => ["Fuego"] }.each do |types, want|
        assert_equal want, LAYER.pokemon_types(datum(:types => types)), "for #{types.inspect}"
      end
      assert_equal [], V21.pokemon_types(Object.new), "a pokemon that cannot give its types"
    end
  end

  test "names a trainer class by its id, never asking a registry about a class it lacks" do
    rows = { :HIKER => Named.new("Montanero"), 3 => Named.new("Posadera") }
    [[:try_get], [:exists?]].each do |lookups|
      classes = registry(rows, lookups)
      with_registry(:TrainerType, classes) do
        { :HIKER => "Montanero", "HIKER" => "Montanero", 3 => "Posadera" }.each do |id, want|
          assert_equal want, LAYER.trainer_type_name(id), "with #{lookups.inspect}, for #{id.inspect}"
        end
        assert_nil V21.trainer_type_name("NOBODY"), "with #{lookups.inspect}, a class it lacks"
      end
      refute classes.asked.include?(:NOBODY), "with #{lookups.inspect}, the registry never got that class"
    end
    with_registry(:TrainerType, registry(rows)) do
      assert_equal "Montanero", V21.trainer_type_name("HIKER"), "with get alone"
    end
  end

  test "turns an item symbol or name from an event script into its symbol and name, never asking about one it lacks" do
    rows = { :POTION => Named.new("Pocion") }
    [[:try_get], [:exists?]].each do |lookups|
      items = registry(rows, lookups)
      with_registry(:Item, items) do
        assert_equal [[:POTION, "Pocion"], [:POTION, "Pocion"], [:NOPE, nil]],
                     [LAYER.item_id(:POTION), LAYER.item_id("POTION"), LAYER.item_id("NOPE")], "with #{lookups.inspect}"
      end
      refute items.asked.include?(:NOPE), "with #{lookups.inspect}, the registry never got that item"
    end
    with_registry(:Item, registry(rows)) do
      assert_equal [[:POTION, "Pocion"], [:NOPE, nil]], [LAYER.item_id(:POTION), LAYER.item_id(:NOPE)],
                   "with get alone, whose error on an unknown item is no name"
    end
  end

  test "a move symbol is its own id where the game has the move, nil where it does not" do
    with_registry(:Move, registry({ :TACKLE => Named.new("Placaje") }, [:exists?])) do
      assert_equal [:TACKLE, nil], [LAYER.move_id(:TACKLE), LAYER.move_id(:NOTAMOVE)]
    end
  end

  test "a national number names the first form at its place in the load order, up to the last anchor it reaches" do
    ids = national(35)
    ids.insert(25, :MON25_1)
    with_registry(:Species, species_table(ids)) do
      assert_equal [:BULBASAUR, :MON25, :NIDORINA, nil, nil], [1, 25, 30, 31, 0].map { |n| national_species(n) }
    end
  end

  test "no national number names a species where the load order does not begin as the national one" do
    with_registry(:Species, species_table([:KOFFING, :WEEZING] + national(30))) do
      assert_equal [nil, nil, nil], [1, 10, 25].map { |n| national_species(n) }
    end
  end

  test "a species of the game's own inside the order cuts the numbers at the last anchor before it" do
    ids = national(30)
    ids.insert(14, :OWNMON)
    with_registry(:Species, species_table(ids)) do
      assert_equal [:BULBASAUR, :CATERPIE, nil, nil, nil], [1, 10, 11, 15, 20].map { |n| national_species(n) }
    end
  end

  test "where species are keyed by number, as in v19 and Infinite Fusion, a number is its own species" do
    with_registry(:Species, species_table([:PIKACHU, 25])) do
      assert_equal [25, nil], [national_species(25), national_species(26)]
    end
  end

  test "species not loaded yet name no number, and are read again once the table is loaded" do
    with_registry(:Species, species_table([])) { assert_nil national_species(1) }
    with_registry(:Species, species_table(national(10))) { assert_equal :CATERPIE, national_species(10) }
  end

  test "an overworld sprite's number names its species as the game spells it, past its female, shiny and form marks" do
    with_registry(:Species, species_table(national(30))) do
      { "025" => "MonMON25", "025s" => "MonMON25", "025f" => "MonMON25", "025_1" => "MonMON25",
        "025fs_1" => "MonMON25", "025s_12" => "MonMON25", "030" => "MonNIDORINA", "031" => nil, "000" => nil,
        "0025" => nil, "025_" => nil, "025sf" => nil, "s025" => nil }.each do |sprite, want|
        assert_equal [want], [PokeAccess::Locator.sprite_species(sprite)], "the sprite #{sprite}"
      end
    end
  end

  test "a sheet the game lacks names no species by the load order, while a table keyed by number still names it" do
    loc = PokeAccess::Locator
    loc.define_singleton_method(:pbResolveBitmap) { |path| path =~ /025\z/ ? "#{path}.png" : nil }
    with_registry(:Species, species_table(national(30))) do
      assert_equal ["MonMON25", nil], [loc.sprite_species("025"), loc.sprite_species("026")]
    end
    with_registry(:Species, species_table([26])) { assert_equal "Mon26", loc.sprite_species("026") }
  ensure
    loc.singleton_class.send(:remove_method, :pbResolveBitmap)
    loc.instance_variable_set(:@sheet_files, nil)
  end

  private

  # A data object answering each field of fields with its value.
  def datum(fields)
    Struct.new(*fields.keys).new(*fields.values)
  end

  # A stand-in GameData registry of rows (id => data) that answers get and the lookups named (:try_get, :exists?), as
  # each version of GameData does; get raises for an id it lacks, and asked lists every id get was given.
  def registry(rows, lookups = [])
    asked = []
    klass = Class.new
    klass.define_singleton_method(:asked) { asked }
    klass.define_singleton_method(:get) { |id| asked << id; rows.fetch(id) }
    klass.define_singleton_method(:try_get) { |id| rows[id] } if lookups.include?(:try_get)
    klass.define_singleton_method(:exists?) { |id| rows.key?(id) } if lookups.include?(:exists?)
    klass
  end

  # The species a national number names, through the data layer as the locator asks.
  def national_species(n)
    LAYER.optional(:national_species, n)
  end

  # The national order through number last: each anchor's own species, a stand-in for every other number.
  def national(last)
    (1..last).map { |n| V21::NATIONAL_ANCHORS[n] || :"MON#{n}" }
  end

  # A stand-in GameData::Species whose table loads ids in the order given, each its first form unless named Base_N
  # (form N of Base) and named "Mon<id>"; an Integer id keys a row by number, as v19 did.
  def species_table(ids)
    rows = {}
    ids.each { |id| rows[id] = datum(:id => id, :form => (id.to_s =~ /_(\d+)\z/ ? $1.to_i : 0), :name => "Mon#{id}") }
    klass = Class.new
    klass.const_set(:DATA, rows)
    klass.define_singleton_method(:get) { |id| rows.fetch(id) }
    klass.define_singleton_method(:each_species) { |&blk| rows.each_value { |s| blk.call(s) if s.form == 0 } }
    klass
  end

  # Runs the block with GameData::<name> replaced by klass, the harness's own put back after.
  def with_registry(name, klass)
    was = GameData.send(:remove_const, name)
    GameData.const_set(name, klass)
    yield
  ensure
    GameData.send(:remove_const, name) if GameData.const_defined?(name, false)
    GameData.const_set(name, was)
  end
end
