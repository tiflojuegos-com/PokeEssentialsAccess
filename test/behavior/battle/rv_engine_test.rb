# The engine Reborn and Rejuvenation share, read where it names things its own way: moves by symbol, pbHPChanged's
# list of pairs, the field and side effects, the bag's counts apart, the Pokedex's species rows and the PC's marks.
Harness.load_common("rv_common")

# The PC screen of that engine: the grab with Ctrl held (or Deselect) toggles the slot in the scene's multiselection
# instead of taking the Pokemon.
class PokemonStorageScreen
  def initialize(scene); @scene = scene; end

  def pbHold(selected, multimove = false)
    return :held unless multimove
    list = @scene.instance_variable_get(:@aMultiSelectedMons) || []
    @scene.instance_variable_set(:@aMultiSelectedMons, list.include?(selected) ? list - [selected] : list + [selected])
    nil
  end
end

PokeAccess::StorageRV.bind

class RvEngineTest < PokeAccessTest
  # A battle move as the engine builds it: no id, the symbol in move.
  class Move
    attr_reader :move, :name, :pp, :totalpp, :type, :category
    def initialize(move, name, category = :physical, pp = 35, total = 35)
      @move = move; @name = name; @category = category; @pp = pp; @totalpp = total; @type = :NORMAL
    end
  end

  # A party move (the engine's PBMove): the symbol and its pp, the name only through the data.
  class PartyMove
    attr_reader :move, :pp
    def initialize(move); @move = move; @pp = 10; end
    def type; :NORMAL; end
  end

  Battler = Struct.new(:moves, :name, :hp, :totalhp, :index)
  Effects = Struct.new(:effects)
  Field = Struct.new(:effect)
  FieldData = Struct.new(:name)

  # A battle of that engine: weather named after its move, trick room on the battle, the rest in ivars.
  class Battle
    attr_reader :field, :trickroom, :weather
    def initialize(field, state, sides, trickroom, weather)
      @field = field; @state = state; @sides = sides; @trickroom = trickroom; @weather = weather
    end
  end

  # Reborn's Pokedex: a row per species under dexList; its trainer keeps no seen or owned arrays any more.
  Pokedex = Struct.new(:dexList)
  DexTrainer = Struct.new(:pokedex, :seen, :owned)
  FormData = Struct.new(:Type1, :Type2)
  Wrapper = Struct.new(:forms)
  PkmnCache = Struct.new(:pkmn)

  # The species table as the game's MonDataHash answers it: [species] the wrapper with its forms by number,
  # [species, form] that form's data.
  class Mons
    def initialize(rows); @rows = rows; end
    def [](sp, form = nil)
      forms = @rows[sp]
      if form.nil?
        numbered = {}
        forms.each_with_index { |f, i| numbered[i] = f[0] }
        return Wrapper.new(numbered)
      end
      FormData.new(forms[form][1], forms[form][2])
    end
  end

  # The game's getTypeName over the types these species have.
  TYPE_NAMES = { :getTypeName => lambda { |t| { :GROUND => "Ground", :ICE => "Ice", :STEEL => "Steel" }[t].to_s } }

  # The Pokedex rows of four species: caught, seen, never seen, and caught in the Alolan form last seen.
  DEX_ROWS = { :PIKACHU => { :seen? => true, :owned? => true, :lastSeen => { :form => "Normal" } },
               :RAICHU => { :seen? => true, :owned? => false, :lastSeen => { :form => "Normal" } },
               :CLEFAIRY => { :seen? => false, :owned? => false, :lastSeen => { :form => "Normal" } },
               :SANDSHREW => { :seen? => true, :owned? => true, :lastSeen => { :form => "Alolan Form" } } }

  # What Sandshrew's Pokedex entry paints, as [text, painter, x, y].
  SANDSHREW_PAGE = [["027  Sandshrew", :positions, 244, 40], ["HT", :positions, 318, 158], ["WT", :positions, 318, 190],
                    ["Mouse Pokémon", :positions, 244, 74], ["0.7 m", :positions, 466, 158],
                    ["40.0 kg", :positions, 478, 190], ["It lives in snowy mountains.", :dtex, 42, 240]]

  test "takes a move's id from move where it has no id" do
    assert_equal :TACKLE, PokeAccess::MoveInfo.id_of(Move.new(:TACKLE, "Placaje"))
  end

  test "counts a symbol id as a move, and neither a gen-6 empty slot nor nothing" do
    { :TACKLE => true, 0 => false, nil => false }.each do |id, want|
      assert_equal want, PokeAccess::MoveInfo.real_id?(id), "for #{id.inspect}"
    end
  end

  test "numbers a category symbol as the other eras do" do
    { :physical => 0, :special => 1, :status => 2 }.each do |category, want|
      assert_equal want, PokeAccess::MoveInfo.category_of(Move.new(:EMBER, "Ascuas", category)), "for #{category}"
    end
  end

  test "the fight menu says the move with its type, category and pp" do
    disp = Object.new
    disp.instance_variable_set(:@battler, Battler.new([Move.new(:TACKLE, "Placaje")], "Pikachu", 20, 20, 0))
    disp.instance_variable_set(:@index, 0)
    PokeAccess::Battle.read_fight_move(disp)
    want = ["Placaje", t(:mv_type, :t => PBTypes.getName(:NORMAL)), t(:cat_physical), t(:mv_pp, :pp => 35, :tot => 35)]
    assert_equal [[want.join(". "), true]], SpeakCapture.log
  end

  test "names a summary move slot from its move symbol, and an empty one empty" do
    pk = Struct.new(:moves).new([PartyMove.new(:TACKLE), nil])
    assert_equal PBMoves.getName(:TACKLE), PokeAccess::Summary.move_slot_name(pk, 0), "the move"
    assert_equal t(:sm_empty_slot), PokeAccess::Summary.move_slot_name(pk, 1), "the empty slot"
  end

  test "lists each real move of the summary once, by name, pp and type" do
    rows = []
    PokeAccess::Summary.each_real_move(Struct.new(:moves).new([PartyMove.new(:TACKLE), nil])) { |*row| rows.push(row) }
    assert_equal [[PBMoves.getName(:TACKLE), 10, nil, PBTypes.getName(:NORMAL)]], rows
  end

  test "says each change of pbHPChanged's list of pairs, the foe's as the share of its bar" do
    mine = Battler.new([], "Pikachu", 12, 40, 0)
    foe = Battler.new([], "Rattata", 5, 20, 1)
    PokeAccess::Battle.hp_changed([[mine, 20], [foe, 20]], true)
    foe_line = t(:bt_hp_change_pct, :name => "Rattata", :verb => t(:bt_lose), :n => 75, :rest => t(:bt_hp_pct, :n => 25))
    assert_equal [[hp_line("Pikachu", 8, t(:bt_hp_exact, :hp => 12, :tot => 40)), false], [foe_line, false]],
                 SpeakCapture.log
  end

  test "skips an entry of pbHPChanged's list that is no pair" do
    mine = Battler.new([], "Pikachu", 12, 40, 0)
    PokeAccess::Battle.hp_changed([:junk, [mine, 20]], true)
    assert_equal [hp_line("Pikachu", 8, t(:bt_hp_exact, :hp => 12, :tot => 40))], SpeakCapture.lines
  end

  test "still says a change given as a battler and its old hp" do
    PokeAccess::Battle.hp_changed(Battler.new([], "Pikachu", 12, 40, 0), 30)
    assert_equal [hp_line("Pikachu", 18, t(:bt_hp_exact, :hp => 12, :tot => 40))], SpeakCapture.lines
  end

  test "names the field from the $cache field data, the plain indoor one as none" do
    with_rv_field do
      assert_equal "Electric Terrain", PokeAccess::Battle.field_effect_name(field_battle(:ELECTERRAIN)), "a field"
      assert_nil PokeAccess::Battle.field_effect_name(field_battle(:INDOOR)), "the plain indoor field"
    end
  end

  test "the field key says the field, the weather named after its move, the rooms, the terrain and each side" do
    state = Effects.new({ :ELECTERRAIN => 3, :GRASSY => 0, :MISTY => 0, :PSYTERRAIN => 0, :Gravity => -1 })
    sides = [Effects.new({ :Reflect => 4, :StealthRock => false }),
             Effects.new({ :Reflect => 0, :StealthRock => true })]
    with_rv_field do
      PokeAccess::Battle.set_battle(Battle.new(Field.new(:ELECTERRAIN), state, sides, 2, :RAINDANCE))
      PokeAccess::Battle.announce_field
    end
    want = [t(:bt_field_effect, :f => "Electric Terrain"), t(:bt_weather, :w => t(:w_rain)), t(:bt_trickroom),
            t(:bt_gravity), t(:bt_electric), t(:bt_side_effect, :effect => t(:bt_reflect), :side => t(:bt_side_yours)),
            t(:bt_side_effect, :effect => t(:bt_stealthrock), :side => t(:bt_side_foe))]
    assert_equal [[want.join(", "), true]], SpeakCapture.log
  end

  test "the field key says there is nothing in play on a quiet field" do
    with_rv_field do
      PokeAccess::Battle.set_battle(field_battle(:INDOOR))
      PokeAccess::Battle.announce_field
    end
    assert_equal [[t(:bt_no_field), true]], SpeakCapture.log
  end

  test "a bag row of bare ids takes its count from the contents table" do
    assert_equal "#{PBItems.getName(:POTION)}: 3, #{list_place(1, 3)}", PokeAccess::Menus.bag_row(bag_window, 0)
  end

  test "a bag row's witness changes as its count changes under a still cursor" do
    win = bag_window
    was = PokeAccess::Menus.bag_witness(win, 0)
    win.instance_variable_get(:@bag).contents[:POTION] = 2
    refute_equal was, PokeAccess::Menus.bag_witness(win, 0)
  end

  test "a bag row's witness changes as the row is marked to be moved" do
    win = bag_window
    was = PokeAccess::Menus.bag_witness(win, 0)
    win.instance_variable_set(:@sortIndex, 0)
    refute_equal was, PokeAccess::Menus.bag_witness(win, 0)
  end

  test "the bag's close row past the items has no witness" do
    win = bag_window
    def win.item; nil; end
    assert_nil PokeAccess::Menus.bag_witness(win, 2)
  end

  test "the Pokedex list takes seen and caught from the species rows" do
    with_rv_dex do
      win = Window_Pokedex.new([[:PIKACHU, "Pikachu", 4, 60, 25, false], [:RAICHU, "Raichu", 8, 300, 26, false],
                                [:CLEFAIRY, "Clefairy", 6, 75, 35, false]])
      { 0 => "25, Pikachu, #{t(:dex_caught)}", 1 => "26, Raichu, #{t(:dex_seen)}",
        2 => "35, #{t(:dex_unknown)}" }.each do |index, want|
        win.index = index
        assert_equal want, PokeAccess::Menus.focused_text(win), "row #{index}"
      end
    end
  end

  test "the Pokedex entry of a caught species says the mark beside its name and its last seen form's types" do
    with_rv_dex { PokeAccess::DexEntry.gen6_info(Object.new, SANDSHREW_PAGE, :SANDSHREW) }
    want = ["027 Sandshrew", t(:dex_caught), "Mouse Pokémon", t(:pdx_type, :t => "Ice Steel"), "HT", "0.7 m", "WT",
            "40.0 kg", "It lives in snowy mountains."]
    assert_equal [[want.join(", "), true]], SpeakCapture.log
  end

  test "the Pokedex entry of a species only seen says neither the mark nor the types" do
    rows = DEX_ROWS.merge(:SANDSHREW => DEX_ROWS[:SANDSHREW].merge(:owned? => false))
    with_rv_dex(rows) { PokeAccess::DexEntry.gen6_info(Object.new, SANDSHREW_PAGE, :SANDSHREW) }
    want = ["027 Sandshrew", "Mouse Pokémon", "HT", "0.7 m", "WT", "40.0 kg", "It lives in snowy mountains."]
    assert_equal [[want.join(", "), true]], SpeakCapture.log
  end

  test "the PC says a slot marked as the grab marks it" do
    pc_screen.pbHold([2, 5], true)
    assert_equal [[t(:rv_pc_marked), true]], SpeakCapture.log
  end

  test "the PC says a slot unmarked as the grab unmarks it" do
    screen = pc_screen
    screen.pbHold([2, 5], true)
    SpeakCapture.clear
    screen.pbHold([2, 5], true)
    assert_equal [[t(:rv_pc_unmarked), true]], SpeakCapture.log
  end

  test "a plain grab takes the Pokemon and says nothing of the selection" do
    assert_equal :held, pc_screen.pbHold([2, 5])
    assert_nothing_spoken
  end

  test "a marked slot's line ends with the mark, and only that slot's" do
    screen = pc_screen
    scene = screen.instance_variable_get(:@scene)
    pk = Poke.build(:name => "Pikachu", :level => 12)
    plain = [5, 6].map { |i| PokeAccess::Party.slot_line(scene, i, nil, pk, nil, "") }
    screen.pbHold([2, 5], true)
    marked = [5, 6].map { |i| PokeAccess::Party.slot_line(scene, i, nil, pk, nil, "") }
    assert_equal ["#{plain[0]}, #{t(:rv_pc_marked)}", plain[1]], marked
  end

  test "a slot marked in another box is not marked in this one" do
    screen = pc_screen
    scene = screen.instance_variable_get(:@scene)
    pk = Poke.build(:name => "Pikachu", :level => 12)
    plain = PokeAccess::Party.slot_line(scene, 5, nil, pk, nil, "")
    screen.pbHold([3, 5], true)
    assert_equal plain, PokeAccess::Party.slot_line(scene, 5, nil, pk, nil, "")
  end

  private

  # A battle on the given field with nothing else in play.
  def field_battle(effect)
    quiet = Effects.new({ :ELECTERRAIN => 0, :GRASSY => 0, :MISTY => 0, :PSYTERRAIN => 0, :Gravity => 0 })
    Battle.new(Field.new(effect), quiet, [Effects.new({}), Effects.new({})], 0, 0)
  end

  # Runs the block in that engine's battle world: its $cache names the Electric Terrain field, and there is no
  # PBEffects (its effects are keyed by symbol); both put back after.
  def with_rv_field
    had = $cache
    $cache = Struct.new(:FEData).new({ :ELECTERRAIN => FieldData.new("Electric Terrain") })
    hidden = Object.send(:remove_const, :PBEffects)
    yield
  ensure
    Object.const_set(:PBEffects, hidden) if hidden
    $cache = had
  end

  # Runs the block with the engine's data provider over a Pokedex of rows, Sandshrew's forms in the species table and
  # the game's type names; the player, the $cache and the provider put back after.
  def with_rv_dex(rows = DEX_ROWS)
    had_trainer = $Trainer
    had_cache = $cache
    $Trainer = DexTrainer.new(Pokedex.new(rows), nil, nil)
    $cache = PkmnCache.new(Mons.new(:SANDSHREW => [["Normal", :GROUND, nil], ["Alolan Form", :ICE, :STEEL]]))
    GameFunctions.with(TYPE_NAMES) { Harness.with_provider(PokeAccess::DataRV) { yield } }
  ensure
    $Trainer = had_trainer
    $cache = had_cache
  end

  # The bag on its second pocket, two bare ids with their counts apart, the cursor on the Potion (three of them).
  def bag_window
    win = Object.new
    bag = Struct.new(:pockets, :contents).new([[], [:POTION, :REPEL]], { :POTION => 3, :REPEL => 1 })
    win.instance_variable_set(:@bag, bag)
    def win.pocket; 1; end
    def win.itemCount; 3; end
    def win.item; :POTION; end
    win
  end

  # The PC on box 2, its multiselection empty.
  def pc_screen
    scene = PokemonStorageScene.new
    scene.instance_variable_set(:@storage, Struct.new(:currentBox).new(2))
    PokemonStorageScreen.new(scene)
  end

  # A loss of n hit points, as the hit points line says it with what is left.
  def hp_line(name, n, rest)
    t(:bt_hp_change, :name => name, :verb => t(:bt_lose), :n => n, :rest => rest)
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
