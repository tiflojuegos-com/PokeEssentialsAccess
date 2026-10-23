# The Enhanced Battle UI's move panel works out some moves' type and category while drawing: Tera Blast and Tera
# Starstorm by the Tera state and the higher attacking stat, Shell Side Arm and Photon Geyser by their use-time step
# on a copy; the rest as the move has them.
class DbkMoveCategoryTest < PokeAccessTest
  MoveInfo = PokeAccess::DBKMoveInfo
  TERA_BLAST = "CategoryDependsOnHigherDamageTera"
  TERA_STARSTORM = "TerapagosCategoryDependsOnHigherDamage"
  TARGET_CODES = ["CategoryDependsOnHigherDamageIgnoreTargetAbility", "CategoryDependsOnHigherDamagePoisonTarget"]

  # A move as the panel reads it: function code, stored category and type, and what the battle calculated.
  Move = Struct.new(:name, :function_code, :category, :calcCategory, :type, :calc_type) do
    def pbCalcType(_battler); calc_type; end
  end

  # A battler with what the panel asks of it: whether it is terastallized, its attacking stats and Tera type.
  class Fighter
    attr_reader :tera_type
    def initialize(tera, atk, spatk, tera_type = nil)
      @tera = tera; @atk = atk; @spatk = spatk; @tera_type = tera_type
    end
    def tera?; @tera; end
    def getOffensiveStats; [@atk, @spatk]; end
    def pbDirectOpposing; :foe; end
  end

  # Terapagos, which Anil's and Royal's panels count as terastallized in its Stellar Form (form 2).
  class Terapagos < Fighter
    def initialize(form); super(false, 150, 100); @form = form; end
    def isSpecies?(sp); sp == :TERAPAGOS; end
    def form; @form; end
  end

  # Photon Geyser or Shell Side Arm: special until pbOnStartUse compares the user's attacking stats against the foe.
  class TargetMove
    attr_reader :name, :function_code, :category, :calcCategory
    def initialize(code); @name = "Fotogeiser"; @function_code = code; @category = 1; @calcCategory = 1; end
    def pbOnStartUse(user, targets)
      atk, spatk = user.getOffensiveStats
      @calcCategory = (targets == [:foe] && atk > spatk) ? 0 : 1
    end
  end

  test "draws an ordinary move's own category" do
    assert_equal 1, MoveInfo.shown_category(Move.new("Rayo", "ParalyzeTarget", 1), Fighter.new(true, 140, 90), true)
  end

  test "draws a terastallized Tera move by the higher attacking stat, special on a tie" do
    { [140, 90] => 0, [90, 140] => 1, [100, 100] => 1 }.each do |(atk, spatk), want|
      [TERA_BLAST, TERA_STARSTORM].each do |code|
        move = Move.new("Teraexplosion", code, 1, 1)
        assert_equal want, MoveInfo.shown_category(move, Fighter.new(true, atk, spatk), true),
                     "#{code} at #{atk}/#{spatk}"
      end
    end
  end

  test "draws a Tera move before terastallizing with what the battle calculated, not its stored category" do
    move = Move.new("Teraexplosion", TERA_BLAST, 1, 0)
    assert_equal 0, MoveInfo.shown_category(move, Fighter.new(false, 90, 140), false)
  end

  test "falls back to a Tera move's own category when the battler cannot give its stats" do
    battler = Fighter.new(true, 1, 2)
    def battler.getOffensiveStats; raise "no stats"; end
    assert_equal 1, MoveInfo.shown_category(Move.new("Teraexplosion", TERA_BLAST, 1, 0), battler, true)
  end

  test "works out Photon Geyser and Shell Side Arm against the foe ahead" do
    TARGET_CODES.each do |code|
      { [150, 100] => 0, [100, 150] => 1 }.each do |(atk, spatk), want|
        assert_equal want, MoveInfo.shown_category(TargetMove.new(code), Fighter.new(false, atk, spatk), false),
                     "#{code} at #{atk}/#{spatk}"
      end
    end
  end

  test "works those moves out on a copy, leaving the move itself as it was" do
    TARGET_CODES.each do |code|
      move = TargetMove.new(code)
      MoveInfo.shown_category(move, Fighter.new(false, 150, 100), false)
      assert_equal 1, move.calcCategory, code
    end
  end

  test "gives the fight menu the same category for those moves, and none for any other" do
    assert_equal 0, PokeAccess::MoveInfo.target_category(TargetMove.new(TARGET_CODES[1]), Fighter.new(false, 150, 100))
    assert_nil PokeAccess::MoveInfo.target_category(Move.new("Rayo", "ParalyzeTarget", 1), Fighter.new(false, 150, 100))
  end

  test "counts a battler as terastallized when it is, when Tera is staged for it, or as Stellar Terapagos" do
    staged = Struct.new(:teraType).new(1)
    unstaged = Struct.new(:teraType).new(0)
    plain = Fighter.new(false, 1, 1)
    formed = Object.new
    def formed.form; 2; end
    cases = [[Fighter.new(true, 1, 1), nil, nil, true], [plain, :tera, staged, true], [plain, :tera, unstaged, false],
             [plain, :tera, Object.new, false], [plain, :dynamax, staged, false], [plain, nil, nil, false],
             [Terapagos.new(2), nil, nil, true], [Terapagos.new(1), nil, nil, false], [formed, nil, nil, false],
             [Object.new, nil, nil, false]]
    cases.each_with_index do |(battler, special, cw, want), i|
      assert_equal want, MoveInfo.terastal?(battler, special, cw), "case #{i}: #{special.inspect}"
    end
  end

  test "draws an ordinary move's calculated type, else its own" do
    weather_ball = Move.new("Bola Clima", "TypeDependsOnWeather", 1, 1, :NORMAL, :FIRE)
    assert_equal :FIRE, MoveInfo.shown_type(weather_ball, nil, false)
    assert_equal :NORMAL, MoveInfo.shown_type(Move.new("Placaje", "None", 0, 0, :NORMAL, nil), nil, true)
  end

  test "draws a Tera move's stored type until terastallized" do
    [TERA_BLAST, TERA_STARSTORM].each do |code|
      move = Move.new("Teraexplosion", code, 1, 1, :NORMAL, :FIRE)
      assert_equal :NORMAL, MoveInfo.shown_type(move, Terapagos.new(2), false), code
    end
  end

  test "draws a terastallized Tera Blast as the Tera type, else as calculated" do
    move = Move.new("Teraexplosion", TERA_BLAST, 1, 1, :NORMAL, :ICE)
    assert_equal :FIRE, MoveInfo.shown_type(move, Fighter.new(true, 1, 1, :FIRE), true)
    assert_equal :ICE, MoveInfo.shown_type(move, Fighter.new(true, 1, 1), true), "with no Tera type to tell"
  end

  test "draws a terastallized Tera Starstorm as Stellar on Terapagos, else as calculated" do
    move = Move.new("Teraclusion", TERA_STARSTORM, 1, 1, :NORMAL, :ICE)
    assert_equal :STELLAR, MoveInfo.shown_type(move, Terapagos.new(2), true)
    assert_equal :ICE, MoveInfo.shown_type(move, Fighter.new(true, 1, 1, :FIRE), true), "on another species"
  end
end
