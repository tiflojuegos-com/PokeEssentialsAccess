# Awakening's battle screens through its profile's hooks: the G stats screen's picker and sheet, the impulse meters on
# the HP key, the fight menu's impulse button and the impulse moves' picker caption, and route D's cursed-energy gem
# as the command menu opens.

# The game's stats screen, painting as draw_information does: the picker's names, or the sheet's rows in their order,
# a rival's optional rows only when the game's switch for each is on; the hook binds to it by name.
module CheckStatsInBattle
  class Show
    LABELS = ["Ataque", "Defensa", "At. Esp.", "Def. Esp.", "Velocidad", "Precisión", "Evasión", "Crítico"]

    def initialize(pkmn, active = {})
      @pkmn = pkmn
      @position = 0
      @chose = false
      @activef = active[:field] || {}
      @actives = active[:sides] || [{}, {}]
      @activep = active[:own] || []
    end

    def draw_information
      rows = @chose ? sheet_rows(@pkmn[@position]) : @pkmn.compact.map { |p| p.name }
      pbDrawTextPositions(nil, rows.map { |t| [t, 0, 0, 0] })
      :drawn
    end

    def sheet_rows(p)
      return [] unless p
      rows = shows?(:MOSTRAR_PS_RIVAL) ? ["PS: #{p.hp}/#{p.totalhp}"] : []
      rows += [p.name, "Nv. #{p.level}", "Turno: 3"] + LABELS
      rows += ["Habilidad:", p.ability] if shows?(:MOSTRAR_HABILIDAD_RIVAL)
      rows += ["Objeto:", p.item] if shows?(:MOSTRAR_OBJETO_RIVAL)
      rows += ["Último movimiento: ", p.last_move, "Efectos de combate:"]
      rows + (@activef.values + (@actives[@position % 2] || {}).values + (@activep[@position] || {}).values).first(9)
    end

    def shows?(switch)
      PokeBattle_SceneConstants.const_get(switch) || @position % 2 == 0
    end

    def checkLevelCritical(p); p.crit; end
  end
end

# The impulse moves whose third level opens a picker of their own: a caption over a command list, the pick returned.
%w[PokeBattle_Move_250 PokeBattle_Move_309 PokeBattle_Move_312].each do |name|
  Object.const_set(name, Class.new { def pbMessage(_msg, _commands); 1; end }) unless Object.const_defined?(name)
end

class AwakeningBattleTest < PokeAccessTest
  INFO = File.join(Harness::ROOT, "games", "awakening", "battle_info.rb")
  HUD = File.join(Harness::ROOT, "games", "awakening", "battle_hud.rb")

  # PBStats' ids for the stats whose stage icons the sheet paints.
  STATS = { :ATTACK => 1, :DEFENSE => 2, :SPEED => 3, :SPATK => 4, :SPDEF => 5, :ACCURACY => 6, :EVASION => 7 }

  # The game's switches that paint a rival's hit points, ability and item on its sheet.
  RIVAL_ROWS = [:MOSTRAR_PS_RIVAL, :MOSTRAR_HABILIDAD_RIVAL, :MOSTRAR_OBJETO_RIVAL]

  # Pikachu's stage icons as its sheet says them.
  STAGES = "Ataque +2, Defensa +1, Evasión -1, Crítico +1"

  # A battler as the sheet reads it, under Forest's Curse: its battle types carry a third one the sheet does not
  # paint. effects holds the Pokemon an Illusion shows, under PBEffects::Illusion.
  Mon = Struct.new(:name, :hp, :totalhp, :level, :status, :stages, :crit, :ability, :item, :last_move, :type1,
                   :type2, :effects) do
    def pbTypes(_type3 = false); [type1, type2, 12].uniq; end
  end

  # A disguise's types, as an Illusion shows them.
  Disguise = Struct.new(:type1, :type2)

  # The fight menu as the scene sets it each turn: impulseButton= after the battler.
  class Fight
    attr_reader :battler
    def initialize(battler); @battler = battler; end
    def impulseButton=(v); @impulseButton = v; end
  end

  # The scene's command menu, which paints the gem as it opens.
  class Scene
    def initialize(battle); @battle = battle; end
    def pbCommandMenuEx(_index, _texts, _mode = 0); :command; end
  end

  # A trainer with its impulse meter, the battle the HP key and the fight menu read, and a battler's tie to it.
  Trainer = Struct.new(:impulses)
  TrainerBattle = Struct.new(:player, :opponent, :battlers)
  Owner = Struct.new(:battle)

  class << self
    # Evaluates battle_info.rb once; its hook binds to CheckStatsInBattle::Show by name.
    def load_stats_screen
      return if @stats_loaded
      @stats_loaded = true
      eval(Harness.source(INFO), TOPLEVEL_BINDING, INFO)
    end

    # The HP key as battle_hud.rb overrides it, the file evaluated once over the stand-ins, whose hooks bind by name;
    # the HP key itself is left as it was.
    def hud_announce_hp
      @hud_announce_hp ||= begin
        core = PokeAccess::Battle.method(:announce_hp)
        eval(Harness.source(HUD), TOPLEVEL_BINDING, HUD)
        PokeAccess::Battle.method(:announce_hp)
      ensure
        PokeAccess::Battle.define_singleton_method(:announce_hp, core) if core
      end
    end
  end

  test "opening the picker says its focused battler" do
    with_stats do
      stats_screen.draw_information
      assert_equal [["Pikachu", true]], SpeakCapture.log
    end
  end

  test "a repaint with nothing moved says nothing" do
    with_stats do
      s = stats_screen
      s.draw_information
      SpeakCapture.clear
      s.draw_information
      assert_nothing_spoken
    end
  end

  test "a repaint answers what the game's own answers, on the picker and on the sheet" do
    with_stats do
      s = stats_screen
      assert_equal :drawn, s.draw_information, "the picker"
      s.instance_variable_set(:@chose, true)
      assert_equal :drawn, s.draw_information, "the sheet"
    end
  end

  test "a rival's place in the picker is said as the rival's" do
    with_stats do
      s = stats_screen
      s.draw_information
      SpeakCapture.clear
      s.instance_variable_set(:@position, 1)
      s.draw_information
      assert_equal [[t(:awk_binfo_foe, :name => "Groudon"), true]], SpeakCapture.log
    end
  end

  test "a place in the picker with no battler says nothing" do
    with_stats do
      s = CheckStatsInBattle::Show.new([pikachu, nil])
      s.draw_information
      SpeakCapture.clear
      s.instance_variable_set(:@position, 1)
      s.draw_information
      assert_nothing_spoken
    end
  end

  test "the player's sheet says its rows, its status and type icons, the stages it paints and every effect" do
    with_stats do
      assert_equal [[pikachu_sheet("Tipo13", "Clima soleado (3), Reflejo (3), Confuso"), true]],
                   sheet_at(stats_screen, 0)
    end
  end

  test "a rival's sheet says both its type icons, and that no stage moved" do
    with_stats do
      assert_equal [[groudon_sheet("Clima soleado (3)"), true]], sheet_at(stats_screen, 1)
    end
  end

  test "with the game's switches off a rival's sheet has no hit points, ability or item" do
    with_stats(false) do
      heads = ["Groudon", "Nv. 60", "Tipo4 Tipo10", "Turno: 3"].join(", ")
      line = "#{heads}. #{t(:awk_binfo_no_stages)}. Último movimiento: #{t(:awk_binfo_none)}. " \
             "Efectos de combate: Clima soleado (3)"
      assert_equal [[line, true]], sheet_at(stats_screen, 1)
    end
  end

  test "with the game's switches off the player's sheet still says its hit points, ability and item" do
    with_stats(false) do
      assert_equal [[pikachu_sheet("Tipo13", "Clima soleado (3), Reflejo (3), Confuso"), true]],
                   sheet_at(stats_screen, 0)
    end
  end

  test "the second battler of each side has its side's effects said" do
    with_stats do
      active = { :field => { "Clima" => "Clima soleado (3)" },
                 :sides => [{ "Reflejo" => "Reflejo (3)" }, { "Velo" => "Velo Aurora (5)" }] }
      screen = CheckStatsInBattle::Show.new([pikachu, groudon, pikachu, groudon], active)
      assert_equal [[pikachu_sheet("Tipo13", "Clima soleado (3), Reflejo (3)"), true]], sheet_at(screen, 2), "the partner"
      assert_equal [[groudon_sheet("Clima soleado (3), Velo Aurora (5)"), true]], sheet_at(screen, 3), "the rival's second"
    end
  end

  test "a battler with no effect on says none after the effects heading" do
    with_stats do
      assert_equal [[pikachu_sheet("Tipo13", t(:awk_binfo_none)), true]],
                   sheet_at(CheckStatsInBattle::Show.new([pikachu]), 0)
    end
  end

  test "under Illusion the sheet paints the disguise's type icons" do
    with_illusion do
      mon = pikachu
      mon.effects = { PBEffects::Illusion => Disguise.new(4, 10) }
      with_stats do
        assert_equal [[pikachu_sheet("Tipo4 Tipo10", t(:awk_binfo_none)), true]],
                     sheet_at(CheckStatsInBattle::Show.new([mon]), 0)
      end
    end
  end

  test "a critical-hit level the screen cannot tell leaves its row out" do
    with_stats do
      mon = pikachu
      mon.define_singleton_method(:crit) { raise "boom" }
      assert_equal [[pikachu_sheet("Tipo13", t(:awk_binfo_none), "Ataque +2, Defensa +1, Evasión -1"), true]],
                   sheet_at(CheckStatsInBattle::Show.new([mon]), 0)
    end
  end

  test "a status with no name is left out" do
    with_stats do
      mon = pikachu
      mon.status = 9
      assert_equal [[pikachu_sheet("Tipo13", t(:awk_binfo_none), STAGES, nil), true]],
                   sheet_at(CheckStatsInBattle::Show.new([mon]), 0)
    end
  end

  test "a battler with no type says no type" do
    with_stats do
      mon = pikachu
      mon.type1 = mon.type2 = nil
      assert_equal [[pikachu_sheet(nil, t(:awk_binfo_none)), true]], sheet_at(CheckStatsInBattle::Show.new([mon]), 0)
    end
  end

  test "a type the game has no name for is left out" do
    blank = Object.new
    def blank.type_name(_type); ""; end
    with_stats do
      Harness.with_provider(blank, 30) do
        assert_equal [[pikachu_sheet(nil, t(:awk_binfo_none)), true]],
                     sheet_at(CheckStatsInBattle::Show.new([pikachu]), 0)
      end
    end
  end

  test "a blank effect is left out" do
    with_stats do
      screen = CheckStatsInBattle::Show.new([pikachu], :own => [{ "1" => "Confuso", "2" => "" }])
      assert_equal [[pikachu_sheet("Tipo13", "Confuso"), true]], sheet_at(screen, 0)
    end
  end

  test "a sheet open on a place with no battler says nothing" do
    with_stats do
      assert_equal [], sheet_at(CheckStatsInBattle::Show.new([pikachu, nil]), 1)
    end
  end

  test "a sheet the game fails to paint says nothing" do
    with_stats do
      mon = pikachu
      mon.define_singleton_method(:hp) { raise "boom" }
      screen = CheckStatsInBattle::Show.new([mon])
      screen.instance_variable_set(:@chose, true)
      assert_raises(RuntimeError) { screen.draw_information }
      assert_nothing_spoken
    end
  end

  test "the HP key says the player's side, then its impulse meter, queued" do
    with_hud do
      PokeAccess::Battle.set_battle(trainer_battle(3, 2))
      PokeAccess::Battle.announce_hp(false)
      assert_equal [[t(:bt_no_pokemon), true], [t(:awk_impulses, :n => 3, :max => 5), false]], SpeakCapture.log
    end
  end

  test "the foe's meter is said only while variable 150 is above 0" do
    with_hud do
      PokeAccess::Battle.set_battle(trainer_battle(3, 2))
      { 0 => [[t(:bt_no_pokemon), true]],
        1 => [[t(:bt_no_pokemon), true], [t(:awk_impulses_foe, :n => 2, :max => 5), false]] }.each do |shown, log|
        $game_variables[150] = shown
        SpeakCapture.clear
        PokeAccess::Battle.announce_hp(true)
        assert_equal log, SpeakCapture.log, "with variable 150 at #{shown}"
      end
    end
  end

  test "with the game's variables unreadable the foe's meter is not said" do
    with_hud do
      PokeAccess::Battle.set_battle(trainer_battle(3, 2))
      without_global(:$game_variables) { PokeAccess::Battle.announce_hp(true) }
      assert_equal [[t(:bt_no_pokemon), true]], SpeakCapture.log
    end
  end

  test "a pair of foe trainers has each meter said" do
    with_hud do
      $game_variables[150] = 1
      PokeAccess::Battle.set_battle(trainer_battle(3, [2, 4]))
      PokeAccess::Battle.announce_hp(true)
      meters = [t(:awk_impulses_foe, :n => 2, :max => 5), t(:awk_impulses_foe, :n => 4, :max => 5)].join(", ")
      assert_equal [[t(:bt_no_pokemon), true], [meters, false]], SpeakCapture.log
    end
  end

  test "the player's meter is the first trainer's of a pair" do
    with_hud do
      PokeAccess::Battle.set_battle(trainer_battle([3, 5]))
      PokeAccess::Battle.announce_hp(false)
      assert_equal [[t(:bt_no_pokemon), true], [t(:awk_impulses, :n => 3, :max => 5), false]], SpeakCapture.log
    end
  end

  test "a side whose trainer keeps no impulses is said alone" do
    with_hud do
      PokeAccess::Battle.set_battle(trainer_battle(nil))
      PokeAccess::Battle.announce_hp(false)
      assert_equal [[t(:bt_no_pokemon), true]], SpeakCapture.log
    end
  end

  test "with no battle the HP key says the party alone, with no meter after it" do
    with_hud do
      PokeAccess::Battle.announce_hp(false)
      assert_equal [[t(:pty_none), true]], SpeakCapture.log
    end
  end

  test "a full meter says the impulse ready, with its key, as the button comes up" do
    with_hud do
      assert_equal [["#{t(:awk_impulse_ready)}. #{t(:awk_impulse_key)}", false]], press(fight_menu(5), 0, 1)
    end
  end

  test "F turns the impulse on and off" do
    with_hud do
      menu = fight_menu(5)
      press(menu, 0, 1)
      assert_equal [[t(:awk_impulse_on), true]], press(menu, 2), "on"
      assert_equal [[t(:awk_impulse_off), true]], press(menu, 1), "and off"
    end
  end

  test "short of a full meter the button coming up says nothing" do
    with_hud do
      assert_equal [], press(fight_menu(4), 0, 1)
    end
  end

  test "the button staying up says nothing more, and coming up again after it hid says ready again" do
    with_hud do
      menu = fight_menu(5)
      press(menu, 0, 1)
      assert_equal [], press(menu, 1), "staying up"
      assert_equal [["#{t(:awk_impulse_ready)}. #{t(:awk_impulse_key)}", false]], press(menu, 0, 1), "up again"
    end
  end

  test "the ready line keeps its key from the medium verbosity" do
    with_hud do
      ready = t(:awk_impulse_ready)
      lines = vb_levels { press(fight_menu(5), 0, 1).map { |text, _i| text } }
      assert_equal [[ready], ["#{ready}. #{t(:awk_impulse_key)}"], ["#{ready}. #{t(:awk_impulse_key)}"]], lines
    end
  end

  test "a fight menu with no battler reads the battle the battle hooks hold" do
    with_hud do
      PokeAccess::Battle.set_battle(trainer_battle(5))
      assert_equal [["#{t(:awk_impulse_ready)}. #{t(:awk_impulse_key)}", false]], press(Fight.new(nil), 0, 1)
    end
  end

  test "the ready line reads the first trainer's meter of a pair, and none of a trainer without one" do
    with_hud do
      { [5, 0] => [["#{t(:awk_impulse_ready)}. #{t(:awk_impulse_key)}", false]], [0, 5] => [],
        nil => [] }.each do |impulses, log|
        assert_equal log, press(fight_menu(impulses), 0, 1), "with #{impulses.inspect}"
      end
    end
  end

  test "each impulse's move picker says its caption, queued, and keeps the game's pick" do
    with_hud do
      moves = %w[PokeBattle_Move_250 PokeBattle_Move_309 PokeBattle_Move_312].map { |name| Object.const_get(name) }
      picks = moves.each_with_index.map { |move, i| move.new.pbMessage("Movimientos #{i}: ", %w[a b]) }
      assert_equal [1, 1, 1], picks
      assert_equal (0..2).map { |i| [PokeAccess.clean("Movimientos #{i}: "), false] }, SpeakCapture.log
    end
  end

  test "the command menu answers what the game's own answers" do
    with_hud do
      assert_equal :command, Scene.new(trainer_battle(0)).pbCommandMenuEx(0, [])
    end
  end

  test "without route D's switch the command menu says no gem" do
    with_hud do
      $game_variables[399] = 30
      Scene.new(trainer_battle(0)).pbCommandMenuEx(0, [])
      assert_nothing_spoken
    end
  end

  test "with the game's switches unreadable the command menu says no gem" do
    with_hud do
      $game_variables[399] = 30
      without_global(:$game_switches) { Scene.new(trainer_battle(0)).pbCommandMenuEx(0, []) }
      assert_nothing_spoken
    end
  end

  test "the gem's energy is said, queued, as the command menu opens" do
    with_hud do
      assert_equal [[t(:awk_energy, :n => 30), false]], gem_at(Scene.new(trainer_battle(0)), 30)
    end
  end

  test "the same gem picture is not said again, and a new one is" do
    with_hud do
      scene = Scene.new(trainer_battle(0))
      gem_at(scene, 30)
      assert_equal [], gem_at(scene, 40), "26 to 50 is one picture"
      assert_equal [[t(:awk_energy, :n => 60), false]], gem_at(scene, 60), "51 to 70 is the next"
    end
  end

  test "the full gem says the talisman ready, with its key" do
    with_hud do
      assert_equal [[full_gem, false]], gem_at(Scene.new(trainer_battle(0)), 100)
    end
  end

  test "a new battle says the gem again" do
    with_hud do
      gem_at(Scene.new(trainer_battle(0)), 100)
      assert_equal [[full_gem, false]], gem_at(Scene.new(trainer_battle(0)), 100)
    end
  end

  test "the gem's picture follows the energy: none, 1-25, 26-50, 51-70, 71-99 and full" do
    with_hud do
      { 0 => 0, 1 => 1, 25 => 1, 26 => 2, 50 => 2, 51 => 3, 70 => 3, 71 => 4, 99 => 4, 100 => 5,
        140 => 5 }.each do |energy, level|
        assert_equal level, PokeAccess::AwakeningBattleHud.gem_level(energy), "at #{energy}"
      end
    end
  end

  private

  # Pikachu as the stats screen shows it: burned, Attack +2, Defense +1 and Evasion -1, one critical-hit level.
  def pikachu
    Mon.new("Pikachu", 120, 150, 30, 3, [0, 2, 1, 0, 0, 0, 0, -1], 1, "Electricidad Estática", "---", "Placaje",
            13, 13)
  end

  # Groudon as the rival's battler: healthy, no stage moved.
  def groudon
    Mon.new("Groudon", 300, 300, 60, 0, [0] * 8, 0, "Sequía", "Restos", "---", 4, 10)
  end

  # Pikachu's sheet as said, with these type icons, these effects after the heading, these stage icons and this
  # status icon (nil for none).
  def pikachu_sheet(types, effects, stages = STAGES, status = t(:st_burn))
    heads = ["Pikachu", "Nv. 30", "PS: 120/150", status, types, "Turno: 3"].compact.join(", ")
    "#{heads}. #{stages}. Habilidad: Electricidad Estática. Objeto: #{t(:awk_binfo_none)}. " \
      "Último movimiento: Placaje. Efectos de combate: #{effects}"
  end

  # Groudon's sheet as said, with every rival row the game's switches paint and these effects after the heading.
  def groudon_sheet(effects)
    heads = ["Groudon", "Nv. 60", "PS: 300/300", "Tipo4 Tipo10", "Turno: 3"].join(", ")
    "#{heads}. #{t(:awk_binfo_no_stages)}. Habilidad: Sequía. Objeto: Restos. " \
      "Último movimiento: #{t(:awk_binfo_none)}. Efectos de combate: #{effects}"
  end

  # The stats screen over Pikachu and Groudon, under the sun, Reflect on the player's side and Pikachu confused.
  def stats_screen
    active = { :field => { "Clima" => "Clima soleado (3)" }, :sides => [{ "Reflejo" => "Reflejo (3)" }, {}],
               :own => [{ "1" => "Confuso" }, {}] }
    CheckStatsInBattle::Show.new([pikachu, groudon], active)
  end

  # What opening the screen's sheet on the battler at pos says, as [text, interrupt] pairs.
  def sheet_at(screen, pos)
    screen.instance_variable_set(:@position, pos)
    screen.instance_variable_set(:@chose, true)
    SpeakCapture.clear
    screen.draw_information
    SpeakCapture.log.dup
  end

  # The full gem's line: the energy, the talisman ready and its key.
  def full_gem
    "#{t(:awk_energy, :n => 100)}. #{t(:awk_gem_ready)}. #{t(:awk_gem_key)}"
  end

  # Runs the block with the stats screen hooked, PBStats' ids, and the game's switches for a rival's rows at rival_rows
  # in a PokeBattle_SceneConstants of their own; the ids and the module that stood before are put back after.
  def with_stats(rival_rows = true)
    self.class.load_stats_screen
    added = STATS.keys.reject { |k| PBStats.const_defined?(k) }
    added.each { |k| PBStats.const_set(k, STATS[k]) }
    saved = Object.send(:remove_const, :PokeBattle_SceneConstants) if Object.const_defined?(:PokeBattle_SceneConstants)
    switches = Object.const_set(:PokeBattle_SceneConstants, Module.new)
    RIVAL_ROWS.each { |c| switches.const_set(c, rival_rows) }
    yield
  ensure
    (added || []).each { |k| PBStats.send(:remove_const, k) }
    Object.send(:remove_const, :PokeBattle_SceneConstants) if switches
    Object.const_set(:PokeBattle_SceneConstants, saved) if saved
  end

  # Runs the block with PBEffects::Illusion defined, as the engines with Illusion define it.
  def with_illusion
    made = !PBEffects.const_defined?(:Illusion)
    PBEffects.const_set(:Illusion, 42) if made
    yield
  ensure
    PBEffects.send(:remove_const, :Illusion) if made
  end

  # Runs the block with one of the game's globals ($game_variables, $game_switches) unreadable, put back after.
  def without_global(name)
    saved = eval(name.to_s)
    begin
      eval("#{name} = nil")
      yield
    ensure
      eval("#{name} = saved")
    end
  end

  # Runs the block with the stand-ins under the fight menu's and the scene's names and the HP key overridden as
  # battle_hud.rb overrides it; the HP key is put back after.
  def with_hud
    core = PokeAccess::Battle.method(:announce_hp)
    made = [[:FightMenuDisplay, Fight], [:PokeBattle_Scene, Scene]].reject { |n, _k| Object.const_defined?(n) }
    made.each { |n, k| Object.const_set(n, k) }
    PokeAccess::Battle.define_singleton_method(:announce_hp, self.class.hud_announce_hp)
    yield
  ensure
    PokeAccess::Battle.define_singleton_method(:announce_hp, core)
    made.each { |n, _k| Object.send(:remove_const, n) if Object.const_defined?(n) }
  end

  # A battle whose player, and foe trainer when given, keep these impulses; an Array is a pair of trainers.
  def trainer_battle(mine, foes = nil)
    TrainerBattle.new(trainers(mine), foes.nil? ? nil : trainers(foes), [])
  end

  # A trainer keeping these impulses, or a pair of them for an Array.
  def trainers(impulses)
    impulses.is_a?(Array) ? impulses.map { |n| Trainer.new(n) } : Trainer.new(impulses)
  end

  # A fight menu whose battler's player keeps these impulses.
  def fight_menu(impulses)
    Fight.new(Owner.new(trainer_battle(impulses)))
  end

  # What setting the impulse button to each value in turn says, as [text, interrupt] pairs.
  def press(menu, *values)
    SpeakCapture.clear
    values.each { |v| menu.impulseButton = v }
    SpeakCapture.log.dup
  end

  # What opening the command menu with route D's switch on and this energy says, as [text, interrupt] pairs.
  def gem_at(scene, energy)
    $game_switches[650] = true
    $game_variables[399] = energy
    SpeakCapture.clear
    scene.pbCommandMenuEx(0, [])
    SpeakCapture.log.dup
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
