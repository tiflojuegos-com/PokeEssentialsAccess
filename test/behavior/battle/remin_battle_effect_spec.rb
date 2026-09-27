# Reminiscencia's fight menu paints the focused move's effectiveness against the foe as an icon (rewriteType) with
# the foe's type icons, hidden by an option; and its hits float "-N PS" or "-X%" with "¡Muy eficaz!" or "Poco
# eficaz..." over the target, the messages being commented out. The module is evaluated alone; the hit points
# override is evaluated from its own block and the core's method put back after.
module RemBattleFixture
  PATH = File.join(Harness::ROOT, "games", "reminiscencia", "battle_effect.rb")
  eval(File.read(PATH)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, PATH) unless defined?(PokeAccess::ReminBattle)

  Icon = Struct.new(:name, :visible)
  Window = Struct.new(:index)
  Battle = Struct.new(:battlers, :doublebattle, :sosbattle)
  SceneRef = Struct.new(:scene)

  # A battler as the menu and the hit read it: its name, types, fainted state, and the battle it is in.
  class Foe
    attr_accessor :name, :hp, :totalhp, :index, :battle
    def initialize(name, types, fainted = false); @name = name; @types = types; @fainted = fainted; end
    def pbTypes(_withtype3 = false); @types; end
    def isFainted?; @fainted; end
  end

  # A battle scene with the fight menu's sprites.
  def self.scene(battle, icon_file, visible = true)
    s = Object.new
    s.instance_variable_set(:@battle, battle)
    s.instance_variable_set(:@sprites, { "effectivenessIcon" => Icon.new("Graphics/Pictures/EffectivenessCheck/#{icon_file}", visible),
                                         "fightwindow" => Window.new(0) })
    s
  end
end

Suite.define("reminiscencia battle: the fight menu says the effectiveness icon and, in full, the foe's types") do
  t = PokeAccess::I18n
  rb = PokeAccess::ReminBattle
  me = RemBattleFixture::Foe.new("Chispa", [13])
  foe = RemBattleFixture::Foe.new("Gyarados", [11, 2])
  battle = RemBattleFixture::Battle.new([me, foe, nil, nil], false, false)
  scene = RemBattleFixture.scene(battle, "x2")
  types = [11, 2].map { |ty| PokeAccess::Data.type_name(ty) }.join(" ")
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :rem_effect)
    SpeakCapture.clear
    rb.fight_effect(scene, [11])
    SpeakCapture.last
  end
  eq "brief: the icon's word", rows[0], t.t(:mv_eff_super)
  eq "full: and the foe with its type icons", rows[2],
     "#{t.t(:mv_eff_super)}. #{t.t(:rem_bt_foe_types, :name => 'Gyarados', :t => types)}"
  SpeakCapture.clear
  rb.fight_effect(scene, [11])
  silent "the same focus is not said twice"
  { "x0" => :mv_eff_none, "m4" => :mv_eff_barely, "m2" => :mv_eff_weak, "x1" => :mv_eff_neutral,
    "x4" => :mv_eff_hyper }.each do |file, key|
    s = RemBattleFixture.scene(battle, file)
    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    rb.fight_effect(s, [0])
    eq "#{file} is #{key}", SpeakCapture.last, t.t(key)
  end
  PokeAccess::Config.verbosity = :full
  hidden = RemBattleFixture.scene(battle, "x2", false)
  SpeakCapture.clear
  rb.fight_effect(hidden, [11])
  silent "nothing while the game hides the icons"
  other = RemBattleFixture::Foe.new("Onix", [5, 4])
  doubles = RemBattleFixture::Battle.new([me, RemBattleFixture::Foe.new("Caido", [0], true), nil, other], true, false)
  SpeakCapture.clear
  rb.fight_effect(RemBattleFixture.scene(doubles, "x0"), [0])
  truthy "in a double battle with the first foe down, the other one", SpeakCapture.last.to_s.include?("Onix")
end

Suite.define("reminiscencia battle: a hit says the effectiveness it floats and, with the percent option, a share") do
  t = PokeAccess::I18n
  path = RemBattleFixture::PATH
  block = File.read(path)[/^PokeAccess::Game\.define\("reminiscencia"\) do\r?\n  override\("PokeAccess::Battle", :announce_hp_change\).*?^end\r?\n/m]
  bt = PokeAccess::Battle
  saved = bt.method(:announce_hp_change)
  saved_sys = $PokemonSystem
  truthy "the profile's block is found", !block.nil?
  begin
    eval(block, TOPLEVEL_BINDING, path)
    scene = Object.new
    foe = RemBattleFixture::Foe.new("Gyarados", [11, 2])
    foe.hp = 70
    foe.totalhp = 80
    foe.index = 1
    foe.battle = RemBattleFixture::SceneRef.new(scene)
    rest = bt.shown_hp(foe, true)
    PokeAccess::ReminBattle.note_hit(foe, 2)
    SpeakCapture.clear
    bt.hp_changed(foe, 80)
    eq "a super effective hit, as the text over it", SpeakCapture.lines,
       ["#{t.t(:mv_eff_super)}. #{t.t(:bt_hp_change, :name => 'Gyarados', :verb => t.t(:bt_lose), :n => 10, :rest => rest)}"]
    PokeAccess::ReminBattle.note_hit(foe, 1)
    $PokemonSystem = Struct.new(:porcentaje).new(1)
    SpeakCapture.clear
    bt.hp_changed(foe, 80)
    eq "with the percent option, the share of the total the text paints", SpeakCapture.lines,
       ["#{t.t(:mv_eff_weak)}. #{t.t(:rem_bt_hp_change_pct, :name => 'Gyarados', :verb => t.t(:bt_lose), :n => '12,5', :rest => rest)}"]
    SpeakCapture.clear
    bt.hp_changed(foe, 80)
    eq "a later loss with no hit behind it, such as poison, leaves out the word the game keeps painted",
       SpeakCapture.lines,
       [t.t(:rem_bt_hp_change_pct, :name => 'Gyarados', :verb => t.t(:bt_lose), :n => '12,5', :rest => rest)]
    SpeakCapture.clear
    bt.hp_changed(foe, 60)
    eq "a gain floats no effectiveness", SpeakCapture.lines,
       [t.t(:rem_bt_hp_change_pct, :name => 'Gyarados', :verb => t.t(:bt_gain), :n => '12,5', :rest => rest)]
    eq "a whole share has no decimals", PokeAccess::ReminBattle.percent_text(20, 80), "25"
  ensure
    bt.define_singleton_method(:announce_hp_change, saved)
    $PokemonSystem = saved_sys
  end
end
