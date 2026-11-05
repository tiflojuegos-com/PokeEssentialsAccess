# Essentials Deluxe (plugins/essentials_deluxe.rb). Its midbattle speech: while the name window over a scripted battle
# line shows, its name leads the next line said, once. Its fight menu: the button is said by the mechanic behind it, each
# one in turn, though pbFightMenu takes them as flags. The plugin's hooks and the core's on pbFightMenu are evaluated
# again over the stand-ins below so they bind.

# The name window as Essentials Deluxe fills it: the speaker's name (a trainer's, or the panel's own name), shown
# unless it is empty or the call hides it, as a reset of the panel does.
class Battle::Scene
  NameBox = Struct.new(:text, :visible)

  def pbUpdateNameWindow(speaker = "", visible = true, reset = false)
    @namePanelName = nil if reset
    name = speaker.is_a?(String) || speaker.nil? ? (@namePanelName || "") : (@namePanelName || speaker.name)
    @sprites ||= {}
    win = (@sprites["nameWindow"] ||= NameBox.new("", false))
    win.text = name
    win.visible = (name.empty? || !visible) ? false : true
  end

  attr_accessor :fight_window

  # The fight menu as Fight Menu.rb opens it, then whatever the test presses (the block).
  def pbFightMenu(_idx_battler, *params)
    keys = [:mega, :ultra, :zmove, :dynamax, :style, :tera, :zodiac, :custom]
    data = {}
    keys.each_with_index { |k, i| data[k] = params[i] || false }
    mechanic = pbFightMenu_BattleMechanic(data, @fight_window)
    @fight_window.setIndexAndMode(0, mechanic ? 1 : 0)
    yield @fight_window if block_given?
  end

  def pbFightMenu_BattleMechanic(data, cw)
    mechanic = nil
    button = :none
    data.keys.each do |key|
      next if !data[key]
      mechanic = button = key
    end
    cw.chosen_button = button
    mechanic
  end
end

class Battle::Scene::FightMenu
  attr_accessor :chosen_button
end

deluxe = File.join(Harness::ROOT, "plugins", "essentials_deluxe.rb")
eval(Harness.source(deluxe), TOPLEVEL_BINDING, deluxe)
v21 = File.join(Harness::ROOT, "core", "battle", "v21", "battle_v21.rb")
eval(Harness.source(v21)[/^PokeAccess::Hooks\.before_hook\("Battle::Scene", :pbFightMenu,.*?^end\r?\n/m], TOPLEVEL_BINDING, v21)

class EssentialsDeluxeGdTest < PokeAccessTest
  Trainer = Struct.new(:name)
  T = PokeAccess::I18n
  # Each mechanic by its flag's place in the menu's call, with the words its button is said in.
  MECHANICS = [[0, :bt_mega_ready, :bt_mega_on, :bt_mega_off],
               [1, :bt_ultra_ready, [:bt_special_on, :bt_m_ultra], [:bt_special_off, :bt_m_ultra]],
               [2, [:bt_special_ready, :bt_m_zmove], [:bt_special_on, :bt_m_zmove], [:bt_special_off, :bt_m_zmove]],
               [3, [:bt_special_ready, :bt_m_dynamax], [:bt_special_on, :bt_m_dynamax], [:bt_special_off, :bt_m_dynamax]],
               [5, [:bt_special_ready, :bt_m_tera], [:bt_special_on, :bt_m_tera], [:bt_special_off, :bt_m_tera]],
               [4, :bt_special_other_ready, :bt_special_other_on, :bt_special_other_off]]

  def words(key)
    key.is_a?(Array) ? T.t(key[0], :name => T.t(key[1])) : T.t(key)
  end

  # The scene with a fight menu on a battler with no move under the cursor, so only the button speaks.
  def fight_scene
    scene = Battle::Scene.new
    scene.fight_window = Battle::Scene::FightMenu.new
    scene
  end

  test "the fight menu's button is said by the mechanic behind it, as it comes up and as it is pressed either way" do
    MECHANICS.each do |place, ready, on, off|
      SpeakCapture.clear
      flags = Array.new(8, false)
      flags[place] = true
      fight_scene.pbFightMenu(0, *flags) do |cw|
        cw.mode = 2
        cw.mode = 1
      end
      assert_equal [[words(ready), false], [words(on), true], [words(off), true]], SpeakCapture.log, "flag #{place}"
    end
  end

  test "several flags up, the button stands for the last, as the menu picks it" do
    fight_scene.pbFightMenu(0, true, false, false, true)
    assert_equal [[words([:bt_special_ready, :bt_m_dynamax]), false]], SpeakCapture.log
  end

  test "a menu with no flag up says no button, and forgets the mechanic of the last one" do
    fight_scene.pbFightMenu(0, false, false, false, true)
    SpeakCapture.clear
    fight_scene.pbFightMenu(0, false)
    assert_equal [], SpeakCapture.log
    assert_nil PokeAccess::Battle.special_action
  end

  test "the speaker's name leads the next scripted line, once" do
    Battle::Scene.new.pbUpdateNameWindow(Trainer.new("Brock"))
    PokeAccess.say_dialogue("¡Mis Pokémon son duros como la roca!")
    PokeAccess.say_dialogue("¡Prepárate!")
    assert_equal [["Brock: ¡Mis Pokémon son duros como la roca!", false], ["¡Prepárate!", false]], SpeakCapture.log
  ensure
    PokeAccess.before_next_line(nil)
  end

  test "a line with no speaker, or a window the call keeps hidden though it holds the name, leads nothing" do
    scene = Battle::Scene.new
    scene.pbUpdateNameWindow(Trainer.new("Brock"))
    scene.pbUpdateNameWindow(nil)
    PokeAccess.say_dialogue("¡El combate sigue!")
    scene.pbUpdateNameWindow(Trainer.new("Misty"), false)
    PokeAccess.say_dialogue("¡Cuidado!")
    assert_equal [["¡El combate sigue!", false], ["¡Cuidado!", false]], SpeakCapture.log
  ensure
    PokeAccess.before_next_line(nil)
  end
end
