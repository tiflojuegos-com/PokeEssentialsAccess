# Vitro's battle as its own scripts draw it. Its menus (0102_PokeBattle_SceneCommands) paint four buttons in a row with labels
# of their own and no title; Q opens the battle's information over the commands and the move's over the moves (0103, 0104), and
# W, in a single wild battle, its list of Balls (0246_Ball Selector). Every change of hit points floats its figure over the
# battler, a foe's too (0248_Damage Numbers), and an immunity is only a text floating over its target (0247_Floating Text,
# 0258_Dialogos Combate). The labels those numbers add (critical, super effective) are said by the battle's own messages.
module PokeAccess
  module VitroBattle
    # The row of the label list each button paints, by the menu's mode (CommandMenuButtons#refresh).
    BUTTON_ROWS = { 0 => [0, 2, 1, 3], 1 => [0, 2, 1, 4], 2 => [5, 7, 6, 3], 3 => [0, 8, 1, 3] }

    # Notes the mode a menu opens in: the menu sets its own after the cursor, so the first read would not find it there.
    def self.opening(mode)
      @mode = mode
    end

    # The label the button under the cursor paints, nil past the last button (where a throw from the list of Balls leaves it).
    def self.label(disp, index)
      row = BUTTON_ROWS[@mode][index]
      row ? PokeAccess.ivar(PokeAccess.ivar(disp, :@buttons), :@commandtext)[row] : nil
    end

    # Says the button under the cursor, or what the core finds without one; as the menu opens, its keys after it.
    def self.command(disp, index, interrupt)
      text = label(disp, index)
      text ? PokeAccess.speak_clean(text, interrupt, :menu) : yield
      command_hint(disp) unless interrupt
    end

    # The command menu's keys, once per battle, as the menu lives as long as the battle: the information, which the Safari
    # Zone leaves out, and the list of Balls where the menu paints its key.
    def self.command_hint(disp)
      return if PokeAccess.ivar(disp, :@access_hinted) || !PokeAccess::Verbosity.hints? || pbInSafari?
      disp.instance_variable_set(:@access_hinted, true)
      line = PokeAccess::I18n.t(:vitro_bt_keys, :info => PokeAccess::KeyHints.key(:l, "Q"))
      return PokeAccess.speak(line, false) unless PokeAccess.ivar(disp, :@atajoBall)
      PokeAccess.speak("#{line} #{PokeAccess::I18n.t(:vitro_bt_ball, :key => PokeAccess::KeyHints.key(:r, "W"))}", false)
    end

    # The fight menu's key, once per battle: the menu sets its buttons to 0 as it opens, right after reading the move.
    def self.fight_hint(disp, value)
      return unless value == 0 && PokeAccess::Verbosity.hints? && !PokeAccess.ivar(disp, :@access_hinted)
      disp.instance_variable_set(:@access_hinted, true)
      PokeAccess.speak(PokeAccess::I18n.t(:vitro_fight_keys, :info => PokeAccess::KeyHints.key(:l, "Q")), false)
    end

    # A fight line's parts with the power its button paints, none below 10; said at the level the moves say theirs.
    def self.with_power(parts, move)
      power = move.basedamage.to_i
      return parts if power < 10
      parts[0, 3] + [[PokeAccess::I18n.t(:mv_power, :p => power), :full]] + parts[3, parts.length]
    end

    # The battler whose orders the menu asks for, in a double battle: the box that bobs says it and the title no longer.
    def self.chooser(scene, index)
      battle = PokeAccess.ivar(scene, :@battle)
      return unless battle && PokeAccess::Battle.doubles?(battle)
      name = PokeAccess.clean((battle.battlers[index].name rescue "").to_s)
      PokeAccess.speak(name, false) unless name.empty?
    end

    # The list of Balls closed with no throw: says the focused command again, whose cursor did not move.
    def self.ball_closed(battle, thrown)
      return if thrown
      menu = PokeAccess.sprite(battle.scene, "commandwindow")
      PokeAccess::Info.set_info(:battle_foe, nil)
      PokeAccess::Battle.read_command(menu, menu.index, false)
    end

    # A text floating over a battler: as painted, with whom it floats over in a double battle.
    def self.floating(battler, text, double)
      return if text.to_s.empty?
      name = double ? PokeAccess.clean((battler.name rescue "").to_s) : ""
      PokeAccess.say_dialogue(name.empty? ? text : PokeAccess::I18n.t(:bt_marks_entry, :name => name, :marks => text))
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbUseBallInBattle", "vitro_ball_closed", :after) do |args, thrown|
  PokeAccess::VitroBattle.ball_closed(args[0], thrown)
end

PokeAccess::Game.define("vitro") do
  before("PokeBattle_Scene", :pbCommandMenu) { |scene, args| PokeAccess::VitroBattle.chooser(scene, args[0]) }
  before("PokeBattle_Scene", :pbCommandMenuEx) { |_scene, args| PokeAccess::VitroBattle.opening(args[2]) }
  before("PokeBattle_Scene", :tkShowFloatingText) { |_scene, args| PokeAccess::VitroBattle.floating(args[0], args[1], args[2]) }
  after("FightMenuDisplay", :megaButton=) { |disp, _r, args| PokeAccess::VitroBattle.fight_hint(disp, args[0]) }
  override("PokeAccess::Battle", :read_command) do |_mod, original, args|
    PokeAccess::VitroBattle.command(args[0], args[1], args[2]) { original.call }
  end
  override("PokeAccess::Battle", :fight_line) do |_mod, original, args|
    PokeAccess::VitroBattle.with_power(original.call, args[1])
  end
  override("PokeAccess::Battle", :foe_change_painted?) { |_mod, _original, _args| true }
  override("PokeAccess::BesBattleInfo", :held_by) { |_mod, _original, args| args[0].get_display_pokemon(args[1]) }
end
