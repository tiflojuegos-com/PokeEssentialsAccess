require_relative '../xenoverse_standalone'

# The real EBS windows use plain attr_accessors rather than the stock display
# setters. Reproduce their update/paint boundary, not their graphics engine.
class NewCommandWindow
  attr_accessor :index, :labels
  def initialize
    @index = 0
    @labels = ['Actual Fight', 'Actual Bag', 'Actual Pokemon', 'Actual Run']
  end
  def refreshCommands(_battler)
    pbDrawTextPositions(Object.new, @labels.map { |text| [text, 4, 2, 0, nil] })
    :original_refresh
  end
  def update; :original_update; end
end
class NewFightWindow
  Rect = Struct.new(:y)
  Button = Struct.new(:src_rect)
  attr_accessor :index
  def initialize; @index = 0; @megaButton = Button.new(Rect.new(0)); end
  def update; :original_update; end
  def megaButtonTrigger
    @megaButton.src_rect.y = @megaButton.src_rect.y == 0 ? 48 : 0
    :original_mega
  end
end
class NextGenCommandWindow
  attr_accessor :index
  def initialize; @index = 0; end
  def refreshCommands(_battler)
    ['Painted Fight', 'Painted Bag', 'Painted Pokemon', 'Painted Run'].each do |text|
      pbDrawOutlineText(Object.new, 0, 0, 90, 44, text, nil)
    end
    :original_refresh
  end
  def update; :original_update; end
end
class NextGenFightWindow
  attr_accessor :index
  def initialize; @index = 0; @usedMega = false; end
  def update; :original_update; end
  def megaButtonTrigger; @usedMega = !@usedMega; :original_mega; end
end
class PokeBattle_Scene
  # Preserve core's already installed scene wrappers while replacing only the
  # harness originals with the EBS blocking-loop shape used by the real game.
  def xeno_test_command_menu(index, _texts, _mode = 0)
    @commandWindow.refreshCommands(index)
    @commandWindow.update
    @commandWindow.index = 1
    @commandWindow.update
    @commandWindow.index
  end
  def xeno_test_fight_menu(_index)
    @fightWindow.update
    @fightWindow.index = 1
    @fightWindow.update
    @fightWindow.index
  end
  if method_defined?(:pbCommandMenuEx)
    alias_method :pbCommandMenuEx__pa_orig_PokeBattle_Scene, :xeno_test_command_menu
  else
    alias_method :pbCommandMenuEx, :xeno_test_command_menu
  end
  if method_defined?(:pbFightMenu)
    alias_method :pbFightMenu__pa_orig_PokeBattle_Scene, :xeno_test_fight_menu
  else
    alias_method :pbFightMenu, :xeno_test_fight_menu
  end
end
load File.join(Harness::ROOT, 'games/xenoverse/battle_menus.rb')

class XenoverseBattleMenusTest < PokeAccessTest
  include PeaStandaloneMethods
  def setup
    super
    PokeAccess::Config.language = :en
    @reader = PokeAccess::XenoverseBattleMenus
    @command, @fight = NewCommandWindow.new, NewFightWindow.new
    @scene = Object.new
    @scene.instance_variable_set(:@commandWindow, @command)
    @scene.instance_variable_set(:@fightWindow, @fight)
    @battle = Object.new
    def @battle.pbCanMegaEvolve?(_index); true; end
    @battler = Struct.new(:index, :moves).new(0, [Struct.new(:id).new(33), Struct.new(:id).new(52)])
    @battler.instance_variable_set(:@battle, @battle)
    @fight.instance_variable_set(:@battler, @battler)
  end

  def test_painted_commands_open_change_wrap_idle_and_reopen
    2.times do
      SpeakCapture.clear
      value = @reader.with_menu(@scene, :command) do
        assert_equal :original_refresh, @command.refreshCommands(0)
        assert_equal :original_update, @command.update
        @command.update
        @command.index = 3; @command.update
        @command.index = 0; @command.update
        @command.index = 1; @command.update
        :original_choice
      end
      assert_equal :original_choice, value
      assert_equal ['Actual Fight', 'Actual Run', 'Actual Fight', 'Actual Bag'], SpeakCapture.lines
      assert_equal [false, true, true, true], SpeakCapture.log.map { |row| row[1] }
      assert_equal :battle_foe, PokeAccess::Info.instance_variable_get(:@kind)
      @command.index = 0
    end
    SpeakCapture.clear
    @command.update
    assert_nothing_spoken
  end

  def test_refresh_does_not_reuse_old_labels_or_other_windows
    @reader.with_menu(@scene, :command) do
      @command.refreshCommands(0); @command.update
      SpeakCapture.clear
      @command.labels = []; @command.refreshCommands(0); @command.update
      other = NewCommandWindow.new
      other.refreshCommands(0); other.update
      [-1, 99, nil].each { |index| @command.index = index; @command.update }
      assert_nothing_spoken
    end
  end

  def test_fight_uses_shared_formatter_and_queues_only_its_opening
    calls = []
    with_singleton(PokeAccess::Battle, :read_fight_move, lambda { |window, interrupt| calls << [window.index, interrupt] }) do
      2.times do
        @fight.index = 0
        @reader.with_menu(@scene, :fight) do
          @fight.update
          @fight.index = 1; @fight.update
        end
      end
    end
    assert_equal [[0, false], [1, true], [0, false], [1, true]], calls
  end

  def test_invalid_or_empty_fight_slots_never_read_another_move
    calls = []
    with_singleton(PokeAccess::Battle, :read_fight_move, lambda { |_window, _interrupt| calls << true }) do
      @reader.with_menu(@scene, :fight) do
        [-1, 99, nil, 2].each { |index| @fight.index = index; @fight.update }
        @fight.index = 0
        @battler.moves[0].id = 0
        @fight.update
      end
    end
    assert_empty calls
    assert_nothing_spoken
  end

  def test_mega_reads_actual_source_rectangle_and_hidden_toggle_stays_silent
    with_singleton(PokeAccess::Battle, :read_fight_move, lambda { |_window, _interrupt| nil }) do
      @fight.instance_variable_set(:@showMega, true)
      @reader.with_menu(@scene, :fight) do
        @fight.update
        assert_equal :original_mega, @fight.megaButtonTrigger
        @fight.megaButtonTrigger
        @fight.instance_variable_set(:@showMega, false)
        @fight.megaButtonTrigger
      end
    end
    assert_equal ['Mega Evolution available', 'Mega Evolution on', 'Mega Evolution off'], SpeakCapture.lines
  end

  def test_nested_scope_and_game_exception_restore_the_outer_owner
    @reader.with_menu(@scene, :command) do
      @command.refreshCommands(0); @command.update
      assert_raises(RuntimeError) { @reader.with_menu(@scene, :fight) { raise 'Actual game failure' } }
      @command.index = 1; @command.update
    end
    assert_equal ['Actual Fight', 'Actual Bag'], SpeakCapture.lines
    SpeakCapture.clear
    @command.index = 2; @command.update
    @fight.update
    assert_nothing_spoken
  end

  def test_actual_registered_scene_wrappers_keep_nested_window_hooks_alive
    scene = PokeBattle_Scene.allocate
    scene.instance_variable_set(:@commandWindow, @command)
    scene.instance_variable_set(:@fightWindow, @fight)
    assert_equal 1, scene.pbCommandMenuEx(0, ['question', 'unused labels'])
    assert_equal ['Actual Fight', 'Actual Bag'], SpeakCapture.lines
    calls = []
    with_singleton(PokeAccess::Battle, :read_fight_move, lambda { |window, interrupt| calls << [window.index, interrupt] }) do
      assert_equal 1, scene.pbFightMenu(0)
    end
    assert_equal [[0, false], [1, true]], calls
    assert_equal :battle_foe, PokeAccess::Info.instance_variable_get(:@kind)
  end

  def test_nextgen_windows_use_actual_outline_labels_and_boolean_mega_state
    command, fight = NextGenCommandWindow.new, NextGenFightWindow.new
    fight.instance_variable_set(:@battler, @battler)
    fight.instance_variable_set(:@showMega, true)
    scene = PokeBattle_Scene.allocate
    scene.instance_variable_set(:@commandWindow, command)
    scene.instance_variable_set(:@fightWindow, fight)
    2.times do
      command.index = 0
      SpeakCapture.clear
      assert_equal 1, scene.pbCommandMenuEx(0, ['discarded labels'])
      assert_equal ['Painted Fight', 'Painted Bag'], SpeakCapture.lines
    end
    calls = []
    SpeakCapture.clear
    with_singleton(PokeAccess::Battle, :read_fight_move, lambda { |window, interrupt| calls << [window.index, interrupt] }) do
      assert_equal 1, scene.pbFightMenu(0)
      @reader.with_menu(scene, :fight) do
        assert_equal :original_mega, fight.megaButtonTrigger
        fight.megaButtonTrigger
      end
    end
    assert_equal [[0, false], [1, true]], calls
    assert_equal ['Mega Evolution available', 'Mega Evolution on', 'Mega Evolution off'], SpeakCapture.lines
    SpeakCapture.clear
    command.update; fight.update
    pbDrawOutlineText(Object.new, 0, 0, 90, 44, 'Unrelated paint', nil)
    assert_nothing_spoken
  end
end

exit(Minitest.run(ARGV) ? 0 : 1)
