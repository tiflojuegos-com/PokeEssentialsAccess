# The Enhanced Battle UI's key prompt (plugins/dbk_enhanced_ui.rb): the keys it paints beside the command and fight
# menus (Eternal Emerald and Relict), or draws into its picture (Anil, Revival, Royal, Grueling Gold), said as a key
# hint once per battle and menu, queued once that menu shows. The plugin's hook is evaluated again over the stand-in
# below, which holds the game's name only while it binds.
module DbkPromptSpec
  COMMAND = 1
  FIGHT = 2

  # A menu window as the hint asks it: whether it shows.
  Window = Struct.new(:visible)

  # The prompt's picture (menu_prompts, its two menus' halves stacked) and the sprite that shows a part of it.
  Picture = Struct.new(:height)
  Background = Struct.new(:src_rect)
  SrcRect = Struct.new(:height)

  # The battle scene's two menu windows, hidden until shown.
  class Scene
    def initialize; @sprites = { "commandWindow" => Window.new(false), "fightWindow" => Window.new(false) }; end
    def show(name); @sprites.each { |key, win| win.visible = (key == name) }; end
  end

  # The battle: its scene, and whether the player's side can throw a ball.
  Battle = Struct.new(:scene, :balls) do
    def pbCanUsePokeBall?(_idx); balls; end
  end

  # Battle::Scene::EnhancedUIPrompt as Emerald and Relict paint it: nothing until it has a battler, then ": A" and
  # ": S", the second left out of the command box when no ball can be thrown, where the background is cut to its
  # first row. A drawn one, as Anil, Revival, Royal and Grueling Gold have it, paints nothing.
  class Prompt
    def initialize(battle, drawn = false)
      @battle = battle; @window = COMMAND; @battler = nil; @disposed = false; @drawn = drawn
      @bgBitmap = Picture.new(104)
      @bgSprite = Background.new(SrcRect.new(52))
    end

    def window=(value); @window = value; refresh; end
    def battler=(value); @battler = value; refresh; end
    def dispose; @disposed = true; end
    def disposed?; @disposed; end

    def refresh
      return :no_battler if !@battler
      rows = [[": A", 68, 7, :left, nil, nil, :outline], [": S", 68, 31, :left, nil, nil, :outline]]
      cut = @window != FIGHT && !@battle.pbCanUsePokeBall?(@battler)
      @bgSprite.src_rect.height = cut ? 28 : @bgBitmap.height / 2
      rows.delete_at(1) if cut
      pbDrawTextPositions(nil, rows) unless @drawn
      :painted
    end
  end
end

prompt_path = File.join(Harness::ROOT, "plugins", "dbk_enhanced_ui.rb")
prompt_src = Harness.source(prompt_path)
prompt_hook = prompt_src.match(/^PokeAccess::Hooks\.around_hook\("Battle::Scene::EnhancedUIPrompt", :refresh.*?^end\n/m)
prompt_held = Battle::Scene.const_defined?(:EnhancedUIPrompt) ? Battle::Scene::EnhancedUIPrompt : nil
begin
  Battle::Scene.send(:remove_const, :EnhancedUIPrompt) if prompt_held
  Battle::Scene.const_set(:EnhancedUIPrompt, DbkPromptSpec::Prompt)
  eval(prompt_hook[0], TOPLEVEL_BINDING, prompt_path, prompt_src[0, prompt_hook.begin(0)].count("\n") + 1)
ensure
  Battle::Scene.send(:remove_const, :EnhancedUIPrompt)
  Battle::Scene.const_set(:EnhancedUIPrompt, prompt_held) if prompt_held
end

class DbkPromptGdTest < PokeAccessTest
  Spec = DbkPromptSpec
  T = PokeAccess::I18n

  test "the command menu's keys are said once it shows, after its first line, queued" do
    in_battle do |scene, prompt|
      prompt.window = Spec::COMMAND
      prompt.battler = 0
      PokeAccess::Frame.run_pollers
      scene.show("commandWindow")
      PokeAccess.speak("Luchar", false)
      PokeAccess::Frame.run_pollers
    end
    assert_equal [["Luchar", false], ["#{hint(:dbk_prompt_info, 'A')}. #{hint(:dbk_prompt_ball, 'S')}", false]],
                 SpeakCapture.log
  end

  test "the fight menu's second key opens the move info" do
    in_battle do |scene, prompt|
      scene.show("fightWindow")
      prompt.battler = 0
      prompt.window = Spec::FIGHT
      PokeAccess::Frame.run_pollers
    end
    assert_equal ["#{hint(:dbk_prompt_info, 'A')}. #{hint(:dbk_prompt_move, 'S')}"], SpeakCapture.lines
  end

  test "with no ball to throw the command menu has the info key alone" do
    in_battle(false) do |scene, prompt|
      scene.show("commandWindow")
      prompt.battler = 0
      PokeAccess::Frame.run_pollers
    end
    assert_equal [hint(:dbk_prompt_info, "A")], SpeakCapture.lines
  end

  test "each menu's keys are said once per battle, however often its prompt repaints" do
    in_battle do |scene, prompt|
      scene.show("commandWindow")
      prompt.battler = 0
      3.times do
        prompt.window = Spec::COMMAND
        PokeAccess::Frame.run_pollers
      end
      scene.show("fightWindow")
      2.times do
        prompt.window = Spec::FIGHT
        PokeAccess::Frame.run_pollers
      end
    end
    assert_equal 2, SpeakCapture.lines.length
  end

  test "a new battle's prompt says the keys again" do
    2.times do
      in_battle do |scene, prompt|
        scene.show("commandWindow")
        prompt.battler = 0
        PokeAccess::Frame.run_pollers
      end
    end
    assert_equal 2, SpeakCapture.lines.length
  end

  test "a key a remap moved is said as the key now used" do
    PokeAccess::Config.rebinds = { :y => 0x51 }
    in_battle do |scene, prompt|
      scene.show("commandWindow")
      prompt.battler = 0
      PokeAccess::Frame.run_pollers
    end
    moved = PokeAccess::ConfigMenu.keyname(0x51)
    assert_equal ["#{hint(:dbk_prompt_info, 'A')}. #{hint(:dbk_prompt_ball, moved)}"], SpeakCapture.lines
  end

  test "with key hints left out nothing is held, and turning them on says the keys at the next repaint" do
    in_battle do |scene, prompt|
      PokeAccess::Config.verbosity = :brief
      scene.show("commandWindow")
      prompt.battler = 0
      PokeAccess::Frame.run_pollers
      PokeAccess::Config.verbosity = :full
      PokeAccess::Frame.run_pollers
      prompt.window = Spec::COMMAND
      PokeAccess::Frame.run_pollers
    end
    assert_equal ["#{hint(:dbk_prompt_info, 'A')}. #{hint(:dbk_prompt_ball, 'S')}"], SpeakCapture.lines
  end

  test "a prompt disposed with its battle drops the keys it held" do
    in_battle do |scene, prompt|
      prompt.battler = 0
      prompt.dispose
      scene.show("commandWindow")
      PokeAccess::Frame.run_pollers
      fresh = Spec::Prompt.new(PokeAccess.ivar(prompt, :@battle))
      fresh.battler = 0
      PokeAccess::Frame.run_pollers
    end
    assert_equal 1, SpeakCapture.lines.length
  end

  test "the prompt keeps what its refresh returns" do
    in_battle do |_scene, prompt|
      prompt.battler = 0
      assert_equal :painted, prompt.refresh
    end
  end

  test "keys drawn into the picture are said as its rows show them, the ball's in the command menu" do
    in_battle(true, true) do |scene, prompt|
      scene.show("commandWindow")
      prompt.battler = 0
      PokeAccess::Frame.run_pollers
      scene.show("fightWindow")
      prompt.window = Spec::FIGHT
      PokeAccess::Frame.run_pollers
    end
    assert_equal [["#{hint(:dbk_prompt_info, 'A')}. #{hint(:dbk_prompt_ball, 'S')}", false],
                  ["#{hint(:dbk_prompt_info, 'A')}. #{hint(:dbk_prompt_move, 'S')}", false]], SpeakCapture.log
  end

  test "a drawn picture cut to its first row, with no ball to throw, gives the info key alone" do
    in_battle(false, true) do |scene, prompt|
      scene.show("commandWindow")
      prompt.battler = 0
      PokeAccess::Frame.run_pollers
    end
    assert_equal [hint(:dbk_prompt_info, "A")], SpeakCapture.lines
  end

  test "a drawn key a remap moved is said as the key now used" do
    PokeAccess::Config.rebinds = { :x => 0x51 }
    in_battle(true, true) do |scene, prompt|
      scene.show("fightWindow")
      prompt.window = Spec::FIGHT
      prompt.battler = 0
      PokeAccess::Frame.run_pollers
    end
    moved = PokeAccess::ConfigMenu.keyname(0x51)
    assert_equal ["#{hint(:dbk_prompt_info, moved)}. #{hint(:dbk_prompt_move, 'S')}"], SpeakCapture.lines
  end

  test "a drawn prompt holds nothing before it has a battler, nor with key hints left out" do
    in_battle(true, true) do |scene, prompt|
      scene.show("commandWindow")
      prompt.window = Spec::COMMAND
      PokeAccess::Frame.run_pollers
      PokeAccess::Config.verbosity = :brief
      prompt.battler = 0
      PokeAccess::Frame.run_pollers
      PokeAccess::Config.verbosity = :full
      prompt.window = Spec::COMMAND
      PokeAccess::Frame.run_pollers
    end
    assert_equal ["#{hint(:dbk_prompt_info, 'A')}. #{hint(:dbk_prompt_ball, 'S')}"], SpeakCapture.lines
  end

  private

  # Runs the block with a battle's scene and its prompt, painted or drawn, the battle's menu boxes under the game's
  # names; a hint still held is dropped after.
  def in_battle(balls = true, drawn = false)
    boxes = [[:COMMAND_BOX, Spec::COMMAND], [:FIGHT_BOX, Spec::FIGHT]]
    boxes = boxes.reject { |n, _v| Battle::Scene.const_defined?(n) }
    boxes.each { |n, v| Battle::Scene.const_set(n, v) }
    scene = Spec::Scene.new
    yield scene, Spec::Prompt.new(Spec::Battle.new(scene, balls), drawn)
  ensure
    PokeAccess::DBKPrompt.instance_variable_set(:@pending, nil)
    (boxes || []).each { |n, _v| Battle::Scene.send(:remove_const, n) }
  end

  # A key hint as the plugin words it: the panel's name and its key.
  def hint(label, key)
    T.t(:hint_label_key, :label => T.t(label), :key => key)
  end
end
