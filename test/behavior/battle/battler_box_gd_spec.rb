# The sex sign and level the HP and info keys say are the ones each databox draws: plain, Deluxe Battle Kit styled
# and profile-overridden boxes. Gamedata pass (it loads the Deluxe Battle Kit reader).
class BoxBattler
  attr_reader :index, :name, :level, :hp, :totalhp, :gender, :displayGender, :battle, :status
  def initialize(index, gender, shown, battle)
    @index = index; @gender = gender; @displayGender = shown; @battle = battle
    @name = "Zorua"; @level = 30; @hp = 50; @totalhp = 100; @status = :NONE
  end
  def pokemon; true; end
end

# A battle whose scene holds the given databoxes under the names the scene keeps them by.
def box_battle(boxes)
  scene = Object.new
  scene.instance_variable_set(:@sprites, boxes)
  battle = Object.new
  battle.instance_variable_set(:@scene, scene)
  def battle.scene; @scene; end
  battle
end

def styled_box(id, klass = Object)
  box = klass.new
  box.instance_variable_set(:@style, Struct.new(:id).new(id))
  box
end

# Every method a box profile can override, on the Battle module and on the Deluxe Battle Kit panel.
BOX_SEAMS = [[PokeAccess::Battle, [:shown_sex, :shown_level, :shown_hp]],
             [PokeAccess::DBKBattlerInfo, [:panel_level]]]

# Runs the block with a profile's battle-box override loaded, and takes it back after.
def with_box_profile(path)
  BOX_SEAMS.each do |mod, names|
    meta = (class << mod; self; end)
    names.each { |n| meta.send(:alias_method, "box_spec_#{n}".to_sym, n) }
  end
  load File.expand_path("../../../games/" + path, File.dirname(__FILE__))
  yield
ensure
  BOX_SEAMS.each do |mod, names|
    meta = (class << mod; self; end)
    names.each do |n|
      meta.send(:alias_method, n, "box_spec_#{n}".to_sym)
      meta.send(:remove_method, "box_spec_#{n}".to_sym)
    end
  end
end

Suite.define("battle boxes: the plain box says the sign it shows and the level") do
  t = PokeAccess::I18n
  battle = box_battle("dataBox_1" => Object.new)
  foe = BoxBattler.new(1, 0, 1, battle)
  eq "a foe under Illusion says the sign of the one it imitates, and its level",
     PokeAccess::Battle.battler_state(foe, true),
     t.t(:bt_state, :name => "Zorua \xE2\x99\x80", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
end

Suite.define("battle boxes: a Deluxe Battle Kit styled box says what draw_style_text draws") do
  t = PokeAccess::I18n
  battle = box_battle("dataBox_0" => styled_box(:Long), "dataBox_1" => styled_box(:Long))
  mine = BoxBattler.new(0, 0, 1, battle)
  foe = BoxBattler.new(1, 0, 1, battle)
  eq "its own side: the sign of the Pokemon itself, not the one Illusion shows, and the level",
     PokeAccess::Battle.battler_state(mine, false),
     t.t(:bt_state, :name => "Zorua \xE2\x99\x82", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, false))
  eq "a foe: its name alone", PokeAccess::Battle.battler_state(foe, true),
     t.t(:bt_state_nolevel, :name => "Zorua", :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
end

Suite.define("battle boxes: Relict's styled foe says its real sign and level") do
  t = PokeAccess::I18n
  with_box_profile("relict/styled_box.rb") do
    battle = box_battle("dataBox_1" => styled_box(:Long), "dataBox_3" => Object.new)
    foe = BoxBattler.new(1, 0, 1, battle)
    eq "the name, the real sign and the level, as Relict's copy draws them", PokeAccess::Battle.battler_state(foe, true),
       t.t(:bt_state, :name => "Zorua \xE2\x99\x82", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
    plain = BoxBattler.new(3, 0, 1, battle)
    eq "and a plain box is still the core's", PokeAccess::Battle.battler_state(plain, true),
       t.t(:bt_state, :name => "Zorua \xE2\x99\x80", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
  end
end

# The Battle module's own form of a method, under every override stacked on it: the first override keeps it
# under the lowest numbered alias.
def box_core_form(name)
  meta = (class << PokeAccess::Battle; self; end)
  first = meta.instance_methods.map { |m| m.to_s }.grep(/\A#{name}__pa_override_\d+\z/).min_by { |m| m[/\d+\z/].to_i }
  PokeAccess::Battle.method(first || name)
end

# Soulstones 2's raid box over the core shown_sex and shown_level: the game has no Deluxe Battle Kit, whose override
# answers every styled box alike.
Suite.define("battle boxes: Soulstones 2's raid box says a foe's name, and the level in the Basic style only") do
  t = PokeAccess::I18n
  made = !Battle::Scene.const_defined?(:RaidPokemonDataBox)
  Battle::Scene.const_set(:RaidPokemonDataBox, Class.new) if made
  chained = { :shown_sex => PokeAccess::Battle.method(:shown_sex), :shown_level => PokeAccess::Battle.method(:shown_level) }
  chained.each_key { |n| PokeAccess::Battle.define_singleton_method(n, box_core_form(n)) }
  begin
    with_box_profile("soulstones2/styled_box.rb") do
      k = Battle::Scene::RaidPokemonDataBox
      battle = box_battle("dataBox_0" => styled_box(:Long, k), "dataBox_1" => styled_box(:Long, k),
                          "dataBox_3" => styled_box(:Basic, k))
      eq "a raid foe: the name alone", PokeAccess::Battle.battler_state(BoxBattler.new(1, 0, 1, battle), true),
         t.t(:bt_state_nolevel, :name => "Zorua", :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
      eq "a foe in the Basic style: its level too", PokeAccess::Battle.battler_state(BoxBattler.new(3, 0, 1, battle), true),
         t.t(:bt_state, :name => "Zorua", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
      eq "its own side: the real sign and the level", PokeAccess::Battle.battler_state(BoxBattler.new(0, 0, 1, battle), false),
         t.t(:bt_state, :name => "Zorua \xE2\x99\x82", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, false))
    end
  ensure
    chained.each { |n, m| PokeAccess::Battle.define_singleton_method(n, m) }
    Battle::Scene.send(:remove_const, :RaidPokemonDataBox) if made
  end
end

Suite.define("battle boxes: Awakening's boss box says no sign, and no level for a foe") do
  t = PokeAccess::I18n
  with_box_profile("awakening/boss_box.rb") do
    battle = box_battle({})
    foe = BoxBattler.new(1, 0, 0, battle)
    mine = BoxBattler.new(0, 1, 1, battle)
    begin
      $game_switches[200] = true
      eq "a boss foe: its name and its bar", PokeAccess::Battle.battler_state(foe, true),
         t.t(:bt_state_nolevel, :name => "Zorua", :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
      eq "the player's own: its name and level, no sign", PokeAccess::Battle.battler_state(mine, false),
         t.t(:bt_state, :name => "Zorua", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, false))
      $game_switches[200] = false
      eq "outside a boss battle the box is the plain one", PokeAccess::Battle.battler_state(foe, true),
         t.t(:bt_state, :name => "Zorua \xE2\x99\x82", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
    ensure
      $game_switches.delete(200)
    end
  end
end

# A boss given lives (variable 189) draws one life icon in its box for each life past the current one; the bar breaking
# (pbBreakBar, run once the life is taken) says the life lost and the icons left. The scene is Awakening's name, stood
# in only here, so the break hook binds to it once.
Suite.define("battle boxes: Awakening's boss says its life icons with its bar, and a broken bar the life it lost") do
  t = PokeAccess::I18n
  made = !Object.const_defined?(:PokeBattle_Scene)
  Object.const_set(:PokeBattle_Scene, Class.new { def pbBreakBar(_b); :flashed; end }) if made
  verbose = $VERBOSE
  begin
    $VERBOSE = nil
    with_box_profile("awakening/boss_box.rb") do
      boss = BoxBattler.new(1, 0, 0, box_battle({}))
      class << boss; attr_accessor :lives; end
      boss.lives = 3
      $game_switches[200] = true
      hp = PokeAccess::Battle.hp_phrase(50, 100, true)
      eq "three lives: the bar, then the two icons past it", PokeAccess::Battle.battler_state(boss, true),
         t.t(:bt_state_nolevel, :name => "Zorua", :hp => "#{hp}, #{t.t(:awk_lives, :n => 2)}")
      boss.lives = 2
      SpeakCapture.clear
      eq "the scene's own break runs", PokeBattle_Scene.new.pbBreakBar(boss), :flashed
      eq "the life lost, and the icon left", SpeakCapture.lines,
         [t.t(:awk_life_lost, :name => "Zorua", :rest => t.t(:awk_lives_left, :n => 1))]
      boss.lives = 1
      SpeakCapture.clear
      PokeBattle_Scene.new.pbBreakBar(boss)
      eq "on the last one, that it is the last", SpeakCapture.lines,
         [t.t(:awk_life_lost, :name => "Zorua", :rest => t.t(:awk_lives_last))]
      eq "and with no icon left, the bar alone", PokeAccess::Battle.battler_state(boss, true),
         t.t(:bt_state_nolevel, :name => "Zorua", :hp => hp)
    end
  ensure
    $VERBOSE = verbose
    $game_switches.delete(200)
    Object.send(:remove_const, :PokeBattle_Scene) if made && Object.const_defined?(:PokeBattle_Scene)
  end
end

# Every screen that draws the sex sign has it said as that sign, from the Pokemon the screen draws.
Suite.define("sex signs: the summary, the glance, Better Summary, the DBK panel and the grids say the sign drawn") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Chispa", :gender => 1)
  truthy "the summary's first page: the name with its sign", PokeAccess::SummaryGameData.info_text(pk).to_s.index("Chispa \xE2\x99\x80")
  truthy "the data sheet the info key reads", PokeAccess::Info.summary_text(pk).to_s.index("Chispa \xE2\x99\x80")
  truthy "the at-a-glance line", PokeAccess::Info.pokemon_info(pk).to_s.index("\xE2\x99\x80")
  eq "Better Summary's ability page: the sign it paints, then the item line", PokeAccess::BetterSummary.extras(pk).first, "\xE2\x99\x80"

  real = Poke.build(:name => "Zoroark", :gender => 0)
  shown = Poke.build(:name => "Absol", :gender => 1)
  foe = Object.new
  foe.instance_variable_set(:@shown, shown)
  foe.instance_variable_set(:@real, real)
  def foe.name; "Absol"; end
  def foe.opposes?; true; end
  def foe.displayPokemon; @shown; end
  def foe.pokemon; @real; end
  def foe.isRaidBoss?; false; end
  parts = PokeAccess::DBKBattlerInfo.identity_parts(foe)
  truthy "the DBK panel says the sign of the Pokemon a foe displays", parts.include?("\xE2\x99\x80")
  falsy "never the one Illusion hides", parts.include?("\xE2\x99\x82")
  def foe.isRaidBoss?; true; end
  falsy "and none on a raid boss, whose panel draws none", PokeAccess::DBKBattlerInfo.identity_parts(foe).include?("\xE2\x99\x80")

  battle = Object.new
  battle.instance_variable_set(:@mine, [foe])
  battle.instance_variable_set(:@foes, [foe])
  def battle.allSameSideBattlers; @mine; end
  def battle.allOtherSideBattlers; @foes; end
  def battle.pbGetOwnerFromBattlerIndex(_i); nil; end
  scene = Object.new
  scene.instance_variable_set(:@battle, battle)
  eq "the selection grid: the player's own slot by the Pokemon itself, with its sign",
     PokeAccess::DBKSelectors.battler_text(scene, 0, 0), "Zoroark \xE2\x99\x82"
  eq "and a raid boss's slot with no sign", PokeAccess::DBKSelectors.battler_text(scene, 1, 0), "Absol"
  def foe.isRaidBoss?; false; end
  eq "a foe's slot by the Pokemon it displays, with that one's sign",
     PokeAccess::DBKSelectors.battler_text(scene, 1, 0), "Absol \xE2\x99\x80"
end

Suite.define("battle boxes: Reminiscencia's box says every battler's hit points as painted, and no level") do
  t = PokeAccess::I18n
  with_box_profile("reminiscencia/battle_box.rb") do
    foe = BoxBattler.new(1, 0, 0, box_battle({}))
    saved = $PokemonSystem
    $PokemonSystem = Struct.new(:porcentaje).new(0)
    begin
      eq "a foe's exact hit points, which its box shows, and no level, which no box shows",
         PokeAccess::Battle.battler_state(foe, true),
         t.t(:bt_state_nolevel, :name => "Zorua \xE2\x99\x82", :hp => PokeAccess::Battle.hp_phrase(50, 100, false))
      $PokemonSystem.porcentaje = 1
      eq "and a percentage with the game's own option on", PokeAccess::Battle.battler_state(foe, true),
         t.t(:bt_state_nolevel, :name => "Zorua \xE2\x99\x82", :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
    ensure
      $PokemonSystem = saved
    end
  end
end

Suite.define("battle boxes: Royal's special battle says the foe's level as the unknown its box paints") do
  t = PokeAccess::I18n
  with_box_profile("royal/zacian_battle.rb") do
    battle = box_battle({})
    foe = BoxBattler.new(1, 0, 0, battle)
    mine = BoxBattler.new(0, 0, 0, battle)
    begin
      $game_switches[84] = true
      eq "the foe: a level unknown", PokeAccess::Battle.battler_state(foe, true),
         t.t(:bt_state, :name => "Zorua \xE2\x99\x82", :level => t.t(:bt_level_unknown), :hp => PokeAccess::Battle.hp_phrase(50, 100, true))
      eq "the player's own keeps its level", PokeAccess::Battle.battler_state(mine, false),
         t.t(:bt_state, :name => "Zorua \xE2\x99\x82", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, false))
      eq "and the battler panel paints the same placeholder", PokeAccess::DBKBattlerInfo.panel_level(foe), :unknown
      $game_switches[84] = false
      eq "outside that battle the level is the foe's", PokeAccess::DBKBattlerInfo.panel_level(foe), 30
    ensure
      $game_switches.delete(84)
    end
  end
end

Suite.define("battle boxes: Infinite Fusion's no-levels mode says no level") do
  t = PokeAccess::I18n
  made = !Object.const_defined?(:SWITCH_NO_LEVELS_MODE)
  Object.const_set(:SWITCH_NO_LEVELS_MODE, 774) if made
  begin
    with_box_profile("infinitefusion_common/no_levels.rb") do
      mine = BoxBattler.new(0, 0, 0, box_battle({}))
      $game_switches[774] = true
      eq "with the mode on, no level for anyone", PokeAccess::Battle.battler_state(mine, false),
         t.t(:bt_state_nolevel, :name => "Zorua \xE2\x99\x82", :hp => PokeAccess::Battle.hp_phrase(50, 100, false))
      $game_switches[774] = false
      eq "with it off, the level", PokeAccess::Battle.battler_state(mine, false),
         t.t(:bt_state, :name => "Zorua \xE2\x99\x82", :level => 30, :hp => PokeAccess::Battle.hp_phrase(50, 100, false))
    end
  ensure
    $game_switches.delete(774)
    Object.send(:remove_const, :SWITCH_NO_LEVELS_MODE) if made
  end
end

# The info key's foe line: its types follow an Illusion, as its name and sign do.
Suite.define("battle boxes: a foe's types are the ones it is shown with") do
  made = !Object.const_defined?(:PBEffects)
  Object.const_set(:PBEffects, Module.new) if made
  PBEffects.const_set(:Illusion, 42) unless PBEffects.const_defined?(:Illusion)
  begin
    zoroark = Poke.build(:name => "Zoroark")
    def zoroark.types; [:DARK]; end
    disguise = Poke.build(:name => "Pikachu")
    def disguise.types; [:ELECTRIC]; end
    foe = BoxBattler.new(1, 0, 0, box_battle({}))
    foe.instance_variable_set(:@effects, { PBEffects::Illusion => disguise })
    foe.instance_variable_set(:@pk, zoroark)
    def foe.effects; @effects; end
    def foe.pokemon; @pk; end
    eq "under Illusion, the disguise's types", PokeAccess::Battle.shown_types(foe), ["TypeELECTRIC"]
    foe.instance_variable_set(:@effects, {})
    def foe.pbTypes(_with_third = false); [:WATER]; end
    eq "else the ones the battle has, a type changed by a move included", PokeAccess::Battle.shown_types(foe), ["TypeWATER"]
  ensure
    Object.send(:remove_const, :PBEffects) if made
  end
end

Suite.define("battle boxes: the DBK panel names the player's own Pokemon as it is, under Illusion too") do
  real = Poke.build(:name => "Zoroark", :gender => 0)
  mine = Object.new
  mine.instance_variable_set(:@real, real)
  def mine.name; "Absol"; end
  def mine.opposes?; false; end
  def mine.pokemon; @real; end
  def mine.isRaidBoss?; false; end
  eq "the name and sign the panel paints for its own side", PokeAccess::DBKBattlerInfo.identity_parts(mine)[0, 2],
     ["Zoroark", "\xE2\x99\x82"]
end

# The stat stages close the DBK panel as a part of their own, without the leading stop Battle.stat_changes writes.
Suite.define("battle boxes: the DBK panel says the stat changes with no stop stranded before them") do
  foe = Object.new
  foe.instance_variable_set(:@stages, { :ATTACK => -1 })
  def foe.lastMoveUsed; nil; end
  parts = PokeAccess::DBKBattlerInfo.detail_parts(foe, false)
  eq "the changes, as the H key words them, without its stop", parts.last,
     PokeAccess::Battle.stat_changes(foe).sub(/\A\.\s*/, "")
  falsy "and no part starts with a stop", parts.any? { |p| p.start_with?(".") }
end
