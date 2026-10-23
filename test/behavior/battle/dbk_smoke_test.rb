# The Deluxe Battle Kit readers (plugins/dbk_battle.rb, dbk_enhanced_ui.rb) driven through their hooks on Sky-shaped
# Battle and Battle::Scene stand-ins: the mechanic toggle, the ball and battler selectors and the battler and move info
# panels, each read once per change and again when it opens anew. The plugin files are evaluated again over the
# stand-ins once, as this file loads, and the stand-ins hold the game's names only while a test runs (in the gen-6
# pass the engine probes would read ::Battle as the v19+ battle scene).
class DbkSmokeTest < PokeAccessTest
  T = PokeAccess::I18n

  # The balls the item data knows: name and description.
  BALLS = { :POKEBALL => ["Poké Ball", "Una bola corriente."], :ULTRABALL => ["Ultra Ball", "Una bola muy buena."],
            :GREATBALL => ["Super Ball", ""] }

  # A Pokemon as the selectors and panels draw it: its name and sex.
  Mon = Struct.new(:name, :gender)

  # A battler as the panels read it: the player's own when mine, a trainer's unless wild; with no isRaidBoss?, as in
  # a kit without raid battles (raid_boss gives one its own).
  Fighter = Struct.new(:name, :index, :level, :hp, :totalhp, :pokemon, :displayPokemon, :battle, :abilityName,
                       :itemName, :mine, :moves, :status, :lastMoveUsed, :wild) do
    def opposes?; index.odd?; end
    def pbOwnedByPlayer?; mine; end
    def wild?; wild ? true : false; end
  end

  # A battler as the battler panel's type line reads it: its battle types (the third only when asked with it), its
  # pre-Tera types once terastallized, the Pokemon an Illusion shows, and whether it is a foe.
  Typed = Struct.new(:battle_types, :pre_tera, :disguise, :foe) do
    def pbTypes(withtype = false); withtype ? battle_types : battle_types.first(2); end
    def tera?; !pre_tera.nil?; end
    def pbPreTeraTypes; pre_tera; end
    def opposes?; foe; end
    def pbOwnedByPlayer?; !foe; end
    def effects; { PBEffects::Illusion => disguise }; end
    def displayPokemon; disguise; end
  end

  # A move as the move panel reads it from the battler.
  Move = Struct.new(:name, :power, :accuracy, :category)

  # Sky's Battle with the kit's mechanic toggle and its registered answer, and its Battle::Scene with the selectors and
  # info panels, each method answering a sentinel the hooks must pass on; the move panel paints @paint if set.
  Kit = Class.new do
    attr_accessor :registered
    def pbToggleSpecialActions(_idx, _cmd); :toggled; end
    def pbBattleMechanicIsRegistered?(_idx, _cmd); @registered; end
  end
  Kit.const_set(:Scene, Class.new do
    def pbSelectBallInfo(*_a); :ball_opened; end
    def pbUpdateBallSelection(_items, _index, _show = false); :ball_drawn; end
    def pbSelectBattlerInfo(*_a); :bsel_opened; end
    def pbUpdateBattlerSelection(_side, _poke, _select = true); :bsel_drawn; end
    def pbOpenBattlerInfo(*_a); :binfo_opened; end
    def pbUpdateBattlerInfo(_battler, _effects, _idx = 0); :binfo_drawn; end
    def pbUpdateMoveInfoWindow(_battler, _special, _cw)
      pbDrawTextPositions(nil, @paint) if @paint
      :minfo_drawn
    end
  end)

  test "keeps the kit's answer to a mechanic toggle" do
    with_kit { |battle, _scene| assert_equal :toggled, battle.pbToggleSpecialActions(0, :mega) }
  end

  test "says a mechanic turned on and off at once, by its name" do
    with_kit do |battle, _scene|
      battle.registered = true
      battle.pbToggleSpecialActions(0, :mega)
      battle.registered = false
      battle.pbToggleSpecialActions(0, :mega)
    end
    assert_equal [[T.t(:dbk_on, :m => T.t(:dbk_mega)), true], [T.t(:dbk_off, :m => T.t(:dbk_mega)), true]],
                 SpeakCapture.log
  end

  test "names each mechanic the kit toggles, and one it has no name for by the kit's own" do
    names = { :dynamax => T.t(:dbk_dynamax), :tera => T.t(:dbk_tera), :zmove => T.t(:dbk_zmove),
              :ultra => T.t(:dbk_ultra), :style => T.t(:dbk_style), :custom => "custom" }
    said = with_kit do |battle, _scene|
      battle.registered = true
      names.keys.map do |mech|
        SpeakCapture.clear
        battle.pbToggleSpecialActions(0, mech)
        SpeakCapture.last
      end
    end
    assert_equal names.values.map { |n| T.t(:dbk_on, :m => n) }, said
  end

  test "says just the mechanic's name when the battle cannot tell whether it is registered" do
    with_kit do |battle, _scene|
      battle.registered = nil
      battle.pbToggleSpecialActions(0, :tera)
      def battle.pbBattleMechanicIsRegistered?(_idx, _cmd); raise "no such mechanic"; end
      battle.pbToggleSpecialActions(0, :tera)
    end
    assert_equal [[T.t(:dbk_tera), true], [T.t(:dbk_tera), true]], SpeakCapture.log
  end

  test "says nothing for a toggle with no mechanic named" do
    with_kit do |battle, _scene|
      battle.registered = true
      battle.pbToggleSpecialActions(0, nil)
    end
    assert_nothing_spoken
  end

  test "keeps the ball selector's answers" do
    with_kit do |_battle, scene|
      assert_equal [:ball_opened, :ball_drawn], [scene.pbSelectBallInfo, scene.pbUpdateBallSelection(balls, 0, false)]
    end
  end

  test "reads the focused ball with its count as the selector opens, and the next as the cursor moves" do
    with_kit do |_battle, scene|
      with_game_data do
        scene.pbSelectBallInfo
        scene.pbUpdateBallSelection(balls, 0, false)
        scene.pbUpdateBallSelection(balls, 1, false)
      end
    end
    assert_equal [[ball("Poké Ball", 5), true], [ball("Ultra Ball", 2), true]], SpeakCapture.log
  end

  test "reads a ball once until the cursor moves" do
    with_kit do |_battle, scene|
      with_game_data do
        scene.pbSelectBallInfo
        scene.pbUpdateBallSelection(balls, 0, false)
        SpeakCapture.clear
        scene.pbUpdateBallSelection(balls, 0, false)
      end
    end
    assert_nothing_spoken
  end

  test "reads the entry with no ball as Back, and nothing for a slot with no entry" do
    with_kit do |_battle, scene|
      with_game_data do
        scene.pbSelectBallInfo
        scene.pbUpdateBallSelection(balls, 99, false)
        scene.pbUpdateBallSelection(balls, 3, false)
      end
    end
    assert_equal [[T.t(:dbk_back), true]], SpeakCapture.log
  end

  test "reads the ball's description when the details key shows it, and the line alone for a ball with none" do
    with_kit do |_battle, scene|
      with_game_data do
        scene.pbSelectBallInfo
        scene.pbUpdateBallSelection(balls, 0, false)
        SpeakCapture.clear
        scene.pbUpdateBallSelection(balls, 0, true)
        scene.pbUpdateBallSelection(balls, 2, true)
      end
    end
    assert_equal [["#{ball("Poké Ball", 5)}. Una bola corriente.", true], [ball("Super Ball", 3), true]],
                 SpeakCapture.log
  end

  test "reads a ball listed without a count by its name alone" do
    with_kit do |_battle, scene|
      with_game_data do
        scene.pbSelectBallInfo
        scene.pbUpdateBallSelection([:ULTRABALL, :POKEBALL], 0, false)
      end
    end
    assert_equal [["Ultra Ball", true]], SpeakCapture.log
  end

  test "reads the ball it closed on again when the selector reopens" do
    with_kit do |_battle, scene|
      with_game_data do
        scene.pbSelectBallInfo
        scene.pbUpdateBallSelection(balls, 1, false)
        SpeakCapture.clear
        scene.pbSelectBallInfo
        scene.pbUpdateBallSelection(balls, 1, false)
      end
    end
    assert_equal [[ball("Ultra Ball", 2), true]], SpeakCapture.log
  end

  test "keeps the battler grid's answers" do
    with_kit do |_battle, scene|
      assert_equal [:bsel_opened, :bsel_drawn], [scene.pbSelectBattlerInfo, scene.pbUpdateBattlerSelection(0, 0, true)]
    end
  end

  test "reads the player's battler as it is, with its sign and owner, once until the cursor moves" do
    with_kit do |_battle, scene|
      in_battle(scene, [foe_near, foe_far])
      scene.pbSelectBattlerInfo
      scene.pbUpdateBattlerSelection(0, 0, true)
      scene.pbUpdateBattlerSelection(0, 0, true)
    end
    assert_equal [[T.t(:dbk_owner, :name => "Sparky ♂", :owner => "Rojo"), true]], SpeakCapture.log
  end

  test "lays the other side out reversed, its first cell its last battler, each as shown, a sexless one signless" do
    with_kit do |_battle, scene|
      in_battle(scene, [foe_near, foe_far])
      scene.pbSelectBattlerInfo
      scene.pbUpdateBattlerSelection(1, 0, true)
      scene.pbUpdateBattlerSelection(1, 1, true)
    end
    assert_equal [[T.t(:dbk_owner, :name => "Lejano", :owner => "Rival"), true],
                  [T.t(:dbk_owner, :name => "Disfraz ♀", :owner => "Rival"), true]], SpeakCapture.log
  end

  test "reads a battler with no trainer, or a nameless one, by its name alone" do
    { nil => nil, "" => Struct.new(:name).new("") }.each do |what, owner|
      SpeakCapture.clear
      with_kit do |_battle, scene|
        in_battle(scene, [foe_near])
        battle_state.define_singleton_method(:pbGetOwnerFromBattlerIndex) { |_index| owner }
        scene.pbSelectBattlerInfo
        scene.pbUpdateBattlerSelection(1, 0, true)
      end
      assert_equal [["Disfraz ♀", true]], SpeakCapture.log, "trainer #{what.inspect}"
    end
  end

  test "draws no sex in the grid for a raid boss on the other side" do
    with_kit do |_battle, scene|
      in_battle(scene, [raid_boss])
      scene.pbSelectBattlerInfo
      scene.pbUpdateBattlerSelection(1, 0, true)
    end
    assert_equal [[T.t(:dbk_owner, :name => "Jefe", :owner => "Rival"), true]], SpeakCapture.log
  end

  test "reads nothing for a cell with no battler, or one with no name" do
    nameless = Fighter.new("", 1, 40, 60, 60, Mon.new("", 1), Mon.new("", 1), battle_state)
    with_kit do |_battle, scene|
      in_battle(scene, [nameless])
      scene.pbSelectBattlerInfo
      scene.pbUpdateBattlerSelection(1, 5, true)
      scene.pbUpdateBattlerSelection(1, 0, true)
    end
    assert_nothing_spoken
  end

  test "reads the cell it closed on again when the grid reopens" do
    with_kit do |_battle, scene|
      in_battle(scene, [foe_near, foe_far])
      scene.pbSelectBattlerInfo
      scene.pbUpdateBattlerSelection(0, 0, true)
      SpeakCapture.clear
      scene.pbSelectBattlerInfo
      scene.pbUpdateBattlerSelection(0, 0, true)
    end
    assert_equal [[T.t(:dbk_owner, :name => "Sparky ♂", :owner => "Rojo"), true]], SpeakCapture.log
  end

  test "keeps the battler panel's answer" do
    with_kit { |_battle, scene| assert_equal :binfo_drawn, info_panel(scene).pbUpdateBattlerInfo(sparky, effects, 0) }
  end

  test "reads the battler's summary, then its focused effect queued" do
    with_kit { |_battle, scene| info_panel(scene).pbUpdateBattlerInfo(sparky, effects, 0) }
    assert_equal [[sparky_summary, true], ["Drenadoras. 3. Roba PS cada turno", false]], SpeakCapture.log
  end

  test "says a foe's types, status, last move and stat changes, withholding its ability and item" do
    foe = foe_near
    foe.status = :BURN
    foe.lastMoveUsed = :THUNDERBOLT
    foe.instance_variable_set(:@stages, [0, 1, 0, 0, 0, 0, 0])
    def foe.pbTypes(_withtype = false); [0, 2]; end
    with_kit { |_battle, scene| with_game_data { info_panel(scene).pbUpdateBattlerInfo(foe, [], 0) } }
    line = ["Disfraz", "♀", T.t(:dbk_trainer, :name => "Rival"), T.t(:dbk_turn, :n => 3), T.t(:dbk_level, :n => 42),
            T.t(:bt_hp_pct, :n => 50), T.t(:mv_type, :t => "Tipo0/Tipo2"), "Quemado", T.t(:dbk_lastmove, :m => "Rayo"),
            T.t(:bt_changes, :list => "Estadistica1 +1").delete_prefix(". ")]
    assert_equal [[line.join(", "), true]], SpeakCapture.log
  end

  test "says no status for a healthy battler, though the game's data names that one too" do
    healthy = sparky
    healthy.status = :NONE
    with_kit { |_battle, scene| with_game_data { info_panel(scene).pbUpdateBattlerInfo(healthy, [], 0) } }
    assert_equal [[sparky_summary, true]], SpeakCapture.log
  end

  test "says a raid boss's level as unknown, with no sex drawn" do
    with_kit { |_battle, scene| info_panel(scene).pbUpdateBattlerInfo(raid_boss, [], 0) }
    line = ["Jefe", T.t(:dbk_trainer, :name => "Rival"), T.t(:dbk_turn, :n => 3), T.t(:dbk_level_unknown),
            T.t(:bt_hp_pct, :n => 50)]
    assert_equal [[line.join(", "), true]], SpeakCapture.log
  end

  test "leaves out what a battler cannot tell: trainer and turn with no battle, a level, an ability or item" do
    alone = Fighter.new("Solo", 0, nil, 30, 60, Mon.new("Solo", 0), Mon.new("Solo", 0), nil, "", "", true)
    with_kit { |_battle, scene| info_panel(scene).pbUpdateBattlerInfo(alone, [], 0) }
    assert_equal [[["Solo", "♂", T.t(:dbk_hp, :hp => 30, :tot => 60)].join(", "), true]], SpeakCapture.log
  end

  test "leaves out the hp with no total, and a status or last move the game's data cannot name" do
    alone = Fighter.new("Solo", 0, 42, 30, nil, Mon.new("Solo", 0), Mon.new("Solo", 0), nil, nil, nil, true, [],
                        :POISON, :STRUGGLE)
    with_kit { |_battle, scene| with_game_data { info_panel(scene).pbUpdateBattlerInfo(alone, [], 0) } }
    assert_equal [[["Solo", "♂", T.t(:dbk_level, :n => 42)].join(", "), true]], SpeakCapture.log
  end

  test "names no trainer for a wild battler or one whose trainer has no name" do
    wild = foe_far
    wild.wild = true
    unnamed = foe_far
    unnamed.battle = Struct.new(:turnCount) { def pbGetOwnerName(_index); ""; end }.new(0)
    with_kit do |_battle, scene|
      panel = info_panel(scene)
      panel.pbUpdateBattlerInfo(wild, [], 0)
      panel.pbOpenBattlerInfo
      panel.pbUpdateBattlerInfo(unnamed, [], 0)
    end
    rest = [T.t(:dbk_level, :n => 40), T.t(:bt_hp_pct, :n => 100)]
    assert_equal [[(["Lejano", T.t(:dbk_turn, :n => 3)] + rest).join(", "), true],
                  [(["Lejano", T.t(:dbk_turn, :n => 1)] + rest).join(", "), true]], SpeakCapture.log
  end

  test "says the types the battler panel paints: a foe's disguise, the pre-Tera ones, else the battle's, third too" do
    disguise = Struct.new(:types).new([12])
    cases = { "foe" => [Typed.new([0, 2, 13], nil, nil, true), [0, 2, 13]],
              "terastallized" => [Typed.new([0, 2, 13], [10], nil, true), [10]],
              "foe under Illusion" => [Typed.new([0, 2, 13], nil, disguise, true), [12]],
              "own under Illusion" => [Typed.new([0, 2, 13], nil, disguise, false), [0, 2, 13]],
              "terastallized under Illusion" => [Typed.new([0, 2, 13], [10], disguise, true), [10]] }
    with_illusion_effect do
      cases.each do |what, (battler, types)|
        assert_equal T.t(:mv_type, :t => types.map { |ty| "Tipo#{ty}" }.join("/")),
                     PokeAccess::DBKBattlerInfo.types(battler), what
      end
    end
  end

  test "says a battler left with no typing as unknown, as the panel paints it ???" do
    said = with_illusion_effect { PokeAccess::DBKBattlerInfo.types(Typed.new([], nil, nil, true)) }
    assert_equal T.t(:pdx_unknown_value), said
  end

  test "says the types of a species the battler panel hides as unknown" do
    hidden = Object.new
    def hidden.celestial?; true; end
    assert_equal T.t(:pdx_unknown_value), PokeAccess::DBKBattlerInfo.types(hidden)
  end

  test "reads only the new effect, at once, moving through the effects, and drops a -- tick and an empty part" do
    with_kit do |_battle, scene|
      panel = info_panel(scene)
      panel.pbUpdateBattlerInfo(sparky, effects, 0)
      SpeakCapture.clear
      panel.pbUpdateBattlerInfo(sparky, effects, 0)
      (1..3).each { |row| panel.pbUpdateBattlerInfo(sparky, effects, row) }
    end
    assert_equal [["Tóxico. Daño creciente", true], ["Rocas Afiladas", true],
                  ["Teracristalización. El Pokémon está Teracristalizado al tipo Fuego.", true]], SpeakCapture.log
  end

  test "reads the summary of each battler the panel moves to" do
    with_kit do |_battle, scene|
      panel = info_panel(scene)
      panel.pbUpdateBattlerInfo(sparky, [], 0)
      panel.pbUpdateBattlerInfo(foe_near, [], 0)
      SpeakCapture.clear
      panel.pbUpdateBattlerInfo(sparky, [], 0)
    end
    assert_equal [[sparky_summary, true]], SpeakCapture.log
  end

  test "says nothing while the overlay is closed, and reads again when it reopens on the same battler" do
    with_kit do |_battle, scene|
      panel = info_panel(scene)
      panel.pbUpdateBattlerInfo(sparky, [], 0)
      SpeakCapture.clear
      panel.instance_variable_set(:@enhancedUIToggle, nil)
      panel.pbUpdateBattlerInfo(sparky, [], 0)
      assert_nothing_spoken "closed"
      panel.instance_variable_set(:@enhancedUIToggle, :battler)
      panel.pbUpdateBattlerInfo(sparky, [], 0)
    end
    assert_equal [[sparky_summary, true]], SpeakCapture.log
  end

  test "reads the battler it closed on again when the panel opens again" do
    with_kit do |_battle, scene|
      panel = info_panel(scene)
      panel.pbUpdateBattlerInfo(sparky, effects, 0)
      SpeakCapture.clear
      assert_equal :binfo_opened, panel.pbOpenBattlerInfo
      panel.pbUpdateBattlerInfo(sparky, effects, 0)
    end
    assert_equal [[sparky_summary, true], ["Drenadoras. 3. Roba PS cada turno", false]], SpeakCapture.log
  end

  test "leaves out what the fight menu's line already said of the move, and says nothing when it said it all" do
    said = { ["Rayo", T.t(:cat_physical), T.t(:mv_power, :p => "90")] => [[T.t(:mv_acc, :a => 100), false]],
             bolt_line.split(", ") => [] }
    said.each do |fight_line, want|
      SpeakCapture.clear
      with_kit do |_battle, scene|
        with_panel_state do
          PokeAccess::BattleScene.instance_variable_set(:@panel_shut, false)
          PokeAccess::BattleScene.instance_variable_set(:@fight_line, [0, 0, fight_line])
          move_panel(scene).pbUpdateMoveInfoWindow(fighter, nil, cursor(0))
        end
      end
      assert_equal want, SpeakCapture.log, "after the fight line said #{fight_line.length} parts"
    end
  end

  test "keeps the move panel's answer" do
    with_kit do |_battle, scene|
      with_panel_state { assert_equal :minfo_drawn, move_panel(scene).pbUpdateMoveInfoWindow(fighter, nil, cursor(0)) }
    end
  end

  test "reads the focused move's category and figures, queued, once until it changes" do
    with_kit do |_battle, scene|
      with_panel_state do
        panel = move_panel(scene)
        battler = fighter
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(0))
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(0))
      end
    end
    assert_equal [[bolt_line, false]], SpeakCapture.log
  end

  test "says only the new figure when a staged mechanic repaints the move under a still cursor" do
    with_kit do |_battle, scene|
      with_panel_state do
        panel = move_panel(scene)
        battler = fighter
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(0))
        SpeakCapture.clear
        battler.moves[0].power = 160
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(0))
      end
    end
    assert_equal [[T.t(:mv_power, :p => "160"), false]], SpeakCapture.log
  end

  test "reads a staged Z-move in its Z form" do
    with_kit do |_battle, scene|
      with_panel_state do
        battler = fighter
        bolt = battler.moves[0]
        def bolt.convert_zmove(_battler, _battle, _idx, _flag); Move.new("Gigavoltio Destructor", 175, 0, 1); end
        move_panel(scene).pbUpdateMoveInfoWindow(battler, :zmove, Struct.new(:index, :mode).new(0, 2))
      end
    end
    line = ["Gigavoltio Destructor", T.t(:cat_special), T.t(:mv_power, :p => "175"),
            T.t(:mv_acc, :a => T.t(:mv_acc_perfect))]
    assert_equal [[line.join(", "), false]], SpeakCapture.log
  end

  test "reads the move the cursor moves to, a status move without power" do
    with_kit do |_battle, scene|
      with_panel_state do
        panel = move_panel(scene)
        battler = fighter
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(0))
        SpeakCapture.clear
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(1))
      end
    end
    assert_equal [[["Cambio", T.t(:cat_status), T.t(:mv_acc, :a => T.t(:mv_acc_perfect))].join(", "), false]],
                 SpeakCapture.log
  end

  test "says nothing while the move overlay is closed, and reads the move whole when it reopens" do
    with_kit do |_battle, scene|
      with_panel_state do
        panel = move_panel(scene)
        battler = fighter
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(0))
        SpeakCapture.clear
        panel.instance_variable_set(:@enhancedUIToggle, nil)
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(0))
        assert_nothing_spoken "closed"
        panel.instance_variable_set(:@enhancedUIToggle, :move)
        panel.pbUpdateMoveInfoWindow(battler, nil, cursor(0))
      end
    end
    assert_equal [[bolt_line, false]], SpeakCapture.log
  end

  test "reads the figures the panel painted over the move data's" do
    with_kit do |_battle, scene|
      with_panel_state do
        panel = move_panel(scene)
        panel.instance_variable_set(:@paint, [["Pow", 256, 40, :left], ["135", 309, 40, :center],
                                              ["Acc", 348, 40, :left], ["100", 401, 40, :center],
                                              ["Pri", 442, 40, :left], ["---", 484, 40, :center],
                                              ["Eff", 428, 12, :left], ["10%", 484, 12, :center]])
        panel.pbUpdateMoveInfoWindow(fighter, nil, cursor(0))
      end
    end
    line = ["Rayo", T.t(:cat_physical), T.t(:mv_power, :p => "135"), T.t(:mv_acc, :a => "100"),
            T.t(:mv_effect, :n => "10%")]
    assert_equal [[line.join(", "), false]], SpeakCapture.log
  end

  private

  # Yields a new Battle and Battle::Scene with the kit's readers bound to them attached, the classes set under those
  # names meanwhile.
  def with_kit
    attached({ :Battle => Kit }, BOUND) { yield Kit.new, Kit::Scene.new }
  end

  # The ball selector's entries: [ball, count], and the Back entry with no ball.
  def balls
    [[:POKEBALL, 5], [:ULTRABALL, 2], [:GREATBALL, 3], [nil]]
  end

  # The selector's line for a ball and how many the bag holds.
  def ball(name, n)
    T.t(:dbk_ball, :name => name, :n => n)
  end

  # Runs the block with GameData answering as the v21 data does: the balls (Item.try_get, nil for any other id), the
  # names of a burn and of no status at all (Status) and of Thunderbolt (Move); taken away again after.
  def with_game_data
    made = !Object.const_defined?(:GameData)
    Object.const_set(:GameData, Module.new) if made
    had = [:Item, :Status, :Move].map do |n|
      [n, GameData.const_defined?(n, false) ? GameData.send(:remove_const, n) : nil]
    end
    item = Struct.new(:name, :description)
    named = Struct.new(:name)
    names = { :NONE => "Ninguno", :BURN => "Quemado", :THUNDERBOLT => "Rayo" }
    finder = Class.new { define_singleton_method(:try_get) { |id| BALLS[id] && item.new(*BALLS[id]) } }
    GameData.const_set(:Item, finder)
    [:Status, :Move].each do |n|
      GameData.const_set(n, Class.new { define_singleton_method(:get) { |id| named.new(names[id]) } })
    end
    yield
  ensure
    (had || []).each do |n, k|
      GameData.send(:remove_const, n) if GameData.const_defined?(n, false)
      GameData.const_set(n, k) if k
    end
    Object.send(:remove_const, :GameData) if made && Object.const_defined?(:GameData)
  end

  # Runs the block with the battler effect Illusion named, as gen-6's PBEffects lacks it; taken away again after.
  def with_illusion_effect
    made = !PBEffects.const_defined?(:Illusion, false)
    PBEffects.const_set(:Illusion, 42) if made
    yield
  ensure
    PBEffects.send(:remove_const, :Illusion) if made
  end

  # The battle the grid and panels read: on turn 3, the player Rojo's battlers against the Rival's.
  def battle_state
    @battle_state ||= Class.new do
      attr_accessor :mine, :theirs
      def turnCount; 2; end
      def pbGetOwnerName(index); index.odd? ? "Rival" : "Rojo"; end
      def pbGetOwnerFromBattlerIndex(index); Struct.new(:name).new(pbGetOwnerName(index)); end
      def allSameSideBattlers; mine; end
      def allOtherSideBattlers; theirs; end
    end.new
  end

  # The player's level-42 Sparky at 30 of 60 hp, with its ability and item; on its own side it shows as itself.
  def sparky
    Fighter.new("Sparky", 0, 42, 30, 60, Mon.new("Sparky", 0), Mon.new("Ditto", 1), battle_state,
                "Electricidad Estática", "Baya Zidra", true)
  end

  # The rival's nearer battler, shown under Illusion as another Pokemon.
  def foe_near
    Fighter.new("Cercano", 1, 42, 30, 60, Mon.new("Cercano", 1), Mon.new("Disfraz", 1), battle_state, "Intimidación",
                "Restos", false)
  end

  # The rival's farther battler, of no sex.
  def foe_far
    Fighter.new("Lejano", 3, 40, 60, 60, Mon.new("Lejano", 2), Mon.new("Lejano", 2), battle_state, "Presión", nil,
                false)
  end

  # A raid boss on the rival's side, as a kit with raid battles flags it: a male Jefe at half HP.
  def raid_boss
    boss = Fighter.new("Jefe", 1, 70, 300, 600, Mon.new("Jefe", 0), Mon.new("Jefe", 0), battle_state, "Presión")
    def boss.isRaidBoss?; true; end
    boss
  end

  # Gives the scene the battle, with Sparky on the player's side and the given battlers on the other, in field order.
  def in_battle(scene, theirs)
    battle_state.mine = [sparky]
    battle_state.theirs = theirs
    scene.instance_variable_set(:@battle, battle_state)
  end

  # The battler panel's summary of Sparky: everything the panel shows for the player's own battler.
  def sparky_summary
    ["Sparky", "♂", T.t(:dbk_trainer, :name => "Rojo"), T.t(:dbk_turn, :n => 3), T.t(:dbk_level, :n => 42),
     T.t(:dbk_hp, :hp => 30, :tot => 60), T.t(:dbk_ability, :a => "Electricidad Estática"),
     T.t(:dbk_item, :i => "Baya Zidra")].join(", ")
  end

  # The effects the battler panel lists: [name, tick, description], the last as the kit lists Terastallization, with
  # no tick at all.
  def effects
    [["Drenadoras", "3", "Roba PS cada turno"], ["Tóxico", "--", "Daño creciente"], ["Rocas Afiladas", "--", ""],
     ["Teracristalización", "", "El Pokémon está Teracristalizado al tipo Fuego."]]
  end

  # The scene with its overlay showing the battler panel.
  def info_panel(scene)
    scene.instance_variable_set(:@enhancedUIToggle, :battler)
    scene
  end

  # The scene with its overlay showing the move panel.
  def move_panel(scene)
    scene.instance_variable_set(:@enhancedUIToggle, :move)
    scene
  end

  # The fight menu's cursor on move idx, with no mechanic staged.
  def cursor(idx)
    Struct.new(:index, :mode).new(idx, 0)
  end

  # Sparky with Thunderbolt (90 power, 100 accuracy, physical) and Baton Pass (status, never misses).
  def fighter
    battler = sparky
    battler.moves = [Move.new("Rayo", 90, 100, 0), Move.new("Cambio", 0, 0, 2)]
    battler
  end

  # The move panel's line for Thunderbolt from the move data: name, category, power and accuracy.
  def bolt_line
    ["Rayo", T.t(:cat_physical), T.t(:mv_power, :p => "90"), T.t(:mv_acc, :a => 100)].join(", ")
  end

  # Runs the block with the move panel's reading state starting as an opening, then puts back what it held.
  def with_panel_state
    bs = PokeAccess::BattleScene
    saved = [:@panel_shut, :@heard, :@fight_line].map { |v| [v, bs.instance_variable_get(v)] }
    bs.instance_variable_set(:@fight_line, nil)
    bs.instance_variable_set(:@heard, nil)
    bs.panel_shut
    yield
  ensure
    saved.each { |v, value| bs.instance_variable_set(v, value) }
  end

  # Runs the block with the stand-ins under their game names (top-level name => class) and the hook chains bound to
  # them at load attached, then takes both away, putting back whatever held those names and chains before.
  def attached(stand_ins, bound)
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    held = bound.keys.select { |k| chains.key?(k) }.map { |k| [k, chains[k]] }
    chains.update(bound)
    priors = stand_ins.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
    stand_ins.each { |n, k| Object.const_set(n, k) }
    yield
  ensure
    stand_ins.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    (priors || []).each { |n, k| Object.const_set(n, k) if k }
    bound.each_key { |k| chains.delete(k) }
    (held || []).each { |k, v| chains[k] = v }
  end

  class << self
    private

    # Evaluates the mod files at rels, read as the harness reads them, over the stand-ins set for the moment under
    # their game names (top-level name => class), and answers the hook chains bound to them, to attach per test; all
    # else the evaluation changed (the names, other chains, function bodies, overrides, the missing list, the battle
    # marks and singletons) is put back as it was.
    def bind(stand_ins, rels)
      hooks = PokeAccess::Hooks
      chains = hooks.instance_variable_get(:@chains)
      chains_was = {}
      chains.each { |k, v| chains_was[k] = v.dup }
      bodies_was = {}
      hooks.fn_bodies.each { |k, v| bodies_was[k] = v.dup }
      overrides = hooks.overrides.length
      missing = hooks.missing.dup
      marks = PokeAccess::Battle::ICON_MARKS.dup
      singletons = [:shown_sex, :shown_level].map { |n| [n, PokeAccess::Battle.method(n)] }
      ours = lambda { |key| stand_ins.keys.any? { |n| key.start_with?("#{n}#", "#{n}::") } }
      chains.delete_if { |k, _v| ours.call(k) }
      priors = stand_ins.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
      stand_ins.each { |n, k| Object.const_set(n, k) }
      verbose = $VERBOSE
      $VERBOSE = nil
      rels.each do |rel|
        path = File.join(Harness::ROOT, rel)
        eval(Harness.source(path), TOPLEVEL_BINDING, path)
      end
      chains.select { |k, _v| ours.call(k) }
    ensure
      $VERBOSE = verbose
      stand_ins.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
      (priors || []).each { |n, k| Object.const_set(n, k) if k }
      (chains.keys - chains_was.keys).each do |key|
        cname, meth = key.split("#", 2)
        k = PokeAccess.const_at(cname)
        orig = "#{meth}__pa_orig_#{cname.gsub(/[^a-zA-Z0-9]/, '_')}"
        unwrap = !ours.call(key) && k.is_a?(Module) && (k.method_defined?(orig) || k.private_method_defined?(orig))
        k.send(:alias_method, meth, orig) if unwrap
        chains.delete(key)
      end
      chains_was.each { |k, v| chains[k] = v }
      bodies = hooks.fn_bodies
      bodies.keys.each { |k| bodies_was.key?(k) ? bodies[k].replace(bodies_was[k]) : bodies.delete(k) }
      hooks.overrides.slice!(overrides..-1)
      hooks.missing.replace(missing)
      PokeAccess::Battle::ICON_MARKS.replace(marks)
      singletons.each { |n, m| PokeAccess::Battle.define_singleton_method(n, m) }
    end
  end

  # The kit's hook chains on the stand-ins, bound once as this file loads: evaluating a file again starts its coverage
  # afresh, so binding before any test lets every test's reading count.
  BOUND = bind({ :Battle => Kit }, ["plugins/dbk_battle.rb", "plugins/dbk_enhanced_ui.rb"])
end
