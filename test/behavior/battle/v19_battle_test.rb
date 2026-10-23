# What the v19 battle scene (Fire Ash) shows only as graphics: the ability splash (an ability, a passive passed as a
# String, Infinite Fusion's second ability), the ZUD fight menu's mechanic button, and the battlefield it opens on.

# A battler with the names the readers ask for: its own (pbThis), its abilities and its moves.
class V19Battler
  attr_accessor :moves, :index
  def initialize(name, ability, index = 1, second = nil)
    @name = name; @ability = ability; @index = index; @second = second; @moves = []
  end
  def pbThis; @name; end
  def abilityName; @ability; end
  def ability2Name; @second; end
end

# The v19 scene as far as the splash goes: an ability bar per side, and Infinite Fusion's second one.
class V19SplashScene
  def initialize
    @sprites = {}
    %w[abilityBar_0 abilityBar_1 ability2Bar_0 ability2Bar_1].each { |k| @sprites[k] = Object.new }
  end
  def pbShowAbilitySplash(_battler, _arg = nil, _name = nil); :shown; end
end

# The ZUD plugin's fight menu on v19's BattleMenuBase: one @mode toggle for every mechanic, @chosen_button naming the
# one a press registers, and setIndexAndMode opening it without either setter.
class V19ZudMenu
  NoButton = -1
  MegaButton = 0
  UltraBurstButton = 1
  ZMoveButton = 2
  DynamaxButton = 3
  attr_accessor :chosen_button
  def initialize; @index = 0; @mode = 0; @battler = nil; @chosen_button = NoButton; end
  def mode=(value); @mode = value; end
  def index=(value); @index = value; end
  def battler=(value); @battler = value; end
  def setIndexAndMode(index, mode); @index = index; @mode = mode; end
end

class V19BattleTest < PokeAccessTest
  Move = Struct.new(:id, :name, :type, :pp, :totalpp)
  Field = Struct.new(:fieldEffect)

  # The Reborn engine's battle: its field (battle.field.effect), named by the game's $cache field data.
  RebornField = Struct.new(:field)
  RebornCache = Struct.new(:FEData)

  class << self
    private

    # Evaluates battle_g6 (as the harness reads it) with stand_ins under their game names for the moment: the hooks it
    # binds to them stay, while what it added to everything else (hooks on classes bound before, function bodies, the
    # missing list) is put back. Answers the bindings it reported missing.
    def bind_battle_g6(stand_ins)
      hooks = PokeAccess::Hooks
      chains = hooks.instance_variable_get(:@chains)
      chains_was = {}
      chains.each { |k, v| chains_was[k] = v.dup }
      bodies_was = {}
      hooks.fn_bodies.each { |k, v| bodies_was[k] = v.dup }
      missing = hooks.missing.dup
      hooks.missing.clear
      made = stand_ins.reject { |n, _k| Object.const_defined?(n) }
      made.each { |n, k| Object.const_set(n, k) }
      verbose = $VERBOSE
      $VERBOSE = nil
      path = File.join(Harness::ROOT, "core", "battle", "gen6", "battle_g6.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      hooks.missing.dup
    ensure
      $VERBOSE = verbose
      (made || {}).each_key { |n| Object.send(:remove_const, n) }
      chains_was.each { |k, v| chains[k] = v }
      bodies = hooks.fn_bodies
      bodies.keys.each { |k| bodies_was.key?(k) ? bodies[k].replace(bodies_was[k]) : bodies.delete(k) }
      hooks.missing.replace(missing)
    end
  end

  # The gen-6 battle hooks bound to the splash scene and the ZUD menu once, as this file loads.
  bind_battle_g6(:PokeBattle_Scene => V19SplashScene, :FightMenuDisplay => V19ZudMenu)

  test "the splash names the battler and its ability, queued" do
    V19SplashScene.new.pbShowAbilitySplash(rival)
    assert_equal [[ability_line("El Charizard rival", "Mar Llamas"), false]], SpeakCapture.log
  end

  test "the splash keeps the scene's own return" do
    assert_equal :shown, V19SplashScene.new.pbShowAbilitySplash(rival)
  end

  test "a passive passed as text is said as the bar shows it" do
    V19SplashScene.new.pbShowAbilitySplash(rival, "Curacion Activa")
    assert_equal [[ability_line("El Charizard rival", "Curacion Activa"), false]], SpeakCapture.log
  end

  test "Infinite Fusion's double-ability splash says what its bar shows" do
    fusion = V19Battler.new("La fusion rival", "Espesura", 1, "Baba")
    { [] => "Espesura", [true] => "Baba", [false, "Viscosidad"] => "Viscosidad",
      [true, "Hedor"] => "Hedor" }.each do |args, shown|
      SpeakCapture.clear
      V19SplashScene.new.pbShowAbilitySplash(fusion, *args)
      assert_equal [ability_line("La fusion rival", shown)], SpeakCapture.lines, "splash #{args.inspect}"
    end
  end

  test "a name its side's bar kept from an earlier call is said again" do
    fusion = V19Battler.new("La fusion rival", "Espesura", 1, "Baba")
    { "abilityBar_1" => [], "ability2Bar_1" => [true] }.each do |bar, args|
      scene = V19SplashScene.new
      PokeAccess.sprite(scene, bar).instance_variable_set(:@ability_name, "Viscosidad")
      SpeakCapture.clear
      scene.pbShowAbilitySplash(fusion, *args)
      assert_equal [ability_line("La fusion rival", "Viscosidad")], SpeakCapture.lines, bar
    end
  end

  test "a name kept on the other side's bar, or a blank one, leaves the battler's own ability" do
    mine = V19Battler.new("Tu Pikachu", "Electricidad Estatica", 0)
    { "abilityBar_1" => "Viscosidad", "abilityBar_0" => "" }.each do |bar, kept|
      scene = V19SplashScene.new
      PokeAccess.sprite(scene, bar).instance_variable_set(:@ability_name, kept)
      SpeakCapture.clear
      scene.pbShowAbilitySplash(mine)
      assert_equal [ability_line("Tu Pikachu", "Electricidad Estatica")], SpeakCapture.lines,
                   "#{bar} kept #{kept.inspect}"
    end
  end

  test "the splash is said only while the scene shows ability splashes" do
    { true => [ability_line("El Charizard rival", "Mar Llamas")], false => [] }.each do |shown, want|
      with_splash_setting(shown) do
        SpeakCapture.clear
        V19SplashScene.new.pbShowAbilitySplash(rival)
        assert_equal want, SpeakCapture.lines, "USE_ABILITY_SPLASH = #{shown}"
      end
    end
  end

  test "a splash with no ability to show, or no battler, says nothing" do
    [V19Battler.new("Ditto", nil), V19Battler.new("Ditto", ""), nil].each do |battler|
      V19SplashScene.new.pbShowAbilitySplash(battler)
      assert_nothing_spoken battler.inspect
    end
  end

  test "the mechanic button coming up says that mechanic is ready, queued" do
    { :NoButton => t(:bt_mega_ready), :MegaButton => t(:bt_mega_ready), :UltraBurstButton => t(:bt_ultra_ready),
      :ZMoveButton => t(:bt_special_ready, :name => t(:bt_m_zmove)),
      :DynamaxButton => t(:bt_special_ready, :name => t(:bt_m_dynamax)) }.each do |button, ready|
      menu = zud_menu(button)
      SpeakCapture.clear
      menu.mode = 1
      assert_equal [[ready, false]], SpeakCapture.log, button.to_s
    end
  end

  test "a Z-move toggle is named for the Z-move and reads the move again under its new name, queued" do
    menu = zud_menu(:ZMoveButton)
    menu.mode = 1
    renamed = Move.new(1, "Gigavoltio Destructor", 13, 1, 1)
    want = move_line(renamed)
    menu.instance_variable_get(:@battler).moves = [renamed]
    menu.mode = 2
    assert_equal [[t(:bt_special_on, :name => t(:bt_m_zmove)), true], [want, false]], SpeakCapture.log
  end

  test "a dynamax toggle off is named for dynamax and reads the move again, queued" do
    menu = zud_menu(:DynamaxButton)
    menu.mode = 1
    menu.mode = 2
    want = move_line(thunderbolt)
    menu.mode = 1
    assert_equal [[t(:bt_special_off, :name => t(:bt_m_dynamax)), true], [want, false]], SpeakCapture.log
  end

  test "a Mega Evolution or Ultra Burst toggle says its own line and reads no move" do
    { :MegaButton => [:bt_mega_on, :bt_mega_off], :UltraBurstButton => [:bt_ultra_on, :bt_ultra_off] }.each do |b, keys|
      menu = zud_menu(b)
      menu.mode = 1
      SpeakCapture.clear
      menu.mode = 2
      menu.mode = 1
      assert_equal [[t(keys[0]), true], [t(keys[1]), true]], SpeakCapture.log, b.to_s
    end
  end

  test "the same mode set again, or the button hidden, says nothing" do
    menu = zud_menu(:ZMoveButton)
    menu.mode = 1
    menu.mode = 2
    SpeakCapture.clear
    menu.mode = 2
    menu.mode = 0
    assert_nothing_spoken
  end

  test "the button coming up again on a later turn is said again" do
    menu = zud_menu(:MegaButton)
    menu.mode = 1
    menu.mode = 0
    SpeakCapture.clear
    menu.mode = 1
    assert_equal [[t(:bt_mega_ready), false]], SpeakCapture.log
  end

  test "the menu opens on its move, queued, and says the mechanic ready only when its button opens available" do
    { [0, 1] => [[thunderbolt, false], [t(:bt_special_ready, :name => t(:bt_m_zmove)), false]],
      [1, 0] => [[quick_attack, false]] }.each do |args, want|
      menu = zud_menu(:ZMoveButton)
      want = want.map { |what, interrupt| [what.is_a?(Move) ? move_line(what) : what, interrupt] }
      menu.setIndexAndMode(*args)
      assert_equal want, SpeakCapture.log, "setIndexAndMode#{args.inspect}"
    end
  end

  test "the first toggle after the menu opens is named for its mechanic" do
    menu = zud_menu(:ZMoveButton)
    menu.setIndexAndMode(0, 1)
    want = move_line(thunderbolt)
    menu.mode = 2
    assert_equal [[t(:bt_special_on, :name => t(:bt_m_zmove)), true], [want, false]], SpeakCapture.log
  end

  test "moving along the moves reads the focused one, interrupting" do
    menu = zud_menu(:NoButton)
    want = move_line(quick_attack)
    menu.index = 1
    assert_equal [[want, true]], SpeakCapture.log
  end

  test "setting the menu up for a battler reads its focused move afresh" do
    menu = zud_menu(:NoButton)
    menu.index = 0
    want = move_line(thunderbolt)
    menu.battler = V19Battler.new("Pikachu", "Electricidad Estatica", 0).tap { |b| b.moves = [thunderbolt] }
    menu.index = 0
    assert_equal [[want, true]], SpeakCapture.log
  end

  test "the battlefield a battle opens on is said, queued" do
    with_field_effects do
      PokeAccess::Battle.announce_opening_field(Field.new(:Fire))
      assert_equal [[t(:bt_field_effect, :f => "Campo de fuego Fire"), false]], SpeakCapture.log
    end
  end

  test "the opening field is said once per battle, and again for the next battle" do
    with_field_effects do
      first = Field.new(:Fire)
      PokeAccess::Battle.announce_opening_field(first)
      SpeakCapture.clear
      PokeAccess::Battle.announce_opening_field(first)
      assert_nothing_spoken "the same battle"
      PokeAccess::Battle.announce_opening_field(Field.new(:Water))
      assert_equal [t(:bt_field_effect, :f => "Campo de fuego Water")], SpeakCapture.lines, "the next battle"
    end
  end

  test "the Reborn engine's field is named by the game's field data, and its plain indoor field by nothing" do
    with_reborn_fields(:VOLCANIC => "Cima volcanica") do
      { :VOLCANIC => [[t(:bt_field_effect, :f => "Cima volcanica"), false]], :INDOOR => [] }.each do |effect, want|
        SpeakCapture.clear
        PokeAccess::Battle.announce_opening_field(RebornField.new(Struct.new(:effect).new(effect)))
        assert_equal want, SpeakCapture.log, effect.to_s
      end
    end
  end

  test "a battle on the plain field says nothing" do
    with_field_effects do
      PokeAccess::Battle.announce_opening_field(Field.new(:None))
      assert_nothing_spoken
    end
  end

  test "the field key names the battlefield" do
    with_field_effects do
      PokeAccess::Battle.set_battle(Field.new(:Fire))
      PokeAccess::Battle.announce_field
      assert_equal [[t(:bt_field_effect, :f => "Campo de fuego Fire"), true]], SpeakCapture.log
    end
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # The rival's Charizard, whose splash shows its ability.
  def rival; V19Battler.new("El Charizard rival", "Mar Llamas"); end

  def ability_line(name, ability); t(:bt_ability, :name => name, :ability => ability); end

  def thunderbolt; Move.new(1, "Rayo", 13, 15, 15); end
  def quick_attack; Move.new(98, "Ataque Rapido", 0, 30, 30); end

  # A ZUD fight menu with button chosen, set up for a Pikachu knowing Rayo and Ataque Rapido, the log cleared.
  def zud_menu(button)
    menu = V19ZudMenu.new
    pikachu = V19Battler.new("Pikachu", "Electricidad Estatica", 0)
    pikachu.moves = [thunderbolt, quick_attack]
    menu.battler = pikachu
    menu.chosen_button = V19ZudMenu.const_get(button)
    SpeakCapture.clear
    menu
  end

  # What core's move reader says for move, read on a menu of its own and checked to open with the move's painted
  # name; the log is left empty.
  def move_line(move)
    probe = Object.new
    probe.instance_variable_set(:@battler, V19Battler.new("Probe", nil).tap { |b| b.moves = [move] })
    probe.instance_variable_set(:@index, 0)
    PokeAccess::Battle.read_fight_move(probe)
    line = SpeakCapture.last
    SpeakCapture.clear
    assert_match(/\A#{Regexp.escape(move.name)}\. /, line.to_s, "the line for #{move.name} opens with its painted name")
    line
  end

  # Runs the block with PokeBattle_SceneConstants::USE_ABILITY_SPLASH set to value, as the game's scene declares it.
  def with_splash_setting(value)
    made = !Object.const_defined?(:PokeBattle_SceneConstants)
    Object.const_set(:PokeBattle_SceneConstants, Module.new) if made
    had = PokeBattle_SceneConstants.const_defined?(:USE_ABILITY_SPLASH, false)
    was = had ? PokeBattle_SceneConstants::USE_ABILITY_SPLASH : nil
    PokeBattle_SceneConstants.send(:remove_const, :USE_ABILITY_SPLASH) if had
    PokeBattle_SceneConstants.const_set(:USE_ABILITY_SPLASH, value)
    yield
  ensure
    PokeBattle_SceneConstants.send(:remove_const, :USE_ABILITY_SPLASH)
    PokeBattle_SceneConstants.const_set(:USE_ABILITY_SPLASH, was) if had
    Object.send(:remove_const, :PokeBattle_SceneConstants) if made
  end

  # Runs the block with the game's $cache holding the Reborn engine's field data, names by field id.
  def with_reborn_fields(names)
    was = $cache
    $cache = RebornCache.new(names.map { |id, name| [id, Struct.new(:name).new(name)] }.to_h)
    yield
  ensure
    $cache = was
  end

  # Runs the block with GameData::BattleFieldEffect naming every field "Campo de fuego <id>", as Fire Ash's data does.
  def with_field_effects
    made = !Object.const_defined?(:GameData)
    Object.const_set(:GameData, Module.new) if made
    fields = Module.new
    def fields.try_get(id); Struct.new(:name).new("Campo de fuego #{id}"); end
    GameData.const_set(:BattleFieldEffect, fields)
    yield
  ensure
    GameData.send(:remove_const, :BattleFieldEffect) if GameData.const_defined?(:BattleFieldEffect, false)
    Object.send(:remove_const, :GameData) if made
  end
end
