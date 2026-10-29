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
end

# The splash's scene half, prepended to the battle scene in the game.
module WfItemSplashHalf
  def pbShowItemSplash(battler, item = nil); [battler, item]; end
end

# A battle scene with the splash.
class WfSplashScene
  include WfItemSplashHalf
end

# A battler holding an item, as the splash reads it.
class WfHolder < Battle::Battler
  attr_accessor :item
end

seams = [:shown_level, :shown_hp].map { |m| [m, PokeAccess::Battle.method(m)] }
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

  test "the item splash says the item and its holder as its two lines paint them, queued" do
    holder = WfHolder.new("Snorlax", 100, 200, 1)
    holder.item = :LEFTOVERS
    with_item_splash(true) do
      WfSplashScene.new.pbShowItemSplash(holder)
      WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
    end
    assert_equal [["Item#{:LEFTOVERS} de Snorlax", false], ["Item#{:SITRUSBERRY} de Onix", false]], SpeakCapture.log
  end

  test "a splash with no item, or with the splash off, says nothing" do
    with_item_splash(true) { WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1)) }
    with_item_splash(false) do
      WfSplashScene.new.pbShowItemSplash(Battle::Battler.new("Onix", 10, 20, 1), :SITRUSBERRY)
    end
    assert_nothing_spoken
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

  # The block's value with World Frontier's box seams in place, the core's put back after.
  def with_box
    kept = WF_BATTLE_SEAMS.map { |m, _wf| [m, PokeAccess::Battle.method(m)] }
    WF_BATTLE_SEAMS.each { |m, wf| PokeAccess::Battle.define_singleton_method(m, wf) }
    yield
  ensure
    kept.each { |m, original| PokeAccess::Battle.define_singleton_method(m, original) }
  end
end
