# What the v19 battle scene (Fire Ash) draws only as graphics: the ability splash (an ability, or a passive passed as
# a String) and the ZUD fight-menu button (@chosen_button). The classes are made here, battle_g6 replayed over them.

def v19_replay_battle_g6
  verbose = $VERBOSE
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "core", "battle", "gen6", "battle_g6.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

V19Move = Struct.new(:id, :name, :type, :pp, :totalpp)

# A battler with the two names the reader asks for and a move list the ZUD toggle can rename.
class V19Battler
  attr_accessor :moves
  def initialize(name, ability); @name = name; @ability = ability; @moves = []; end
  def pbThis; @name; end
  def abilityName; @ability; end
end

# One stand-in for both splash shapes, bound once: a second replay would stack another hook body on the first.
class V19SplashScene
  def initialize; @sprites = { "abilityBar_1" => Object.new, "ability2Bar_1" => Object.new }; end
  def pbShowAbilitySplash(_battler, _arg = nil, _name = nil); :shown; end
end

def v19_splash_scene
  Object.const_set(:PokeBattle_SceneConstants, Module.new) unless Object.const_defined?(:PokeBattle_SceneConstants)
  PokeBattle_SceneConstants.const_set(:USE_ABILITY_SPLASH, true) unless PokeBattle_SceneConstants.const_defined?(:USE_ABILITY_SPLASH)
  Object.const_set(:PokeBattle_Scene, V19SplashScene)
  unless $v19_splash_bound
    v19_replay_battle_g6
    $v19_splash_bound = true
  end
  yield
ensure
  Object.send(:remove_const, :PokeBattle_Scene) if Object.const_defined?(:PokeBattle_Scene)
  Object.send(:remove_const, :PokeBattle_SceneConstants) if Object.const_defined?(:PokeBattle_SceneConstants)
end

Suite.define("v19 battle: the ability splash names the ability, or the passive it was given") do
  v19_splash_scene do
    scene = PokeBattle_Scene.new
    foe = V19Battler.new("El Charizard rival", "Mar Llamas")

    eq "the splash keeps its own return", scene.pbShowAbilitySplash(foe), :shown
    eq "the battler and its ability, queued", SpeakCapture.log,
       [[PokeAccess::I18n.t(:bt_ability, :name => "El Charizard rival", :ability => "Mar Llamas"), false]]

    SpeakCapture.clear
    scene.pbShowAbilitySplash(foe, "Curacion Activa")
    eq "a passive passed as text is what the bar shows, so it is what is said", SpeakCapture.lines,
       [PokeAccess::I18n.t(:bt_ability, :name => "El Charizard rival", :ability => "Curacion Activa")]
  end
end

# Infinite Fusion's double abilities give the same method another shape, (battler, secondAbility,
# abilityName): a fusion shows a splash for each of its two abilities, and a name passed in stays on the bar.
Suite.define("v19 battle: Infinite Fusion's double-ability splash names what its bar shows") do
  t = PokeAccess::I18n
  v19_splash_scene do
    scene = PokeBattle_Scene.new
    foe = V19Battler.new("La fusion rival", "Espesura")
    def foe.index; 1; end
    def foe.ability2Name; "Baba"; end

    scene.pbShowAbilitySplash(foe)
    scene.pbShowAbilitySplash(foe, true)
    scene.pbShowAbilitySplash(foe, false, "Viscosidad")
    eq "the first ability, the second when asked for, and a name passed in", SpeakCapture.lines,
       %w[Espesura Baba Viscosidad].map { |a| t.t(:bt_ability, :name => "La fusion rival", :ability => a) }

    SpeakCapture.clear
    scene.instance_variable_get(:@sprites)["abilityBar_1"].instance_variable_set(:@ability_name, "Viscosidad")
    scene.pbShowAbilitySplash(foe)
    eq "a name the bar kept from an earlier call is the one it shows again", SpeakCapture.lines,
       [t.t(:bt_ability, :name => "La fusion rival", :ability => "Viscosidad")]
  end
end

Suite.define("v19 battle: the ZUD button says which mechanic it toggles and rereads the renamed move") do
  begin
    zud = Class.new do
      const_set(:NoButton, -1)
      const_set(:MegaButton, 0)
      const_set(:UltraBurstButton, 1)
      const_set(:ZMoveButton, 2)
      const_set(:DynamaxButton, 3)
      attr_accessor :chosen_button
      def initialize; @index = 0; @mode = 0; @battler = nil; @chosen_button = -1; end
      def mode=(v); @mode = v; end
      def index=(v); @index = v; end
      def battler=(b); @battler = b; end
    end
    Object.const_set(:FightMenuDisplay, zud)
    v19_replay_battle_g6

    user = V19Battler.new("Pikachu", "Electricidad Estatica")
    user.moves = [V19Move.new(1, "Rayo", 13, 15, 15)]
    menu = FightMenuDisplay.new
    menu.battler = user
    menu.chosen_button = FightMenuDisplay::ZMoveButton
    menu.mode = 1

    SpeakCapture.clear
    user.moves = [V19Move.new(1, "Gigavoltio Destructor", 13, 1, 1)]
    menu.mode = 2
    lines = SpeakCapture.lines
    eq "a Z-move toggle is named for the Z-move", lines[0],
       PokeAccess::I18n.t(:bt_special_on, :name => PokeAccess::I18n.t(:bt_m_zmove))
    match "then the focused move is read again under its new name", lines[1].to_s, /Gigavoltio Destructor/

    SpeakCapture.clear
    menu.chosen_button = FightMenuDisplay::DynamaxButton
    menu.mode = 1
    eq "a dynamax toggle off is named for dynamax", SpeakCapture.lines[0],
       PokeAccess::I18n.t(:bt_special_off, :name => PokeAccess::I18n.t(:bt_m_dynamax))

    SpeakCapture.clear
    menu.chosen_button = FightMenuDisplay::MegaButton
    menu.mode = 2
    eq "the mega button keeps its own line and rereads nothing", SpeakCapture.lines,
       [PokeAccess::I18n.t(:bt_mega_on)]
  ensure
    Object.send(:remove_const, :FightMenuDisplay) if Object.const_defined?(:FightMenuDisplay)
  end
end

# Fire Ash's battlefields (fieldEffect): a trainer's rules can open a battle on one with no message, only a
# backdrop, so the field it opens on is said.
Suite.define("v19 battle: the battlefield a battle opens on is said once, and the field key names it") do
  t = PokeAccess::I18n
  made = !Object.const_defined?(:GameData)
  begin
    Object.const_set(:GameData, Module.new) if made
    fe_mod = Module.new
    def fe_mod.try_get(id); Struct.new(:name).new("Campo de fuego #{id}"); end
    GameData.const_set(:BattleFieldEffect, fe_mod)
    battle = Struct.new(:fieldEffect).new(:Fire)
    PokeAccess::Battle.announce_opening_field(battle)
    eq "the opening field, queued", SpeakCapture.log, [[t.t(:bt_field_effect, :f => "Campo de fuego Fire"), false]]
    SpeakCapture.clear
    PokeAccess::Battle.announce_opening_field(battle)
    silent "and only once per battle"
    plain = Struct.new(:fieldEffect).new(:None)
    PokeAccess::Battle.announce_opening_field(plain)
    silent "a plain field says nothing"
  ensure
    GameData.send(:remove_const, :BattleFieldEffect) if GameData.const_defined?(:BattleFieldEffect)
    Object.send(:remove_const, :GameData) if made
  end
end
