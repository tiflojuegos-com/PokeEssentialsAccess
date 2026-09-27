# BattleScene.command_label with no @texts or #command (the v19-v21 CommandMenu): the button by position, its label
# following the menu mode (0 regular, 1 cancel, 2 call, 3 Safari, 4 Bug Contest).
class FakeCommandMenu
  attr_accessor :index, :mode

  # Builds a positional command-menu stub focused on button `index` in the given `mode`.
  def initialize(index, mode)
    @index = index; @mode = mode
  end
end

Suite.define("battle: Safari command menu reads Ball/Bait/Rock/Run") do
  expected = [:bt_cmd_ball, :bt_cmd_bait, :bt_cmd_rock, :bt_cmd_run]
  labels = (0..3).map { |i| PokeAccess::BattleScene.command_label(FakeCommandMenu.new(i, 3)) }
  eq "position 0 is Ball", labels[0], PokeAccess::I18n.t(:bt_cmd_ball)
  eq "position 1 is Bait", labels[1], PokeAccess::I18n.t(:bt_cmd_bait)
  eq "position 2 is Rock", labels[2], PokeAccess::I18n.t(:bt_cmd_rock)
  eq "position 3 is Run", labels[3], PokeAccess::I18n.t(:bt_cmd_run)
  truthy "no Safari button is read as the regular Fight/Bag/Pokemon defaults",
         (labels & [PokeAccess::I18n.t(:bt_cmd_fight), PokeAccess::I18n.t(:bt_cmd_bag),
                    PokeAccess::I18n.t(:bt_cmd_pokemon)]).empty?
end

Suite.define("battle: Bug Contest command menu reads Fight/Ball/Pokemon/Run") do
  labels = (0..3).map { |i| PokeAccess::BattleScene.command_label(FakeCommandMenu.new(i, 4)) }
  eq "position 0 is Fight", labels[0], PokeAccess::I18n.t(:bt_cmd_fight)
  eq "position 1 is Ball, not Bag", labels[1], PokeAccess::I18n.t(:bt_cmd_ball)
  eq "position 2 is Pokemon", labels[2], PokeAccess::I18n.t(:bt_cmd_pokemon)
  eq "position 3 is Run", labels[3], PokeAccess::I18n.t(:bt_cmd_run)
  truthy "position 1 is not the regular Bag default",
         labels[1] != PokeAccess::I18n.t(:bt_cmd_bag)
end

Suite.define("battle: regular command menu still reads Fight/Bag/Pokemon by position") do
  regular = (0..2).map { |i| PokeAccess::BattleScene.command_label(FakeCommandMenu.new(i, 0)) }
  eq "position 0 is Fight", regular[0], PokeAccess::I18n.t(:bt_cmd_fight)
  eq "position 1 is Bag", regular[1], PokeAccess::I18n.t(:bt_cmd_bag)
  eq "position 2 is Pokemon", regular[2], PokeAccess::I18n.t(:bt_cmd_pokemon)
  eq "mode 0 fourth button is Run",
     PokeAccess::BattleScene.command_label(FakeCommandMenu.new(3, 0)), PokeAccess::I18n.t(:bt_cmd_run)
  eq "mode 1 fourth button is Cancel",
     PokeAccess::BattleScene.command_label(FakeCommandMenu.new(3, 1)), PokeAccess::I18n.t(:pc_cancel)
  eq "mode 2 fourth button is Call",
     PokeAccess::BattleScene.command_label(FakeCommandMenu.new(3, 2)), PokeAccess::I18n.t(:bt_cmd_call)
end
