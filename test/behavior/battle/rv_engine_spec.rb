# What core reads the same way in Reborn and Rejuvenation, whose shared engine names things its own way: moves
# carry their id as move (a symbol) and their category as a symbol, pbHPChanged takes a list of pairs, the battle
# keeps its field in field.effect, its terrains and rooms in @state and its side effects under symbol keys, the
# bag keeps bare ids in its pockets with the counts apart, the Pokedex keeps a row per species (Reborn, Desolation)
# and the PC a multiselection of marked slots.
Harness.load_common("rv_common")
module RVEngineSpec
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
  PkmnCache = Struct.new(:pkmn)
end

Suite.define("rv engine: a move whose id is called move is read, named and numbered") do
  m = RVEngineSpec::Move.new(:TACKLE, "Placaje")
  eq "the id comes from move where there is no id", PokeAccess::MoveInfo.id_of(m), :TACKLE
  truthy "a symbol id names a move", PokeAccess::MoveInfo.real_id?(:TACKLE)
  falsy "a gen-6 empty slot does not", PokeAccess::MoveInfo.real_id?(0)
  falsy "and nothing does not", PokeAccess::MoveInfo.real_id?(nil)
  eq "a category symbol is numbered like the other eras", PokeAccess::MoveInfo.category_of(RVEngineSpec::Move.new(:EMBER, "Ascuas", :special)), 1

  disp = Object.new
  disp.instance_variable_set(:@battler, RVEngineSpec::Battler.new([m], "Pikachu", 20, 20, 0))
  disp.instance_variable_set(:@index, 0)
  SpeakCapture.clear
  PokeAccess::Battle.read_fight_move(disp)
  spoke "the fight menu says the move instead of staying silent", /Placaje/
  spoke "with its pp", /35/
end

Suite.define("rv engine: the summary's moves are read from the move symbol") do
  pk = Struct.new(:moves).new([RVEngineSpec::PartyMove.new(:TACKLE), nil])
  nm = PokeAccess::Summary.move_slot_name(pk, 0)
  truthy "a move slot is named, not called empty (#{nm})", nm && nm != PokeAccess::I18n.t(:sm_empty_slot)
  eq "an empty slot is empty", PokeAccess::Summary.move_slot_name(pk, 1), PokeAccess::I18n.t(:sm_empty_slot)
  rows = []
  PokeAccess::Summary.each_real_move(pk) { |name, pp, _tot, _ty| rows.push([name, pp]) }
  eq "the real moves are listed once each", rows.length, 1
end

Suite.define("rv engine: pbHPChanged's list of pairs says each change") do
  mine = RVEngineSpec::Battler.new([], "Pikachu", 12, 40, 0)
  foe = RVEngineSpec::Battler.new([], "Rattata", 5, 20, 1)
  SpeakCapture.clear
  PokeAccess::Battle.hp_changed([[mine, 20], [foe, 20]], true)
  spoke "the player's battler", /Pikachu/
  spoke "and the foe", /Rattata/
  SpeakCapture.clear
  PokeAccess::Battle.hp_changed(mine, 30)
  spoke "the (battler, old hp) shape still reads", /Pikachu/
end

Suite.define("rv engine: the field key names the field, the weather, terrains, rooms and side effects") do
  had = $cache
  $cache = Struct.new(:FEData).new({ :ELECTERRAIN => RVEngineSpec::FieldData.new("Electric Terrain") })
  hidden = Object.send(:remove_const, :PBEffects)
  begin
    state = RVEngineSpec::Effects.new({ :ELECTERRAIN => 3, :GRASSY => 0, :MISTY => 0, :PSYTERRAIN => 0, :Gravity => -1 })
    sides = [RVEngineSpec::Effects.new({ :Reflect => 4, :StealthRock => false }),
             RVEngineSpec::Effects.new({ :Reflect => 0, :StealthRock => true })]
    b = RVEngineSpec::Battle.new(RVEngineSpec::Field.new(:ELECTERRAIN), state, sides, 2, :RAINDANCE)
    eq "the field by its $cache name", PokeAccess::Battle.field_effect_name(b), "Electric Terrain"
    eq "the plain indoor field is no field", PokeAccess::Battle.field_effect_name(RVEngineSpec::Battle.new(RVEngineSpec::Field.new(:INDOOR), state, sides, 0, 0)), nil
    PokeAccess::Battle.set_battle(b)
    SpeakCapture.clear
    PokeAccess::Battle.announce_field
    line = SpeakCapture.lines.last.to_s
    t = PokeAccess::I18n
    truthy "the field (#{line})", line.include?(t.t(:bt_field_effect, :f => "Electric Terrain"))
    truthy "the weather named after its move", line.include?(t.t(:bt_weather, :w => t.t(:w_rain)))
    truthy "trick room from the battle", line.include?(t.t(:bt_trickroom))
    truthy "permanent gravity", line.include?(t.t(:bt_gravity))
    truthy "the terrain counter", line.include?(t.t(:bt_electric))
    truthy "a screen on the player's side", line.include?(t.t(:bt_side_effect, :effect => t.t(:bt_reflect), :side => t.t(:bt_side_yours)))
    truthy "a hazard on the foe's", line.include?(t.t(:bt_side_effect, :effect => t.t(:bt_stealthrock), :side => t.t(:bt_side_foe)))
  ensure
    Object.const_set(:PBEffects, hidden)
    $cache = had
    PokeAccess::Battle.clear_battle
  end
end

Suite.define("rv engine: a bag row takes its count from the contents table") do
  bag = Struct.new(:pockets, :contents).new([[], [:POTION, :REPEL]], { :POTION => 3, :REPEL => 1 })
  win = Object.new
  win.instance_variable_set(:@bag, bag)
  def win.pocket; 1; end
  def win.itemCount; 3; end
  def win.item; :POTION; end
  row = PokeAccess::Menus.bag_row(win, 0)
  truthy "the count is the item's (#{row})", row =~ /: 3\b/
  falsy "not a letter of the symbol", row =~ /: O\b/
  wit = PokeAccess::Menus.bag_witness(win, 0)
  truthy "a row of bare ids has a change witness too", wit
  bag.contents[:POTION] = 2
  falsy "so using one under a still cursor reads the row again", PokeAccess::Menus.bag_witness(win, 0) == wit
  bag.contents[:POTION] = 3
  win.instance_variable_set(:@sortIndex, 0)
  falsy "and so does marking it to be moved", PokeAccess::Menus.bag_witness(win, 0) == wit
  def win.item; nil; end
  eq "the close row past the items has none", PokeAccess::Menus.bag_witness(win, 2), nil
end

Suite.define("rv engine: the Pokedex list and entry take seen and caught from its species rows") do
  had_trainer = $Trainer
  had_cache = $cache
  rv = (class << PokeAccess::DataRV; self; end)
  rv.send(:alias_method, :rv_spec_type_name, :type_name)
  begin
    rv.send(:define_method, :type_name) { |ty| ty.to_s.capitalize }
    Harness.with_provider(PokeAccess::DataRV) do
      rows = { :PIKACHU => { :seen? => true, :owned? => true, :lastSeen => { :form => "Normal" } },
               :RAICHU => { :seen? => true, :owned? => false, :lastSeen => { :form => "Normal" } },
               :CLEFAIRY => { :seen? => false, :owned? => false, :lastSeen => { :form => "Normal" } },
               :SANDSHREW => { :seen? => true, :owned? => true, :lastSeen => { :form => "Alolan Form" } } }
      $Trainer = RVEngineSpec::DexTrainer.new(RVEngineSpec::Pokedex.new(rows), nil, nil)
      $cache = RVEngineSpec::PkmnCache.new(RVEngineSpec::Mons.new(:SANDSHREW => [["Normal", :GROUND, nil],
                                                                                  ["Alolan Form", :ICE, :STEEL]]))
      t = PokeAccess::I18n
      win = Window_Pokedex.new([[:PIKACHU, "Pikachu", 4, 60, 25, false], [:RAICHU, "Raichu", 8, 300, 26, false],
                                [:CLEFAIRY, "Clefairy", 6, 75, 35, false]])
      caught = PokeAccess::Menus.focused_text(win)
      truthy "a caught species is named (#{caught})", caught.include?("Pikachu")
      truthy "and said caught", caught.include?(t.t(:dex_caught))
      win.index = 1
      seen = PokeAccess::Menus.focused_text(win)
      truthy "a species only seen is named and said seen (#{seen})", seen.include?("Raichu") && seen.include?(t.t(:dex_seen))
      win.index = 2
      eq "one never seen is its number and unknown", PokeAccess::Menus.focused_text(win), "35, #{t.t(:dex_unknown)}"

      painted = [["027  Sandshrew", :positions, 244, 40], ["HT", :positions, 318, 158], ["WT", :positions, 318, 190],
                 ["Mouse Pokémon", :positions, 244, 74], ["0.7 m", :positions, 466, 158],
                 ["40.0 kg", :positions, 478, 190], ["It lives in snowy mountains.", :dtex, 42, 240]]
      SpeakCapture.clear
      PokeAccess::DexEntry.gen6_info(Object.new, painted, :SANDSHREW)
      got = SpeakCapture.lines.join(" ")
      truthy "the entry of a caught species says the mark painted beside its name (#{got})",
             got.include?("027 Sandshrew, #{t.t(:dex_caught)}")
      truthy "and the types of the form last seen, drawn as icons",
             got.include?(t.t(:pdx_type, :t => "Ice Steel"))
    end
  ensure
    rv.send(:alias_method, :type_name, :rv_spec_type_name)
    rv.send(:remove_method, :rv_spec_type_name)
    $Trainer = had_trainer
    $cache = had_cache
  end
end

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

Suite.define("rv engine: the PC's multiselection is said as a slot is marked or unmarked, and on the marked slot") do
  PokeAccess::StorageRV.bind
  t = PokeAccess::I18n
  scene = PokemonStorageScene.new
  scene.instance_variable_set(:@storage, Struct.new(:currentBox).new(2))
  screen = PokemonStorageScreen.new(scene)
  SpeakCapture.clear
  screen.pbHold([2, 5], true)
  eq "marking a slot says so", SpeakCapture.lines, [t.t(:rv_pc_marked)]
  pk = Poke.build(:name => "Pikachu", :level => 12)
  line = PokeAccess::Party.slot_line(scene, 5, nil, pk, nil, "")
  truthy "the marked slot's line says it (#{line})", line.end_with?(", #{t.t(:rv_pc_marked)}")
  falsy "another slot's does not", PokeAccess::Party.slot_line(scene, 6, nil, pk, nil, "").include?(t.t(:rv_pc_marked))
  SpeakCapture.clear
  screen.pbHold([2, 5], true)
  eq "unmarking it says so", SpeakCapture.lines, [t.t(:rv_pc_unmarked)]
  SpeakCapture.clear
  eq "a plain grab takes the Pokemon as it would", screen.pbHold([2, 5]), :held
  silent "and says nothing of the selection"
end
