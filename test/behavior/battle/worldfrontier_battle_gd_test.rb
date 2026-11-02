# World Frontier's battle screen, gamedata pass (games/worldfrontier/battle_ui.rb): its databox with no level, a foe's
# hit points as the box rounds them, the outlined mega and Dynamax icons and the Tera one as marks, the held item's
# splash, and the key buttons beside the battle menus. The stand-ins below hold the game's names (Battle::Scene, its
# PokemonDataBox, WFItemSplashScene) only while battle_ui.rb is evaluated, so its hooks bind to them and no other test
# sees them.

# The databox's outlined icon, which World Frontier draws from a bitmap of its own instead of pbDrawImagePositions.
class WfOutlinedBox
  def wf_draw_outlined_special_icon(filename, x, y, src = nil); [filename, x, y, src]; end
end

# A battle scene with its two menu windows, the key buttons and the info panel, all hidden until shown; its databox is
# the outlined icon's.
class WfMenuScene
  PokemonDataBox = WfOutlinedBox
  Shown = Struct.new(:visible)

  def initialize
    @sprites = {}
    %w[commandWindow fightWindow button1 button3 enhancedUI].each { |k| @sprites[k] = Shown.new(false) }
  end

  # Lays the key buttons out as the game does on each menu change: "button1" by both menus, "button3" by the fight
  # menu's, none while an info panel is open.
  def wf_update_info_buttons(window = nil)
    window ||= @sprites["fightWindow"].visible ? :fight : (@sprites["commandWindow"].visible ? :command : nil)
    info = @sprites["enhancedUI"].visible
    @sprites["button1"].visible = !info && [:command, :fight].include?(window)
    @sprites["button3"].visible = !info && window == :fight
    :laid_out
  end

  # Shows that menu's window alone (nil for none), then the buttons, as pbShowWindow does.
  def show(window)
    @sprites["commandWindow"].visible = (window == :command)
    @sprites["fightWindow"].visible = (window == :fight)
    wf_update_info_buttons(window)
  end

  # Opens or closes the info panel over the menu, which lays the buttons out again.
  def info(open)
    @sprites["enhancedUI"].visible = open
    wf_update_info_buttons
  end

  def pbEndBattle(_result = nil); :ended; end
end

# The splash's scene half, prepended to the battle scene in the game.
module WfItemSplashHalf
  # Shows the bar, hiding first one still up, as the game does.
  def pbShowItemSplash(battler, item = nil)
    pbHideItemSplashSide(0) if @bar_up
    @bar_up = true
    [battler, item]
  end

  def pbHideItemSplashSide(side)
    @bar_up = false
    side
  end
end

# A battle scene with the splash.
class WfSplashScene
  include WfItemSplashHalf
end

# A battle scene with the move panel of version 1.2.0, down to the answers its icon is worked out from.
class WfPanelScene
  def initialize(value, blocked, immune); @value = value; @blocked = blocked; @immune = immune; end
  def pbMoveInfoTypeMod(_type, _foe, _move); @value; end
  def pbMoveInfoWeatherBlocksMove?(_move, _type); @blocked; end
  def pbMoveInfoAllAbilitiesImmune?(_user, _foe, _move, _type, _value); @immune; end
end

# A battler holding an item, as the splash reads it.
class WfHolder < Battle::Battler
  attr_accessor :item
end

seams = [:shown_level, :shown_hp].map { |m| [m, PokeAccess::Battle.method(m)] }
line_seams = [[PokeAccess, :say_dialogue], [PokeAccess::BattleScene, :message_shown?],
              [PokeAccess::DBKMoveInfo, :effect_index]]
core_lines = line_seams.map { |owner, m| [owner, m, owner.method(m)] }
harness_scene = Battle.send(:remove_const, :Scene)
Battle.const_set(:Scene, WfMenuScene)
Object.const_set(:WFItemSplashScene, WfItemSplashHalf)
begin
  path = File.join(Harness::ROOT, "games", "worldfrontier", "battle_ui.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  Object.send(:remove_const, :WFItemSplashScene)
  Battle.send(:remove_const, :Scene)
  Battle.const_set(:Scene, harness_scene)
end
WF_BATTLE_SEAMS = [:shown_level, :shown_hp].map { |m| [m, PokeAccess::Battle.method(m)] }
seams.each { |m, original| PokeAccess::Battle.define_singleton_method(m, original) }
WF_LINE_SEAMS = line_seams.map { |owner, m| [owner, m, owner.method(m)] }
core_lines.each { |owner, m, original| owner.define_singleton_method(m, original) }

class WorldfrontierBattleGdTest < PokeAccessTest
  I18n = PokeAccess::I18n

  test "a battler's box is said without the level it does not paint" do
    pika = Battle::Battler.new("Pikachu", 30, 60, 0)
    state = with_box { PokeAccess::Battle.battler_state(pika) }
    assert_equal I18n.t(:bt_state_nolevel, :name => "Pikachu#{PokeAccess::Battle.shown_sex(pika)}",
                                           :hp => I18n.t(:bt_hp_exact, :hp => 30, :tot => 60)), state
  end

  test "a foe's hit points are the percentage its box rounds, never 0 while it stands nor 100 while hurt" do
    assert_equal [50, 1, 99, 0, 100], [[80, 160], [1, 160], [159, 160], [0, 160], [160, 160]].map { |hp, tot| PokeAccess::WfBattleBox.percent(hp, tot) }
    onix = Battle::Battler.new("Onix", 1, 160, 1)
    assert_equal I18n.t(:bt_hp_pct, :n => 1), with_box { PokeAccess::Battle.shown_hp(onix, true) }
  end

  test "the player's own hit points stay exact" do
    pika = Battle::Battler.new("Pikachu", 1, 160, 0)
    assert_equal I18n.t(:bt_hp_exact, :hp => 1, :tot => 160), with_box { PokeAccess::Battle.shown_hp(pika, false) }
  end

  test "the outlined mega and Dynamax icons and the Tera strip count as the box's marks" do
    box = WfOutlinedBox.new
    icons = PokeAccess::PaintCapture.icons do
      box.wf_draw_outlined_special_icon("Graphics/UI/Battle/icon_mega", 4, 4)
      pbDrawImagePositions(nil, [["Graphics/Plugins/Terastallization/tera_types", 4, 4, 0, 32, 32, 32]])
    end
    assert_equal [I18n.t(:bt_mark_mega), I18n.t(:bt_m_tera)], PokeAccess::Battle.marks_of(icons)
  end

  test "the item splash waits, then says the item and its holder as its two lines paint them as it leaves, queued" do
    holder = WfHolder.new("Snorlax", 100, 200, 1)
    holder.item = :LEFTOVERS
    with_item_splash(true) do
      WfSplashScene.new.pbShowItemSplash(holder)
      assert_nothing_spoken
      WfSplashScene.new.pbHideItemSplashSide(1)
      WfSplashScene.new.pbHideItemSplashSide(0)
    end
    assert_equal [["Item#{:LEFTOVERS} de Snorlax", false]], SpeakCapture.log
  end

  test "a second splash says the one still waiting" do
    holder = WfHolder.new("Snorlax", 100, 200, 1)
    holder.item = :LEFTOVERS
    with_item_splash(true) do
      WfSplashScene.new.pbShowItemSplash(holder)
      WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
    end
    assert_equal [["Item#{:LEFTOVERS} de Snorlax", false]], SpeakCapture.log
  end

  test "a splash shown over one still up says that one, and waits for its own message" do
    holder = WfHolder.new("Snorlax", 100, 200, 1)
    holder.item = :LEFTOVERS
    scene = WfSplashScene.new
    with_item_splash(true) do
      with_wf_lines do
        scene.pbShowItemSplash(holder)
        scene.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
        assert_equal ["ItemLEFTOVERS de Snorlax"], SpeakCapture.lines
        PokeAccess.say_dialogue("Onix usó su ItemSITRUSBERRY.")
      end
    end
    assert_equal ["ItemLEFTOVERS de Snorlax", "Onix usó su ItemSITRUSBERRY."], SpeakCapture.lines
  end

  test "a splash goes ahead of a message that does not name both the item and its holder" do
    with_item_splash(true) do
      with_wf_lines do
        ["¡Onix se recuperó!", "¡ItemSITRUSBERRY brilla!"].each do |message|
          SpeakCapture.clear
          WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
          PokeAccess.say_dialogue(message)
          assert_equal [["ItemSITRUSBERRY de Onix", false], [message, false]], SpeakCapture.log
        end
      end
    end
  end

  test "a splash gives way to a message that names the item and its holder, in any case" do
    with_item_splash(true) do
      with_wf_lines do
        WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
        PokeAccess.say_dialogue("¡ONIX recuperó PS con su itemsitrusberry!")
        assert_equal ["¡ONIX recuperó PS con su itemsitrusberry!"], SpeakCapture.lines
        WfMenuScene.new.pbEndBattle
        assert_equal 1, SpeakCapture.lines.length, "and nothing waits any more"
      end
    end
  end

  test "a splash still up as the battle's scene ends is said" do
    with_item_splash(true) do
      WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
      assert_equal :ended, WfMenuScene.new.pbEndBattle
    end
    assert_equal ["ItemSITRUSBERRY de Onix"], SpeakCapture.lines
  end

  test "a blank message leaves the splash waiting" do
    with_item_splash(true) do
      with_wf_lines do
        WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
        PokeAccess.say_dialogue("  ")
        assert_nothing_spoken
        PokeAccess::WfItemSplash.flush
      end
    end
    assert_equal ["ItemSITRUSBERRY de Onix"], SpeakCapture.lines
  end

  test "resetting the caches drops the splash waiting" do
    with_item_splash(true) { WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY) }
    PokeAccess::Caches.reset_all
    PokeAccess::WfItemSplash.flush
    assert_nothing_spoken
  end

  test "a splash with no item, or with the splash off, holds nothing" do
    with_item_splash(true) { WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1)) }
    with_item_splash(false) do
      WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
    end
    PokeAccess::WfItemSplash.flush
    assert_nothing_spoken
  end

  test "the battle's first message is said once: the call the camera swallows after showing it says nothing" do
    scene = Battle::Scene.new
    with_wf_lines do
      scene.pbDisplayPausedMessage("¡Lola te desafía!")
      scene.instance_variable_set(:@ebs_suppress_next_paused, true)
      scene.pbDisplayPausedMessage("¡Eco de Lola te desafía!")
      scene.pbDisplayMessage("¡Eco de Lola saca a Onix!")
      scene.instance_variable_set(:@ebs_suppress_next_paused, false)
      scene.pbDisplayPausedMessage("¡Lola saca a Onix!")
    end
    assert_equal ["¡Lola te desafía!", "¡Lola saca a Onix!"], SpeakCapture.lines
  end

  test "a brief message passes the camera's swallowing, as the game lets it" do
    scene = Battle::Scene.new
    scene.instance_variable_set(:@ebs_suppress_next_paused, true)
    with_wf_lines { scene.pbDisplayMessage("¡Adelante, Onix!", true) }
    assert_equal ["¡Adelante, Onix!"], SpeakCapture.lines
  end

  test "the move panel's icon follows its own table, the weather it weighs and the abilities it weighs, as painted" do
    with_effectiveness do
      {
        [nil, false, false] => 0, [0.0, false, false] => 1, [0.5, false, false] => 2, [2.0, false, false] => 3,
        [1.0, false, false] => 4, [2.0, true, false] => 1, [nil, true, false] => 1, [2.0, false, true] => 1
      }.each do |(value, blocked, immune), icon|
        scene = WfPanelScene.new(value, blocked, immune)
        with_wf_lines do
          assert_equal icon, PokeAccess::DBKMoveInfo.effect_index(:foe, :FIRE, scene, :move, :user),
                       "#{value.inspect}, blocked #{blocked}, immune #{immune}"
        end
      end
    end
  end

  test "an earlier panel, with no weather of its own to weigh, leaves the icon to the plugin" do
    assert_nil PokeAccess::WfBattleBox.move_icon(:foe, :FIRE, Object.new, :move, :user)
    assert_nil PokeAccess::WfBattleBox.move_icon(:foe, :FIRE)
  end

  test "a panel that raises asking leaves the icon to the plugin" do
    scene = WfPanelScene.new(1.0, false, false)
    def scene.pbMoveInfoTypeMod(*_a); raise "no battle"; end
    assert_nil PokeAccess::WfBattleBox.move_icon(:foe, :FIRE, scene, :move, :user)
  end

  test "core says every message a scene is handed, the camera's mark or not" do
    scene = Battle::Scene.new
    scene.instance_variable_set(:@ebs_suppress_next_paused, true)
    scene.pbDisplayPausedMessage("¡Lola te desafía!")
    assert_equal ["¡Lola te desafía!"], SpeakCapture.lines
  end

  test "the command menu's info button is said once the menu shows, after its first line, queued" do
    in_wf_battle do |scene|
      scene.show(:command)
      PokeAccess.speak("Luchar", false)
      PokeAccess::Frame.run_pollers
    end
    assert_equal [["Luchar", false], [key_hint(:dbk_prompt_info, "A"), false]], SpeakCapture.log
  end

  test "the fight menu says both its buttons, the move info's second, and the layout keeps the game's value" do
    in_wf_battle do |scene|
      assert_equal :laid_out, scene.show(:fight)
      PokeAccess::Frame.run_pollers
    end
    assert_equal ["#{key_hint(:dbk_prompt_info, 'A')}. #{key_hint(:dbk_prompt_move, 'S')}"], SpeakCapture.lines
  end

  test "each menu's buttons are said once per battle, however often the game lays them out" do
    2.times do
      in_wf_battle do |scene|
        3.times do
          scene.show(:command)
          PokeAccess::Frame.run_pollers
          scene.show(:fight)
          PokeAccess::Frame.run_pollers
          scene.show(nil)
          PokeAccess::Frame.run_pollers
        end
      end
    end
    assert_equal 4, SpeakCapture.lines.length
  end

  test "an info panel hides the buttons and holds nothing, and a menu gone by the next frame waits for its return" do
    in_wf_battle do |scene|
      scene.show(:fight)
      scene.info(true)
      PokeAccess::Frame.run_pollers
      assert_nothing_spoken
      scene.info(false)
      scene.show(nil)
      PokeAccess::Frame.run_pollers
      assert_nothing_spoken
      scene.show(:fight)
      PokeAccess::Frame.run_pollers
    end
    assert_equal ["#{key_hint(:dbk_prompt_info, 'A')}. #{key_hint(:dbk_prompt_move, 'S')}"], SpeakCapture.lines
  end

  test "a remapped button is said by its key now, and nothing is said with key hints left out" do
    PokeAccess::Config.rebinds = { :y => 0x51 }
    in_wf_battle do |scene|
      scene.show(:fight)
      PokeAccess::Frame.run_pollers
    end
    moved = PokeAccess::ConfigMenu.keyname(0x51)
    assert_equal ["#{key_hint(:dbk_prompt_info, 'A')}. #{key_hint(:dbk_prompt_move, moved)}"], SpeakCapture.lines
    PokeAccess::Config.verbosity = :brief
    in_wf_battle do |scene|
      scene.show(:command)
      PokeAccess::Frame.run_pollers
    end
    assert_equal 1, SpeakCapture.lines.length
  end

  private

  # Runs the block with a fresh battle's scene; a hint still held is dropped after.
  def in_wf_battle
    yield WfMenuScene.new
  ensure
    PokeAccess::WfMenuKeys.instance_variable_set(:@pending, nil)
  end

  # A key hint as World Frontier's buttons are said: the panel's name and its key.
  def key_hint(label, key)
    I18n.t(:hint_label_key, :label => I18n.t(label), :key => key)
  end

  # Runs the block with the battle scene's USE_ITEM_SPLASH, World Frontier's switch tying the item splash to the
  # ability splash, set to on; taken off after.
  def with_item_splash(on)
    Battle::Scene.const_set(:USE_ITEM_SPLASH, on)
    yield
  ensure
    Battle::Scene.send(:remove_const, :USE_ITEM_SPLASH)
  end

  # Runs the block with the game's type table, by the multiplier; taken off after.
  def with_effectiveness
    table = Module.new do
      def self.ineffective?(value); value == 0.0; end
      def self.not_very_effective?(value); value == 0.5; end
      def self.super_effective?(value); value == 2.0; end
    end
    Object.const_set(:Effectiveness, table)
    yield
  ensure
    Object.send(:remove_const, :Effectiveness)
  end

  # The block's value with World Frontier's seams on the battle's lines in place, the core's put back after.
  def with_wf_lines
    kept = WF_LINE_SEAMS.map { |owner, m, _wf| [owner, m, owner.method(m)] }
    WF_LINE_SEAMS.each { |owner, m, wf| owner.define_singleton_method(m, wf) }
    yield
  ensure
    kept.each { |owner, m, original| owner.define_singleton_method(m, original) }
  end

  # The block's value with World Frontier's box seams in place, the core's put back after.
  def with_box
    kept = WF_BATTLE_SEAMS.map { |m, _wf| [m, PokeAccess::Battle.method(m)] }
    WF_BATTLE_SEAMS.each { |m, wf| PokeAccess::Battle.define_singleton_method(m, wf) }
    yield
  ensure
    kept.each { |m, original| PokeAccess::Battle.define_singleton_method(m, original) }
  end
end
