# BattleScene.command_label: the focused battle command, from the menu's own texts, else the v22 command symbol,
# else the v19-v21 label by position for the menu mode (0-2 regular, 3 Safari, 4 Bug Contest, 5-8 Deluxe Battle Kit).
class CommandMenuTest < PokeAccessTest
  # The i18n keys of a regular battle's four buttons, by position.
  REGULAR = [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_run]

  # The v19-v21 CommandMenu: a button by position in a mode, no texts and no command.
  Menu = Struct.new(:index, :mode)

  # The v22 CommandMenu, which names the focused command by symbol.
  SymbolMenu = Struct.new(:index, :command)

  # A menu that answers its index but no mode.
  IndexOnly = Struct.new(:index)

  # A menu that answers its mode but no index.
  ModeOnly = Struct.new(:mode)

  test "labels the buttons of the regular, Safari and Bug Contest modes by position" do
    { 0 => REGULAR,
      1 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :pc_cancel],
      2 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_call],
      3 => [:bt_cmd_ball, :bt_cmd_bait, :bt_cmd_rock, :bt_cmd_run],
      4 => [:bt_cmd_fight, :bt_cmd_ball, :bt_cmd_pokemon, :bt_cmd_run] }.each do |mode, keys|
      assert_equal keys.map { |k| t(k) }, labels_in(mode), "mode #{mode}"
    end
  end

  test "labels the buttons of the Deluxe Battle Kit's modes by position" do
    { 5 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_cheer],
      6 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :bt_cmd_run],
      7 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :pc_cancel],
      8 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :bt_cmd_call] }.each do |mode, keys|
      assert_equal keys.map { |k| t(k) }, labels_in(mode), "mode #{mode}"
    end
  end

  test "a mode it does not know labels as a regular battle" do
    assert_equal REGULAR.map { |k| t(k) }, labels_in(9)
  end

  test "a menu that answers no mode labels as a regular battle" do
    assert_equal REGULAR.map { |k| t(k) }, (0..3).map { |i| PokeAccess::BattleScene.command_label(IndexOnly.new(i)) }
  end

  test "a menu that answers no index is on its first button" do
    assert_equal t(:bt_cmd_ball), PokeAccess::BattleScene.command_label(ModeOnly.new(3))
  end

  test "a position it has no label for is said as run" do
    { nil => t(:bt_cmd_run), 4 => t(:bt_cmd_run) }.each do |index, label|
      assert_equal label, PokeAccess::BattleScene.command_label(Menu.new(index, 1)), "at #{index.inspect}"
    end
  end

  test "the menu's own texts win over the mode's labels, cleaned of their codes" do
    menu = Menu.new(0, 3)
    menu.instance_variable_set(:@texts, ["\\c[2]Luchar", "Mochila", "", nil])
    { 0 => "Luchar", 1 => "Mochila" }.each do |index, label|
      menu.index = index
      assert_equal label, PokeAccess::BattleScene.command_label(menu), "button #{index}"
    end
  end

  test "an empty or missing text falls back to the mode's label" do
    menu = Menu.new(0, 3)
    menu.instance_variable_set(:@texts, ["Luchar", "Mochila", "", nil])
    { 2 => t(:bt_cmd_rock), 3 => t(:bt_cmd_run) }.each do |index, label|
      menu.index = index
      assert_equal label, PokeAccess::BattleScene.command_label(menu), "button #{index}"
    end
  end

  test "a v22 menu says its command by symbol, wherever the button sits" do
    { :fight => :bt_cmd_fight, :fight2 => :bt_cmd_fight, :bag => :bt_cmd_bag, :pokemon => :bt_cmd_pokemon,
      :run => :bt_cmd_run, :call => :bt_cmd_call, :cancel => :pc_cancel, :shift => :bt_shift,
      :throw_ball => :bt_cmd_ball, :throw_ball_contest => :bt_cmd_ball, :throw_bait => :bt_cmd_bait,
      :throw_rock => :bt_cmd_rock }.each do |command, key|
      assert_equal t(key), PokeAccess::BattleScene.command_label(SymbolMenu.new(3, command)), "for #{command.inspect}"
    end
  end

  test "a v22 command it has no word for is said through the key of its name" do
    assert_equal t(:bt_cmd_cheer), PokeAccess::BattleScene.command_label(SymbolMenu.new(0, :bt_cmd_cheer))
  end

  private

  # The four labels of a v19-v21 menu in mode, by position.
  def labels_in(mode)
    (0..3).map { |i| PokeAccess::BattleScene.command_label(Menu.new(i, mode)) }
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
