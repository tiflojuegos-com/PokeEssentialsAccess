# The DBK Move Info panel's line beyond its figures: the bonus row pbGetFinalModifiers adds under them, caught from the
# same draw call, the move-property icons pbDrawMoveFlagIcons draws, named in its order, how the move lands on each
# foe as pbDrawTypeEffectiveness paints it, and the whole line as the panel reads it; and the battler panel's star.
class DbkMoveinfoFlagsTest < PokeAccessTest
  T = PokeAccess::I18n
  MoveInfo = PokeAccess::DBKMoveInfo
  Move = Struct.new(:name, :flags, :target, :category, :power, :accuracy, :priority, :function_code, :type)

  # A battler with a move list, as the fight menu's cursor reaches it; dynamax? only when asked for.
  Fighter = Struct.new(:moves, :index, :dynamaxed) do
    def dynamax?; dynamaxed; end
  end

  # A battler as the effectiveness strip reads it: name, slot, types, and whether it fainted, terastallized or is a
  # celestial whose effectiveness the panel withholds.
  Target = Struct.new(:name, :index, :types, :fainted, :tera, :celestial) do
    def pbTypes(_withtype = false); types; end
    def fainted?; fainted ? true : false; end
    def tera?; tera ? true : false; end
    def celestial?; celestial ? true : false; end
  end

  test "says the left-aligned row painted after the figures as the bonus, its stops dropped" do
    with_capture do
      MoveInfo.note_draw(figures + [["Poder potenciado por Torrente...", 8, 226, :left], ["Otra fila", 8, 250, :left]])
      assert_equal "Poder potenciado por Torrente", MoveInfo.bonus
    end
  end

  test "has no bonus when no row follows the figures, or the row is only a stop" do
    with_capture do
      MoveInfo.note_draw(figures)
      assert_nil MoveInfo.bonus, "the labels before the last figure are no bonus"
      MoveInfo.note_draw(figures + [[".", 8, 226, :left]])
      assert_nil MoveInfo.bonus, "a stop alone"
    end
  end

  test "forgets the bonus on a repaint without one" do
    with_capture do
      MoveInfo.note_draw(figures + [["Poder potenciado por Torrente.", 8, 226, :left]])
      MoveInfo.note_draw(figures)
      assert_nil MoveInfo.bonus
    end
  end

  test "keeps the bonus through a draw that is not the panel's, until the next opening" do
    with_capture do
      MoveInfo.note_draw(figures + [["Precisión reducida por Arena Profunda.", 8, 226, :left]])
      MoveInfo.note_draw([["algo", 0, 0, :left]])
      assert_equal "Precisión reducida por Arena Profunda", MoveInfo.bonus, "another draw"
      MoveInfo.capture_on
      assert_nil MoveInfo.bonus, "the next opening"
    end
  end

  test "names the property icons in the move's order" do
    punch = Move.new("Puño Fuego", ["Contact", "CanProtect", "CanMirrorMove", "Punching"], :NearOther, 0)
    assert_equal [T.t(:dbkf_contact), T.t(:dbkf_punch)], MoveInfo.flag_words(punch)
  end

  test "names a flag family by its icon and skips a flag with none" do
    words = { "ZMove_ELECTRIC" => [T.t(:dbkf_zmove)], "DynamaxMove_FIRE" => [T.t(:dbkf_dynamax)],
              "GmaxMove" => [T.t(:dbkf_dynamax)], "HighCriticalHitRate_1" => [T.t(:dbkf_crit)], "Unknown" => [] }
    words.each do |flag, said|
      assert_equal said, MoveInfo.flag_words(Move.new("Z", [flag], :NearOther, 1)), flag
    end
  end

  test "names at most nine icons, as the panel's row holds" do
    many = Move.new("X", %w[Contact Sound Wind Punching Biting Bomb Pulse Powder Dance Slicing], :NearOther, 0)
    assert_equal %w[contact sound wind punch bite bomb pulse powder dance].map { |k| T.t(:"dbkf_#{k}") },
                 MoveInfo.flag_words(many)
  end

  test "names nothing for a move with no properties" do
    [[], nil].each do |flags|
      assert_equal [], MoveInfo.flag_words(Move.new("Y", flags, :User, 2)), "flags #{flags.inspect}"
    end
  end

  test "adds the no-protect and no-mirror icons to a move aimed at a foe only for the flag it lacks" do
    contact = T.t(:dbkf_contact)
    cases = { ["Contact"] => [contact, T.t(:dbkf_noprotect), T.t(:dbkf_nomirror)],
              ["Contact", "CanProtect"] => [contact, T.t(:dbkf_nomirror)],
              ["Contact", "CanMirrorMove"] => [contact, T.t(:dbkf_noprotect)],
              ["Contact", "CanProtect", "CanMirrorMove"] => [contact] }
    with_foe_targets([:NearOther]) do
      cases.each do |flags, said|
        assert_equal said, MoveInfo.flag_words(Move.new("Puño", flags, :NearOther, 0)), "flags #{flags.inspect}"
      end
      assert_equal [], MoveInfo.flag_words(Move.new("Danza Espada", [], :User, 2)), "aimed at the user"
    end
  end

  test "reads the panel's line: name, category, figures, bonus, then the properties" do
    with_capture do
      MoveInfo.note_draw(figures("90", "10%") + [["Poder potenciado por Puño Férreo.", 8, 226, :left]])
      assert_equal ["Puño Fuego", T.t(:cat_physical), T.t(:mv_power, :p => "90"), T.t(:mv_acc, :a => "100"),
                    T.t(:mv_effect, :n => "10%"), "Poder potenciado por Puño Férreo", props],
                   MoveInfo.parts(Fighter.new([fire_punch], 0), 0)
    end
  end

  test "names the type the window works out for the move, not the one it stores" do
    weather_ball = Move.new("Meteorobola", [], :NearOther, 1, 50, 100, 0, "TypeDependsOnWeather", :NORMAL)
    def weather_ball.pbCalcType(_battler); :FIRE; end
    line = with_type_names { with_capture { MoveInfo.parts(Fighter.new([weather_ball], 0), 0) } }
    assert_equal ["Meteorobola", T.t(:mv_type, :t => "Fuego"), T.t(:cat_special), T.t(:mv_power, :p => "50"),
                  T.t(:mv_acc, :a => 100)], line
  end

  test "has the properties from medium, while the bonus the panel writes out stays" do
    with_capture do
      MoveInfo.note_draw(figures("90", "---") + [["Poder potenciado por Puño Férreo.", 8, 226, :left]])
      line = ["Puño Fuego", T.t(:cat_physical), T.t(:mv_power, :p => "90"), T.t(:mv_acc, :a => "100"),
              "Poder potenciado por Puño Férreo"]
      assert_equal [line, line + [props], line + [props]], vb_levels { MoveInfo.parts(Fighter.new([fire_punch], 0), 0) }
    end
  end

  test "has no line for an empty slot" do
    with_capture { assert_nil MoveInfo.parts(Fighter.new([fire_punch], 0), 1) }
  end

  test "reads a staged Z-move or Max Move, or a dynamaxed battler's, in that form" do
    with_capture do
      cw = Struct.new(:mode)
      staged = { "Gigavoltio Destructor" => [false, :zmove, cw.new(2)], "Maxitormenta" => [false, :dynamax, cw.new(2)],
                 "Maxiataque" => [true, nil, nil], "Rayo" => [false, :zmove, cw.new(1)] }
      staged.each do |name, (dynamaxed, special, menu)|
        battler = Fighter.new([convertible], 0, dynamaxed)
        assert_equal name, MoveInfo.parts(battler, 0, special, menu).first,
                     "#{special.inspect}, mode #{menu && menu.mode}"
      end
    end
  end

  test "ends the line with how the move lands on the one foe" do
    words = { :GRASS => :mv_eff_super, :WATER => :mv_eff_weak, :NORMAL => :mv_eff_neutral, :FLASH => :mv_eff_none }
    words.each do |type, key|
      foe = facing(Target.new("Hoja", 1, [type]))
      line = with_capture { with_effectiveness { MoveInfo.parts(puncher, 0, nil, nil, foe) } }
      assert_equal T.t(key), line.last, "against #{type}"
    end
  end

  test "names each foe the move lands on, leaving out the player's side and the fainted" do
    foes = facing(Target.new("Propio", 0, [:GRASS]), Target.new("Hoja", 1, [:GRASS]), nil,
                  Target.new("Agua", 3, [:WATER]), Target.new("Caido", 5, [:GRASS], true))
    line = with_capture { with_effectiveness { MoveInfo.parts(puncher, 0, nil, nil, foes) } }
    assert_equal [T.t(:mv_eff_vs, :name => "Hoja", :eff => T.t(:mv_eff_super)),
                  T.t(:mv_eff_vs, :name => "Agua", :eff => T.t(:mv_eff_weak))].join(", "), line.last
  end

  test "has no effectiveness when no foe stands" do
    field = facing(Target.new("Propio", 0, [:GRASS]), nil, Target.new("Caido", 1, [:GRASS], true))
    line = with_capture { with_effectiveness { MoveInfo.parts(puncher, 0, nil, nil, field) } }
    assert_equal ["Puño Fuego", T.t(:cat_physical), T.t(:mv_power, :p => "75"), T.t(:mv_acc, :a => 100)], line
  end

  test "says a foe the panel withholds as unknown" do
    assert_equal T.t(:mv_eff_unknown), effectiveness_on(Target.new("Cosmico", 1, [:GRASS], false, false, true))
  end

  test "says a Stellar move lands super effectively on a Tera foe, whatever its types" do
    stellar = Move.new("Teraclusion", [], :NearOther, 1, 120, 100, 0, "TerapagosCategoryDependsOnHigherDamage")
    stellar.type = :STELLAR
    tera = facing(Target.new("Tera", 1, [:WATER], false, true))
    line = with_capture { with_effectiveness { MoveInfo.parts(Fighter.new([stellar], 0), 0, nil, nil, tera) } }
    assert_equal T.t(:mv_eff_super), line.last
  end

  test "withholds how the move lands on a species the player has neither battled nor owned" do
    cases = { [0, false] => T.t(:mv_eff_unknown), [1, false] => T.t(:mv_eff_super), [0, true] => T.t(:mv_eff_super) }
    cases.each do |(battled, owned), said|
      line = with_setting(:SHOW_TYPE_EFFECTIVENESS_FOR_NEW_SPECIES, false) do
        with_pokedex(battled, owned) { effectiveness_on(new_species) }
      end
      assert_equal said, line, "battled #{battled} times, owned: #{owned}"
    end
  end

  test "says how the move lands on a new species when the game's setting reveals it" do
    line = with_setting(:SHOW_TYPE_EFFECTIVENESS_FOR_NEW_SPECIES, true) do
      with_pokedex(0, false) { effectiveness_on(new_species) }
    end
    assert_equal T.t(:mv_eff_super), line
  end

  test "has no effectiveness for a status move" do
    status = Fighter.new([Move.new("Danza Espada", [], :User, 2, 0, 0, 0, "RaiseUserAttack2", :NORMAL)], 0)
    foe = facing(Target.new("Hoja", 1, [:GRASS]))
    line = with_capture { with_effectiveness { MoveInfo.parts(status, 0, nil, nil, foe) } }
    assert_equal ["Danza Espada", T.t(:cat_status), T.t(:mv_acc, :a => T.t(:mv_acc_perfect))], line
  end

  test "says one star for every shiny on the plugin's battler panel" do
    super_shiny = Object.new
    def super_shiny.super_shiny?; true; end
    assert_equal T.t(:dbk_shiny), PokeAccess::DBKBattlerInfo.shiny_word(super_shiny)
  end

  private

  # The panel's figure rows as Spanish Anil paints them, power and effect chance given.
  def figures(power = "117", effect = "---")
    [["Surf", 10, 12, :left], ["Poder:", 256, 40, :left], [power, 309, 40, :center], ["Precisión:", 348, 40, :left],
     ["100", 401, 40, :center], ["Prioridad:", 442, 40, :left], ["---", 484, 40, :center], ["Efecto:", 428, 12, :left],
     [effect, 484, 12, :center]]
  end

  # Fire Punch with its two property flags, as the fight menu's battler holds it.
  def fire_punch
    Move.new("Puño Fuego", ["Contact", "Punching"], :NearOther, 0, 75, 100, 0, "BurnTarget", :FIRE)
  end

  # The properties phrase for Fire Punch.
  def props
    T.t(:dbk_flags, :list => [T.t(:dbkf_contact), T.t(:dbkf_punch)].join(", "))
  end

  # Thunderbolt, which turns into its Z-move or Max Move when asked (the copy the panel reads keeps both answers).
  def convertible
    move = Move.new("Rayo", [], :NearOther, 1, 90, 100, 0, "ParalyzeTarget", :ELECTRIC)
    def move.convert_zmove(_battler, _battle, _idx, _flag)
      Move.new("Gigavoltio Destructor", [], :NearOther, 1, 175, 0)
    end
    def move.convert_dynamax_move(battler, _battle, _idx)
      Move.new(battler.dynamax? ? "Maxiataque" : "Maxitormenta", [], :NearOther, 1, 130, 0)
    end
    move
  end

  # A battler whose one move is a fire punch with no properties.
  def puncher
    Fighter.new([Move.new("Puño Fuego", [], :NearOther, 0, 75, 100, 0, "BurnTarget", :FIRE)], 0)
  end

  # A grass foe whose species, Oddish, the panel may not have met.
  def new_species
    foe = Target.new("Hoja", 1, [:GRASS])
    def foe.displayPokemon; Struct.new(:species).new(:ODDISH); end
    foe
  end

  # How the fire punch lands on foe alone: the last phrase of the panel's line against it.
  def effectiveness_on(foe)
    with_capture { with_effectiveness { MoveInfo.parts(puncher, 0, nil, nil, facing(foe)) } }.last
  end

  # A scene whose battle has the given battlers, in slot order.
  def facing(*battlers)
    scene = Object.new
    scene.instance_variable_set(:@battle, Struct.new(:allBattlers).new(battlers))
    scene
  end

  # Runs the block with the engine's Effectiveness answering by the foe's first type (2 super effective, 0.5 not very,
  # 1 neutral, 0 none), as v21's module does, then takes it away again.
  def with_effectiveness
    table = { :GRASS => 2.0, :WATER => 0.5, :NORMAL => 1.0, :FLASH => 0.0 }
    calc = Module.new do
      define_singleton_method(:calculate) { |_type, *types| table[types.first] }
      define_singleton_method(:ineffective?) { |v| v == 0 }
      define_singleton_method(:not_very_effective?) { |v| v > 0 && v < 1 }
      define_singleton_method(:super_effective?) { |v| v > 1 }
    end
    prior = Object.const_defined?(:Effectiveness) ? Object.send(:remove_const, :Effectiveness) : nil
    Object.const_set(:Effectiveness, calc)
    yield
  ensure
    Object.send(:remove_const, :Effectiveness) if Object.const_defined?(:Effectiveness)
    Object.const_set(:Effectiveness, prior) if prior
  end

  # Runs the block with the player's Pokédex having battled every species that many times and owning it or not, then
  # puts back the player there was.
  def with_pokedex(battled, owned)
    dex = Object.new
    dex.define_singleton_method(:battled_count) { |_species| battled }
    dex.define_singleton_method(:owned?) { |_species| owned }
    was = $player
    $player = Struct.new(:pokedex).new(dex)
    yield
  ensure
    $player = was
  end

  # Runs the block with the panel's capture armed and empty, then puts back what it held before.
  def with_capture
    saved = [:@painted, :@bonus, :@armed].map { |v| [v, MoveInfo.instance_variable_get(v)] }
    MoveInfo.capture_on
    yield
  ensure
    saved.each { |v, value| MoveInfo.instance_variable_set(v, value) }
  end

  # Runs the block with GameData::Target answering targets_foe for the given targets, as v21's move targets do,
  # then takes it away again.
  def with_foe_targets(foes)
    with_game_data(:Target, lambda { |id| Struct.new(:targets_foe).new(foes.include?(id)) }) { yield }
  end

  # Runs the block with GameData::Type naming the types the window draws (Fire as Fuego), then takes it away again.
  def with_type_names
    names = { :FIRE => "Fuego", :NORMAL => "Normal" }
    with_game_data(:Type, lambda { |id| names[id] && Struct.new(:name).new(names[id]) }) { yield }
  end

  # Runs the block with GameData::<kind>.get answering through getter, then puts back what held that name before.
  def with_game_data(kind, getter)
    made = !Object.const_defined?(:GameData)
    Object.const_set(:GameData, Module.new) if made
    had = GameData.const_defined?(kind, false) ? GameData.send(:remove_const, kind) : nil
    GameData.const_set(kind, Class.new { define_singleton_method(:get) { |id| getter.call(id) } })
    yield
  ensure
    GameData.send(:remove_const, kind) if Object.const_defined?(:GameData) && GameData.const_defined?(kind, false)
    GameData.const_set(kind, had) if had
    Object.send(:remove_const, :GameData) if made && Object.const_defined?(:GameData)
  end

  # Runs the block with the game's Settings::<name> set to value, as a game that sets it does, then puts back what
  # held that name before.
  def with_setting(name, value)
    made = !Object.const_defined?(:Settings)
    Object.const_set(:Settings, Module.new) if made
    had = Settings.const_defined?(name, false)
    was = had ? Settings.send(:remove_const, name) : nil
    Settings.const_set(name, value)
    yield
  ensure
    if Object.const_defined?(:Settings)
      Settings.send(:remove_const, name) if Settings.const_defined?(name, false)
      Settings.const_set(name, was) if had
      Object.send(:remove_const, :Settings) if made
    end
  end
end
