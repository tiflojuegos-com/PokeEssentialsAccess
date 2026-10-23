# The gen-6 data provider (DataG6) as PokeAccess::Data serves it on a gen-6 engine: each datum from the PB* table,
# PBMoveData, dex data or message table the engine keeps it in; and the core submodules the toolkit boots with.
class ProviderGen6Test < PokeAccessTest
  LAYER = PokeAccess::Data
  G6 = PokeAccess::DataG6

  CORE = %w[Config Hooks Keys Info Menus Battle Party Summary Locator Pathfinder Sound ConfigMenu Settings Surfaces
            Pokedex Tags Appearance Data].freeze

  # The texts of the game's message tables, by table and id.
  TEXTS = { [:MoveDescriptions, 7] => "Un placaje con todo el cuerpo.",
            [:ItemDescriptions, 25] => "Ahuyenta a los Pokemon salvajes debiles.",
            [:AbilityDescs, 4] => "Puede paralizar al contacto.", [:Kinds, 3] => "Pokemon Raton",
            [:Entries, 3] => "Almacena electricidad en las mejillas." }.freeze

  # Gen-6's getID: a symbol or string names a constant of mod, 0 when it has none; anything else is the id itself.
  GEN6_GET_ID = lambda do |mod, constant|
    return nil if !mod || !constant || constant == ""
    return constant unless constant.is_a?(Symbol) || constant.is_a?(String)
    (mod.const_defined?(constant.to_sym) rescue false) ? mod.const_get(constant.to_sym) : 0
  end

  # Gen-6's PBTrainers.getName, which indexes its message table by number.
  TRAINER_NAMES = lambda do |id|
    raise TypeError, "no implicit conversion of #{id.class} into Integer" unless id.is_a?(Integer)
    { 5 => "Montanero", 65 => "Posadera" }[id]
  end

  # The engine's dex data file, noting whether it was closed and unreadable when broken.
  class DexFile < FakeDexData
    def initialize(broken); super(); @broken = broken; @closed = false; end
    def fgetb; raise IOError, "the dex data cannot be read" if @broken; super; end
    def close; @closed = true; end
    def closed?; @closed; end
  end

  test "serves on a gen-6 engine, above the fallback" do
    assert_equal [G6, 10], [LAYER.active, LAYER.active_priority]
  end

  test "names moves, types, items, species, abilities, natures, stats and trainer classes through their PB* tables" do
    { [:move_name, 7] => "Mov7", [:type_name, 2] => "Tipo2", [:item_name, 25] => "Repel",
      [:species_name, 3] => "Especie3", [:ability_name, 4] => "Habilidad4", [:nature_name, 1] => "Naturaleza1",
      [:stat_name, 4] => "Estadistica4", [:trainer_type_name, 65] => "Posadera" }.each do |(method, id), want|
      assert_equal want, LAYER.send(method, id), "#{method}(#{id})"
    end
  end

  test "reads a move's power, accuracy, pp, type and category from its PBMoveData" do
    { :move_power => 47, :move_accuracy => 100, :move_total_pp => 15, :move_type_name => "Tipo2",
      :move_category => 1 }.each do |method, want|
      assert_equal want, LAYER.send(method, 7), "#{method}(7)"
    end
  end

  test "reads descriptions and a species' category and dex entry from the game's message tables" do
    with_messages do
      { [:move_description, 7] => TEXTS[[:MoveDescriptions, 7]], [:item_description, 25] => TEXTS[[:ItemDescriptions, 25]],
        [:ability_description, 4] => TEXTS[[:AbilityDescs, 4]],
        [:species_entry, 3] => ["Especie3", TEXTS[[:Kinds, 3]], TEXTS[[:Entries, 3]]] }.each do |(method, id), want|
        assert_equal want, LAYER.send(method, id), "#{method}(#{id})"
      end
    end
  end

  test "a species entry whose message tables fail keeps its name" do
    GameFunctions.with(:pbGetMessage => lambda { |_type, _id| raise IndexError, "no such message" }) do
      assert_equal ["Especie3", nil, nil], G6.species_entry(3)
    end
  end

  test "names an item's plural through PBItems.getNamePlural" do
    with_singleton(PBItems, :getNamePlural, lambda { |id| id == 25 ? "Repelentes" : "" }) do
      assert_equal "Repelentes", LAYER.item_name_plural(25)
    end
  end

  test "words a status by the mod's status table, where a game may put its own literal" do
    assert_equal [:st_sleep, :st_freeze], [LAYER.status_name(1), LAYER.status_name(5)], "the keys of the mod's words"
    assert_nil LAYER.status_name(9), "a status the table lacks"
    with_status_names(1 => "Dormido (ZZZ)") { assert_equal "Dormido (ZZZ)", LAYER.status_name(1), "a game's own" }
  end

  test "names a pokemon's types, the second only when it differs from the first" do
    pokemon = Struct.new(:type1, :type2)
    { [1, 2] => ["Tipo1", "Tipo2"], [13, 13] => ["Tipo13"] }.each do |(first, second), want|
      assert_equal want, LAYER.pokemon_types(pokemon.new(first, second)), "types #{first} and #{second}"
    end
  end

  test "names a species' types as its dex data keeps them, once when both are the same" do
    assert_equal [["Tipo1", "Tipo2"], ["Tipo13"]], [LAYER.species_types(4), LAYER.species_types(25)]
  end

  test "closes the dex data after reading a species' types, also when the read fails" do
    read = DexFile.new(false)
    with_dex(read) { G6.species_types(4) }
    assert read.closed?, "after reading"
    broken = DexFile.new(true)
    assert_raises(IOError) { with_dex(broken) { G6.species_types(4) } }
    assert broken.closed?, "after a failed read"
  end

  test "names a trainer class by its number or its constant's name, and nothing for one the game lacks" do
    with_singleton(PBTrainers, :getName, TRAINER_NAMES) do
      with_consts(PBTrainers, :SPRITE_FOLDER => "Graphics/Trainers/") do
        { 65 => "Posadera", "HIKER" => "Montanero", :HIKER => "Montanero" }.each do |id, want|
          assert_equal want, G6.trainer_type_name(id), "for #{id.inspect}"
        end
        ["AQUAGRUNT_M", "hiker", "HIKER-2", "SPRITE_FOLDER"].each do |id|
          assert_nil G6.trainer_type_name(id), "for #{id.inspect}"
        end
      end
    end
  end

  test "turns an item name from an event script into its number and name, through PBItems or the game's getID" do
    GameFunctions.with(:getID => GEN6_GET_ID) do
      { "REPEL" => [25, "Repel"], :POTION => [1, "Pocion"], "NOTANITEM" => [0, PBItems.getName(0)],
        nil => [nil, nil] }.each do |sym, want|
        assert_equal want, LAYER.item_id(sym), "for #{sym.inspect}"
      end
    end
  end

  test "turns a move symbol into its number, through its PBMoves constant or the game's getID" do
    with_consts(PBMoves, :THUNDERSHOCK => 84) do
      GameFunctions.with(:getID => GEN6_GET_ID) do
        { :THUNDERSHOCK => 84, "THUNDERSHOCK" => 84, 84 => 84, :NOTAMOVE => 0 }.each do |sym, want|
          assert_equal want, LAYER.move_id(sym), "for #{sym.inspect}"
        end
      end
    end
  end

  test "boots the toolkit with its core submodules defined" do
    assert_equal [], CORE.reject { |m| PokeAccess.const_defined?(m) }
  end

  private

  # Runs the block with the three description tables in MessageTypes and pbGetMessage answering TEXTS, "" for any
  # other message; both are put back after.
  def with_messages
    with_consts(MessageTypes, :MoveDescriptions => 6, :ItemDescriptions => 9, :AbilityDescs => 11) do
      texts = Hash[TEXTS.map { |(table, id), text| [[MessageTypes.const_get(table), id], text] }]
      GameFunctions.with(:pbGetMessage => lambda { |type, id| texts.fetch([type, id], "") }) { yield }
    end
  end

  # Runs the block with pbOpenDexData opening dex.
  def with_dex(dex)
    GameFunctions.with(:pbOpenDexData => lambda { dex }) { yield }
  end

  # Runs the block with the mod's status table changed as changes says, the table put back after.
  def with_status_names(changes)
    was = PokeAccess::Config.status_names
    PokeAccess::Config.status_names = was.merge(changes)
    yield
  ensure
    PokeAccess::Config.status_names = was
  end

  # Runs the block with each name => value a constant of mod, putting back what each was before, or nothing.
  def with_consts(mod, pairs)
    saved = {}
    pairs.each do |name, value|
      saved[name] = mod.send(:remove_const, name) if mod.const_defined?(name, false)
      mod.const_set(name, value)
    end
    yield
  ensure
    pairs.each_key do |name|
      mod.send(:remove_const, name) if mod.const_defined?(name, false)
      mod.const_set(name, saved[name]) if saved.key?(name)
    end
  end

  # Runs the block with obj answering name as body does, putting back what it answered before, or nothing.
  def with_singleton(obj, name, body)
    had = obj.singleton_methods.include?(name) ? obj.method(name) : nil
    obj.define_singleton_method(name, &body)
    yield
  ensure
    had ? obj.define_singleton_method(name, had) : obj.singleton_class.send(:remove_method, name)
  end
end
