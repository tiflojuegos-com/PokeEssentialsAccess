Harness.load_common("rv_common")

# The data provider of the engine Reborn, Rejuvenation and Desolation share (DataRV): a $cache of data objects keyed by
# symbol and the game's own get*Name helpers over it, in Reborn's shape and in Desolation's.
class ProviderRvTest < PokeAccessTest
  RV = PokeAccess::DataRV
  MM = PokeAccess::MapMeta

  Mon = Struct.new(:name, :Type1, :Type2, :kind, :dexentry)
  Move = Struct.new(:name, :type, :category, :basedamage, :accuracy, :maxpp, :desc)
  Item = Struct.new(:name, :desc, :plural)
  Ability = Struct.new(:name, :fullName, :fullDesc, :desc)
  Named = Struct.new(:name)
  TrainerClass = Struct.new(:title)
  Cache = Struct.new(:pkmn, :moves, :items, :abil, :types, :natures, :trainertypes, :mapdata, :RXevents)
  MapRow = Struct.new(:Outdoor, :HealingSpot, :DiveMap)
  CommonEvent = Struct.new(:list)
  DesoMon = Struct.new(:name, :Type1, :Type2, :forms, :formData)
  Nature = Struct.new(:name, :incStat, :decStat)
  MapData = Struct.new(:MapPosition)
  DesoCache = Struct.new(:pkmn, :moves, :items, :abil, :types, :natures, :mapdata, :town_map)
  Pokedex = Struct.new(:dexList)
  Trainer = Struct.new(:pokedex)
  Pokemon = Struct.new(:type1, :type2, :level, :exp, :growthrate)

  FULL_STATS = ["HP", "Attack", "Defense", "Special Attack", "Special Defense", "Speed", "Accuracy", "Evasion"].freeze
  BATTLE_STATS = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed", "accuracy", "evasiveness"].freeze

  # A species of Reborn's table: its forms by number and each form's data, a form it lacks answered with the first.
  class Species
    attr_reader :forms
    def initialize(forms, data); @forms = forms; @data = data; end
    def [](form); @data[form] || @data[0]; end
  end

  # The species table of Reborn and Rejuvenation: [species] is the species, [species, form] that form's data.
  class FormTable
    def initialize(rows); @rows = rows; end
    def [](*args)
      species = @rows.fetch(args[0])
      args.length == 1 ? species : species[args[1]]
    end
  end

  # Reborn's map data: an Array whose [] answers a map it keeps nothing for with a blank row, as MapDataCache does.
  class MapDataCache < Array
    def [](index); fetch(index, nil) || MapRow.new(nil, nil, nil); end
  end

  # The experience table of the engine's PBExp: a level starts at its square times ten, up to level 100.
  module ExpTable
    def self.startExperience(level, _growth); [level, 100].min**2 * 10; end
  end

  # Reborn's own helpers over its $cache; a machine's description is its move's.
  REBORN = {
    :getMonName => lambda { |species, form = 0| $cache.pkmn[species, form].name },
    :getMoveName => lambda { |move| $cache.moves[move].name },
    :getMoveDesc => lambda { |move| $cache.moves[move] ? $cache.moves[move].desc : "" },
    :getTypeName => lambda { |type| $cache.types[type] ? $cache.types[type].name : "" },
    :getItemName => lambda { |item| $cache.items[item].name },
    :getItemDescription => lambda { |item| item == :TM01 ? getMoveDesc(:THUNDERSHOCK) : $cache.items[item].desc },
    :getAbilityName => lambda { |abil, _short = false| $cache.abil[abil] ? $cache.abil[abil].fullName : "" },
    :getAbilityDesc => lambda { |abil| $cache.abil[abil] ? $cache.abil[abil].fullDesc : "" },
    :getNatureName => lambda { |nature| $cache.natures[nature] ? $cache.natures[nature].name : "" }
  }.freeze

  # Rejuvenation's over Reborn's: getItemName takes plural:, and getStatName names a stat in the mode asked.
  REJUVENATION = {
    :getItemName => lambda { |item, _article = nil, plural: false| plural ? $cache.items[item].plural : $cache.items[item].name },
    :getStatName => lambda { |stat, mode = :battle| (mode == :full ? FULL_STATS : BATTLE_STATS)[stat].to_s }
  }.freeze

  # Desolation's, which has no getItemDescription and no getStatName.
  DESOLATION = {
    :getMonName => lambda { |mon| $cache.pkmn[mon].name },
    :getTypeName => lambda { |type| $cache.types[type] ? $cache.types[type].name : "" },
    :getItemName => lambda { |item| $cache.items[item].name }
  }.freeze

  test "takes the engine for its own only by a $cache with species, moves and abilities, and no GameData" do
    tables = Struct.new(:pkmn, :moves, :abil).new({}, {}, {})
    { "species, moves and abilities" => [tables, true], "no $cache" => [nil, false],
      "no species" => [Struct.new(:moves, :abil).new({}, {}), false],
      "no moves" => [Struct.new(:pkmn, :abil).new({}, {}), false],
      "no abilities" => [Struct.new(:pkmn, :moves).new({}, {}), false],
      "a $cache that cannot be asked" => [BasicObject.new, false] }.each do |what, (cache, want)|
      assert_equal want, with_cache(cache) { RV.engine? }, "with #{what}"
    end
    assert_equal false, with_toplevel(:GameData, Module.new) { with_cache(tables) { RV.engine? } },
                 "with those tables beside GameData"
  end

  test "reads names, and the descriptions of moves and abilities, through the game's own helpers" do
    in_reborn do
      { [:species_name, :PIKACHU] => "Pikachu", [:move_name, :THUNDERSHOCK] => "Thunder Shock",
        [:item_name, :POTION] => "Potion", [:ability_name, :STATIC] => "Static", [:nature_name, :TIMID] => "Timid",
        [:type_name, :ELECTRIC] => "Electric", [:move_description, :THUNDERSHOCK] => "A jolt.",
        [:ability_description, :STATIC] => "May paralyze on contact." }.each do |(method, id), want|
        assert_equal want, RV.send(method, id), "#{method}(#{id})"
      end
    end
  end

  test "takes a helper's empty answer for no answer" do
    in_reborn do
      [[:type_name, :FAIRY], [:nature_name, :BRAVE], [:move_description, :SPLASH], [:ability_name, :LEVITATE]].each do |method, id|
        assert_nil RV.send(method, id), "#{method}(#{id})"
      end
    end
  end

  test "reads a move's power, accuracy, pp and type from its data" do
    in_reborn do
      assert_equal [40, 100, 30, "Electric"],
                   [RV.move_power(:THUNDERSHOCK), RV.move_accuracy(:THUNDERSHOCK), RV.move_total_pp(:THUNDERSHOCK),
                    RV.move_type_name(:THUNDERSHOCK)]
    end
  end

  test "numbers a move's category as the other eras do: physical 0, special 1, status 2" do
    in_reborn { assert_equal [0, 1, 2], [:TACKLE, :THUNDERSHOCK, :GROWL].map { |move| RV.move_category(move) } }
  end

  test "an item's description is the game's getItemDescription, which gives a machine its move's" do
    in_reborn { assert_equal ["Restores 20 HP.", "A jolt."], [RV.item_description(:POTION), RV.item_description(:TM01)] }
  end

  test "an item's description is its data's own where the game has no getItemDescription" do
    in_desolation { assert_equal "Restores 20 HP.", RV.item_description(:POTION) }
  end

  test "an item's plural is getItemName's plural where it takes plural:, else the name" do
    in_reborn { assert_equal "Potion", RV.item_name_plural(:POTION), "Reborn's takes none" }
    in_reborn(:extra => REJUVENATION) { assert_equal "Potions", RV.item_name_plural(:POTION), "Rejuvenation's does" }
  end

  test "a stat is the game's full name where it has getStatName, else the mod's word for its number" do
    i18n = PokeAccess::I18n
    in_reborn do
      assert_equal [i18n.t(:st_atk), i18n.t(:st_evasion)], [RV.stat_name(1), RV.stat_name(7)], "Reborn has no getStatName"
      assert_nil RV.stat_name(:ATTACK), "a stat that is no number"
    end
    in_reborn(:extra => REJUVENATION) do
      assert_equal "Special Attack", RV.stat_name(3), "Rejuvenation names it in full"
      assert_nil RV.stat_name(8), "a number past its stats"
    end
  end

  test "words a status by the mod, nothing for no status" do
    i18n = PokeAccess::I18n
    { :SLEEP => i18n.t(:st_sleep), :FROZEN => i18n.t(:st_freeze), :PETRIFIED => i18n.t(:st_petrified) }.each do |status, want|
      assert_equal want, RV.status_name(status), status.to_s
    end
    [nil, :NONE].each { |status| assert_nil RV.status_name(status), status.inspect }
  end

  test "a species entry is its base form's name, category and dex text, any part its data lacks left empty" do
    in_reborn { assert_equal ["Rotom", "Plasma", "A body of plasma."], RV.species_entry(:ROTOM), "a species with all three" }
    in_desolation { assert_equal ["Sandshrew", nil, nil], RV.species_entry(:SANDSHREW), "one whose data keeps neither text" }
  end

  test "a species' types are its base form's, each once" do
    in_reborn do
      { :PIKACHU => ["Electric"], :ROTOM => ["Electric", "Ghost"], :MAGIKARP => ["Water"] }.each do |species, want|
        assert_equal want, RV.species_types(species), species.to_s
      end
    end
    in_desolation { assert_equal ["Ground"], RV.species_types(:SANDSHREW), "Desolation's Sandshrew, last seen Alolan" }
  end

  test "a pokemon's types come from its own symbols, a missing or unnamed one skipped" do
    in_reborn do
      { [:ELECTRIC, nil] => ["Electric"], [:ELECTRIC, :GHOST] => ["Electric", "Ghost"], [:WATER, :WATER] => ["Water"],
        [:ELECTRIC, :FAIRY] => ["Electric"] }.each do |(first, second), want|
        assert_equal want, RV.pokemon_types(Pokemon.new(first, second)), "types #{first.inspect} and #{second.inspect}"
      end
    end
  end

  test "names a trainer class by its symbol or name, and nothing for a number, one it lacks or one untitled" do
    in_reborn do
      [:YOUNGSTER, "YOUNGSTER"].each { |id| assert_equal "Youngster", RV.trainer_type_name(id), "for #{id.inspect}" }
      [3, "NOBODY", :UNTITLED].each { |id| assert_nil RV.trainer_type_name(id), "for #{id.inspect}" }
    end
  end

  test "an item or move symbol from an event script is its own id, where the game has it" do
    in_reborn do
      assert_equal [[:POTION, "Potion"], [:NOPE, nil]], [RV.item_id("POTION"), RV.item_id(:NOPE)], "items"
      assert_equal [:THUNDERSHOCK, nil], [RV.move_id("THUNDERSHOCK"), RV.move_id("NOPE")], "moves"
    end
  end

  test "gives a species' Pokedex row only where the Pokedex keeps rows as Hashes" do
    in_desolation(:seen => { :SANDSHREW => "Alolan" }) do
      assert_equal pokedex_row("Alolan"), RV.dex_row(:SANDSHREW), "a species seen"
      assert_nil RV.dex_row(:PIKACHU), "one never seen"
      $Trainer.pokedex.dexList[:PIKACHU] = Struct.new(:seen).new(true)
      assert_nil RV.dex_row(:PIKACHU), "a row kept as an object, as Rejuvenation keeps it"
    end
  end

  test "a Pokedex entry shows the form last seen, its formData's types over the base form's" do
    in_desolation do
      { :SANDSHREW => ["Ice", "Steel"], :EXEGGUTOR => ["Grass", "Dragon"], :VULPIX => ["Ice"],
        :PIKACHU => ["Electric"] }.each do |species, want|
        assert_equal want, RV.dex_shown_types(species), species.to_s
      end
    end
  end

  test "in Reborn's table, the form last seen is found by its name, the base form for a name it lacks" do
    in_reborn(:seen => { :ROTOM => "Heat", :PIKACHU => "" }) do
      assert_equal [["Electric", "Fire"], ["Electric"]], [RV.dex_shown_types(:ROTOM), RV.dex_shown_types(:PIKACHU)]
    end
    in_reborn(:seen => { :ROTOM => "Fan" }) { assert_equal ["Electric", "Ghost"], RV.dex_shown_types(:ROTOM) }
  end

  test "a randomized game shows the randomizer's types, or the game's own for a species it left alone" do
    random = { :PIKACHU => DesoMon.new("Pikachu", :WATER, nil, {}, {}) }
    in_desolation(:random => random) do
      assert_equal [["Water"], ["Ice", "Steel"]], [RV.dex_shown_types(:PIKACHU), RV.dex_shown_types(:SANDSHREW)], "Desolation"
    end
    random = FormTable.new(:ROTOM => Species.new({ 0 => "Normal", 1 => "Heat" },
                                                 [Mon.new("Rotom", :WATER, :GHOST), Mon.new("Heat Rotom", :WATER, :FIRE)]))
    in_reborn(:seen => { :ROTOM => "Heat", :PIKACHU => "" }, :random => random) do
      assert_equal [["Water", "Fire"], ["Electric"]], [RV.dex_shown_types(:ROTOM), RV.dex_shown_types(:PIKACHU)], "Reborn"
    end
  end

  test "a Pokedex entry shows no types without a row, with nothing last seen, or for a species the table lacks" do
    in_desolation(:seen => { :MISSINGNO => "" }) do
      $Trainer.pokedex.dexList[:EXEGGUTOR] = { :seen? => true, :owned? => false }
      { :PIKACHU => "no row", :EXEGGUTOR => "nothing last seen", :MISSINGNO => "a species the table lacks" }.each do |species, what|
        assert_nil RV.dex_shown_types(species), what
      end
    end
  end

  test "a nature's raised and lowered stats, none for one kept without them or for what is no nature of the engine" do
    in_desolation do
      assert_equal [[1, 3], [nil, nil]], [RV.nature_stats(:ADAMANT), RV.nature_stats(:HARDY)], "Desolation's natures"
      [3, "ADAMANT", :BRAVE].each { |nature| assert_nil RV.nature_stats(nature), nature.inspect }
    end
    in_reborn { assert_nil RV.nature_stats(:TIMID), "Reborn keeps natures without their stats" }
    off_engine { assert_nil RV.nature_stats(:ADAMANT), "off the engine" }
  end

  test "a map's place on the town map, nothing for a map left unplaced, with no map data or off the engine" do
    in_desolation { assert_equal [[0, 7, 17], nil], [RV.map_position(1), RV.map_position(5)] }
    bare_engine { assert_nil RV.map_position(1), "an engine keeping no map data" }
    off_engine { assert_nil RV.map_position(1), "off the engine" }
  end

  test "a map's metadata is its map data's by the GameData names, a map kept with none has none, nothing off the engine" do
    in_reborn_maps do
      assert_equal({ :outdoor_map => true, :teleport_destination => nil, :dive_map_id => 7 }, RV.map_metadata(1))
      assert_equal({ :outdoor_map => nil, :teleport_destination => [3, 4, 5], :dive_map_id => nil }, RV.map_metadata(2))
      assert_equal({ :outdoor_map => nil, :teleport_destination => nil, :dive_map_id => nil }, RV.map_metadata(9),
                   "Reborn's blank row for a map it keeps nothing for")
    end
    in_desolation { assert_equal({}, RV.map_metadata(5), "a hole in Desolation's map data") }
    off_engine { assert_nil RV.map_metadata(1) }
  end

  test "the maps that name a map under their sea, and the common events, are those the engine keeps" do
    in_reborn_maps { assert_equal [{ 1 => 7 }, [:cmd]], [RV.dive_maps, RV.common_events[1].list] }
    off_engine { assert_equal [nil, nil], [RV.dive_maps, RV.common_events] }
  end

  test "MapMeta and the event walk read the engine's map data and common events through it" do
    in_reborn_maps do
      Harness.with_provider(RV) do
        surface_index_afresh do
          assert_equal [true, false, true, 7, nil, 1],
                       [MM.outdoor?(1), MM.outdoor?(2), MM.pokecenter?(2), MM.dive_map(1), MM.dive_map(2), MM.surface_map(7)]
        end
        assert_equal [:cmd], PokeAccess::EventPages.common_list(1)
      end
    end
  end

  test "a region's town map points, where the engine keeps the region as its name, picture and points" do
    in_desolation do
      assert_equal [[7, 17, "Keneph Beach", "", nil, nil, nil, nil]], RV.town_points(0), "Desolation's region 0"
      assert_nil RV.town_points(3), "a region it lacks"
      $cache.town_map = [{ :filename => "mapRegion0.png" }]
      assert_nil RV.town_points(0), "a region kept as a Hash, as Reborn and Rejuvenation keep it"
    end
    bare_engine { assert_nil RV.town_points(0), "an engine keeping no town map" }
    off_engine { assert_nil RV.town_points(0), "off the engine" }
  end

  test "tells a symbol that is one of the engine's types" do
    in_desolation { assert_equal [true, false], [RV.type?(:ICE), RV.type?(:UP)] }
    off_engine { assert_equal false, RV.type?(:ICE), "off the engine" }
  end

  test "an ability's short description, the one the summary paints under it" do
    in_reborn { assert_equal ["Paralyzes on contact.", nil], [RV.ability_summary(:STATIC), RV.ability_summary(:LEVITATE)] }
    off_engine { assert_nil RV.ability_summary(:STATIC), "off the engine" }
  end

  test "the experience a pokemon still needs for its next level, nothing at the cap or off the engine" do
    with_toplevel(:PBExp, ExpTable) do
      in_reborn do
        { [5, 260] => 100, [5, 359] => 1 }.each do |(level, exp), want|
          assert_equal want, RV.exp_left(Pokemon.new(nil, nil, level, exp, :medium)), "level #{level} with #{exp}"
        end
        [[5, 360], [5, 400], [100, 100_000]].each do |level, exp|
          assert_nil RV.exp_left(Pokemon.new(nil, nil, level, exp, :medium)), "level #{level} with #{exp}"
        end
      end
      off_engine { assert_nil RV.exp_left(Pokemon.new(nil, nil, 5, 260, :medium)), "off the engine" }
    end
    with_toplevel(:PBExp, nil) do
      in_reborn { assert_nil RV.exp_left(Pokemon.new(nil, nil, 5, 260, :medium)), "an engine without PBExp" }
    end
  end

  private

  # Reborn's $cache: Pikachu, Rotom with its Heat form and Magikarp, a move of each category, a potion and a machine,
  # Static, the types they use, Timid and two trainer classes, one untitled.
  def reborn_cache
    Cache.new(FormTable.new(:PIKACHU => Species.new({ 0 => "Normal" }, [Mon.new("Pikachu", :ELECTRIC, nil, "Mouse", "It stores electricity.")]),
                            :ROTOM => Species.new({ 0 => "Normal", 1 => "Heat" },
                                                  [Mon.new("Rotom", :ELECTRIC, :GHOST, "Plasma", "A body of plasma."),
                                                   Mon.new("Heat Rotom", :ELECTRIC, :FIRE, "Plasma", "It heats ovens.")]),
                            :MAGIKARP => Species.new({ 0 => "Normal" }, [Mon.new("Magikarp", :WATER, :WATER, "Fish", "It splashes.")])),
              { :TACKLE => Move.new("Tackle", :NORMAL, :physical, 40, 100, 35, "A full-body charge."),
                :THUNDERSHOCK => Move.new("Thunder Shock", :ELECTRIC, :special, 40, 100, 30, "A jolt."),
                :GROWL => Move.new("Growl", :NORMAL, :status, 0, 100, 40, "It growls.") },
              { :POTION => Item.new("Potion", "Restores 20 HP.", "Potions"), :TM01 => Item.new("TM01", "Teaches a move.", "TM01s") },
              { :STATIC => Ability.new("Static", "Static", "May paralyze on contact.", "Paralyzes on contact.") },
              { :NORMAL => Named.new("Normal"), :ELECTRIC => Named.new("Electric"), :GHOST => Named.new("Ghost"),
                :FIRE => Named.new("Fire"), :WATER => Named.new("Water") },
              { :TIMID => Named.new("Timid") },
              { :YOUNGSTER => TrainerClass.new("Youngster"), :UNTITLED => TrainerClass.new("") })
  end

  # Desolation's $cache: a plain species table with each form's own types in formData by form name, a potion, the types
  # its species use, two natures, map 1 placed on the town map and region 0 kept as name, picture and points.
  def desolation_cache
    alolan = { 0 => "Normal", 1 => "Alolan" }
    DesoCache.new({ :SANDSHREW => DesoMon.new("Sandshrew", :GROUND, nil, alolan, { "Alolan" => { :Type1 => :ICE, :Type2 => :STEEL } }),
                    :EXEGGUTOR => DesoMon.new("Exeggutor", :GRASS, :PSYCHIC, alolan, { "Alolan" => { :Type2 => :DRAGON } }),
                    :VULPIX => DesoMon.new("Vulpix", :FIRE, nil, alolan, { "Alolan" => { :Type1 => :ICE } }),
                    :PIKACHU => DesoMon.new("Pikachu", :ELECTRIC, nil, {}, {}) },
                  {}, { :POTION => Item.new("Potion", "Restores 20 HP.") }, {},
                  { :GROUND => Named.new("Ground"), :ICE => Named.new("Ice"), :STEEL => Named.new("Steel"),
                    :GRASS => Named.new("Grass"), :PSYCHIC => Named.new("Psychic"), :DRAGON => Named.new("Dragon"),
                    :FIRE => Named.new("Fire"), :ELECTRIC => Named.new("Electric"), :WATER => Named.new("Water") },
                  { :ADAMANT => Nature.new("Adamant", 1, 3), :HARDY => Nature.new("Hardy", nil, nil) },
                  [nil, MapData.new([0, 7, 17])],
                  [[nil, "mapRegion0.png", [[7, 17, "Keneph Beach", "", nil, nil, nil, nil]]]])
  end

  # Runs the block in Reborn's engine: its $cache, a Pokedex row per species seen (species => form name last seen), a
  # randomizer's table and its helpers, with extra helpers over them.
  def in_reborn(seen: {}, random: nil, extra: {})
    in_engine(reborn_cache, seen, random, REBORN.merge(extra)) { yield }
  end

  # Runs the block in Reborn's engine with its map data (map 1 outdoors over the sea of map 7, map 2 a healing spot)
  # and common event 1.
  def in_reborn_maps
    cache = reborn_cache
    cache.mapdata = MapDataCache.new([nil, MapRow.new(true, nil, 7), MapRow.new(nil, [3, 4, 5], nil)])
    cache.RXevents = [nil, CommonEvent.new([:cmd])]
    in_engine(cache, {}, nil, REBORN) { yield }
  end

  # Runs the block with MapMeta's index of the maps above a sea built afresh, and drops it after.
  def surface_index_afresh
    MM.instance_variable_set(:@surface_of, nil)
    yield
  ensure
    MM.instance_variable_set(:@surface_of, nil)
  end

  # Runs the block in Desolation's engine, Sandshrew, Exeggutor and Vulpix last seen in their Alolan form and Pikachu
  # seen unless seen says otherwise.
  def in_desolation(seen: { :SANDSHREW => "Alolan", :EXEGGUTOR => "Alolan", :VULPIX => "Alolan", :PIKACHU => "" },
                    random: nil)
    in_engine(desolation_cache, seen, random, DESOLATION) { yield }
  end

  # Runs the block with $cache, $Trainer's Pokedex, $random_dex and the game's helpers in place; all are put back after.
  def in_engine(cache, seen, random, helpers)
    had = [$cache, $Trainer, $random_dex]
    $cache = cache
    $Trainer = Trainer.new(Pokedex.new(Hash[seen.map { |species, form| [species, pokedex_row(form)] }]))
    $random_dex = random
    GameFunctions.with(helpers) { yield }
  ensure
    $cache, $Trainer, $random_dex = had
  end

  # A Pokedex row of these games, its form last seen by name.
  def pokedex_row(form)
    { :seen? => true, :owned? => true, :lastSeen => { :gender => "Male", :form => form, :shiny => false } }
  end

  # The block's value with $cache as cache, put back after.
  def with_cache(cache)
    had = $cache
    $cache = cache
    yield
  ensure
    $cache = had
  end

  # Runs the block on the engine under a $cache holding only its species, moves and abilities tables, all empty.
  def bare_engine
    with_cache(Struct.new(:pkmn, :moves, :abil).new({}, {}, {})) { yield }
  end

  # Runs the block off the engine, under another engine's $cache: no species, moves or abilities tables of these
  # games, but the natures, map data, town map, abilities and types they keep.
  def off_engine
    other = Struct.new(:natures, :mapdata, :town_map, :abil, :types)
    with_cache(other.new({ :ADAMANT => Nature.new("Adamant", 1, 3) }, [nil, MapData.new([0, 7, 17])],
                         [[nil, "mapRegion0.png", [[7, 17, "Keneph Beach", "", nil, nil, nil, nil]]]],
                         { :STATIC => Ability.new("Static", "Static", "May paralyze on contact.", "Paralyzes on contact.") },
                         { :ICE => Named.new("Ice") })) { yield }
  end

  # The block's value with Object::<name> set to value (absent for nil), putting back what was there before, or nothing.
  def with_toplevel(name, value)
    had = Object.const_defined?(name, false) ? Object.send(:remove_const, name) : nil
    Object.const_set(name, value) unless value.nil?
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, had) if had
  end
end
