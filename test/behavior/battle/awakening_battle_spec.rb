# Awakening's own battle screens, driven through the profile's hooks: the G stats screen (CheckStatsInBattle::Show,
# which paints its picker or its sheet on every repaint), the impulse meters and button, and route D's cursed-energy
# gem. The stats screen's class is Awakening's alone and stands in for the whole run; the fight menu and the scene
# take the shared names only while a suite runs, and the hooks bind to them once.
module CheckStatsInBattle
  # Paints as draw_information does: the picker's names, or the sheet's rows in their order (the first nine effects).
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
      rows = ["PS: #{p.hp}/#{p.totalhp}", p.name, "Nv. #{p.level}", "Turno: 3"] + LABELS
      rows += ["Habilidad:", p.ability, "Objeto:", p.item, "Último movimiento: ", p.last_move, "Efectos de combate:"]
      rows + (@activef.values + (@actives[@position % 2] || {}).values + (@activep[@position] || {}).values).first(9)
    end

    def checkLevelCritical(p); p.crit; end
  end
end

module AwkBattleSpec
  Mon = Struct.new(:name, :hp, :totalhp, :level, :status, :stages, :crit, :ability, :item, :last_move, :type1, :type2)

  # A battler under Forest's Curse: its battle types carry a third one, which the sheet does not paint.
  class Mon
    def pbTypes(_type3 = false); [type1, type2, 12].uniq; end
  end

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

  STATS = { :ATTACK => 1, :DEFENSE => 2, :SPEED => 3, :SPATK => 4, :SPDEF => 5, :ACCURACY => 6, :EVASION => 7 }

  # Runs the block with PBStats' ids and the sheet's switches for the rival's rows in place, taken back after.
  def self.with_stats
    added = STATS.keys.reject { |k| PBStats.const_defined?(k) }
    added.each { |k| PBStats.const_set(k, STATS[k]) }
    made = !Object.const_defined?(:PokeBattle_SceneConstants)
    Object.const_set(:PokeBattle_SceneConstants, Module.new) if made
    shown = [:MOSTRAR_PS_RIVAL, :MOSTRAR_HABILIDAD_RIVAL, :MOSTRAR_OBJETO_RIVAL].reject { |c| PokeBattle_SceneConstants.const_defined?(c) }
    shown.each { |c| PokeBattle_SceneConstants.const_set(c, true) }
    yield
  ensure
    added.each { |k| PBStats.send(:remove_const, k) }
    shown.each { |c| PokeBattle_SceneConstants.send(:remove_const, c) } unless made
    Object.send(:remove_const, :PokeBattle_SceneConstants) if made && Object.const_defined?(:PokeBattle_SceneConstants)
  end

  # Runs the block with the stand-ins under the scene's and the fight menu's names, the HUD file loaded over them once.
  def self.with_hud
    made = [[:FightMenuDisplay, Fight], [:PokeBattle_Scene, Scene]].reject { |n, _k| Object.const_defined?(n) }
    made.each { |n, k| Object.const_set(n, k) }
    unless @hud_loaded
      @hud_loaded = true
      load File.expand_path("../../../games/awakening/battle_hud.rb", File.dirname(__FILE__))
    end
    yield
  ensure
    made.each { |n, _k| Object.send(:remove_const, n) if Object.const_defined?(n) }
  end

  # A battle with a player (and a foe trainer) holding the given impulses, and the given battlers.
  def self.battle(mine, foes = nil, battlers = [])
    trainer = Struct.new(:impulses)
    b = Object.new
    b.instance_variable_set(:@p, trainer.new(mine))
    b.instance_variable_set(:@o, foes.nil? ? nil : trainer.new(foes))
    b.instance_variable_set(:@b, battlers)
    def b.player; @p; end
    def b.opponent; @o; end
    def b.battlers; @b; end
    b
  end
end

load File.expand_path("../../../games/awakening/battle_info.rb", File.dirname(__FILE__))

Suite.define("awakening stats screen: the picker's battler, then its sheet with the icons, and again on each move") do
  t = PokeAccess::I18n
  AwkBattleSpec.with_stats do
    stages = [0, 2, 0, 0, 0, 0, 0, -1]
    pika = AwkBattleSpec::Mon.new("Pikachu", 120, 150, 30, 3, stages, 1, "Electricidad Estática", "---", "Placaje", 13, 13)
    foe = AwkBattleSpec::Mon.new("Groudon", 300, 300, 60, 0, [0] * 8, 0, "Sequía", "Restos", "---", 4, 10)
    active = { :field => { "Clima" => "Clima soleado (3)" }, :sides => [{ "Reflejo" => "Reflejo (3)" }, {}],
               :own => [{ "1" => "Confuso" }, {}] }
    s = CheckStatsInBattle::Show.new([pika, foe], active)
    eq "the repaint runs as the game's own", s.draw_information, :drawn
    eq "opening: the picker's focused battler", SpeakCapture.lines, ["Pikachu"]
    SpeakCapture.clear
    s.draw_information
    silent "a repaint with nothing moved says nothing"
    s.instance_variable_set(:@position, 1)
    s.draw_information
    eq "a rival's place is said as the rival's", SpeakCapture.lines, [t.t(:awk_binfo_foe, :name => "Groudon")]
    SpeakCapture.clear
    s.instance_variable_set(:@position, 0)
    s.instance_variable_set(:@chose, true)
    s.draw_information
    heads = ["Pikachu", "Nv. 30", "PS: 120/150", t.t(:st_burn), "Tipo13", "Turno: 3"].join(", ")
    eq "the sheet: its painted rows, the status and its one type icon, the stages and every effect", SpeakCapture.lines,
       ["#{heads}. Ataque +2, Evasión -1, Crítico +1. Habilidad: Electricidad Estática. " \
        "Objeto: #{t.t(:awk_binfo_none)}. Último movimiento: Placaje. " \
        "Efectos de combate: Clima soleado (3), Reflejo (3), Confuso"]
    SpeakCapture.clear
    s.instance_variable_set(:@position, 1)
    s.draw_information
    heads = ["Groudon", "Nv. 60", "PS: 300/300", "Tipo4 Tipo10", "Turno: 3"].join(", ")
    eq "right to the rival: its whole sheet with both type icons, no stage moved said so", SpeakCapture.lines,
       ["#{heads}. #{t.t(:awk_binfo_no_stages)}. Habilidad: Sequía. Objeto: Restos. " \
        "Último movimiento: #{t.t(:awk_binfo_none)}. Efectos de combate: Clima soleado (3)"]
  end
end

Suite.define("awakening impulses: the meter with the HP key, and the fight menu's F button") do
  t = PokeAccess::I18n
  AwkBattleSpec.with_hud do
    battle = AwkBattleSpec.battle(3, 2)
    PokeAccess::Battle.set_battle(battle)
    PokeAccess::Battle.announce_hp(false)
    eq "the player's side, then its meter", SpeakCapture.lines,
       [t.t(:bt_no_pokemon), t.t(:awk_impulses, :n => 3, :max => 5)]
    SpeakCapture.clear
    PokeAccess::Battle.announce_hp(true)
    eq "the foe's meter is drawn only with variable 150 above 0", SpeakCapture.lines, [t.t(:bt_no_pokemon)]
    SpeakCapture.clear
    $game_variables[150] = 1
    PokeAccess::Battle.announce_hp(true)
    eq "and then it is said", SpeakCapture.lines, [t.t(:bt_no_pokemon), t.t(:awk_impulses_foe, :n => 2, :max => 5)]

    battler = Object.new
    battler.instance_variable_set(:@battle, AwkBattleSpec.battle(5))
    def battler.battle; @battle; end
    disp = FightMenuDisplay.new(battler)
    SpeakCapture.clear
    disp.impulseButton = 0
    disp.impulseButton = 1
    disp.impulseButton = 2
    disp.impulseButton = 1
    eq "a full meter: ready with its key, then on and off with F", SpeakCapture.lines,
       ["#{t.t(:awk_impulse_ready)}. #{t.t(:awk_impulse_key)}", t.t(:awk_impulse_on), t.t(:awk_impulse_off)]
    battler.instance_variable_set(:@battle, AwkBattleSpec.battle(4))
    SpeakCapture.clear
    disp.impulseButton = 0
    disp.impulseButton = 1
    silent "the button comes up every turn, but short of five nothing is ready"
  end
end

Suite.define("awakening cursed gem: said as the command menu opens when it changes picture, full with its key") do
  t = PokeAccess::I18n
  AwkBattleSpec.with_hud do
    scene = PokeBattle_Scene.new(AwkBattleSpec.battle(0))
    $game_variables[399] = 30
    eq "the command menu runs as the game's own", scene.pbCommandMenuEx(0, []), :command
    silent "without route D's switch there is no gem"
    $game_switches[650] = true
    scene.pbCommandMenuEx(0, [])
    eq "the energy, queued", SpeakCapture.log, [[t.t(:awk_energy, :n => 30), false]]
    SpeakCapture.clear
    $game_variables[399] = 40
    scene.pbCommandMenuEx(0, [])
    silent "the same picture (26 to 50) is not said again"
    $game_variables[399] = 100
    scene.pbCommandMenuEx(0, [])
    eq "the full gem: the talisman ready and its key", SpeakCapture.lines,
       ["#{t.t(:awk_energy, :n => 100)}. #{t.t(:awk_gem_ready)}. #{t.t(:awk_gem_key)}"]
    SpeakCapture.clear
    PokeBattle_Scene.new(AwkBattleSpec.battle(0)).pbCommandMenuEx(0, [])
    spoke "a new battle says it again", /#{Regexp.escape(t.t(:awk_gem_ready))}/
  end
end
