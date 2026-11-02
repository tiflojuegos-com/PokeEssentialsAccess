# Essentials BES's battle (plugins/bes_battle.rb): the Z-Move, Dynamax and Tera buttons of the fight menu are said as they
# come up and as they are registered or cancelled, a battler's Dynamax is said, the ability strip is read, the type of a
# move is the one the fight button draws, and the databox icons of the Ultra Burst, Dynamax and Tera states are marks.
require File.expand_path("../../static/reader_sites", File.dirname(__FILE__))
require File.expand_path("../../static/reference_names", File.dirname(__FILE__))

# A battler as the Dynamax message reads it.
class BesDynamaxBattler
  attr_reader :pbThis

  def initialize(name, dynamax, gigantamax)
    @pbThis = name
    @dynamax = dynamax
    @gigantamax = gigantamax
  end

  def isDynamax?; @dynamax; end
  def isGigantamax?; @gigantamax; end
end

BesBattleStub = Struct.new(:battlers)
BesFightMove = Struct.new(:name, :id, :pp, :totalpp, :type)
BesFightBattler = Struct.new(:moves, :pokemon, :battle)

class BesBattleTest < PokeAccessTest
  T = PokeAccess::I18n
  PLUGIN = File.join(Harness::ROOT, "plugins", "bes_battle.rb")
  TARGETS = ["FightMenuDisplay#zButton=", "FightMenuDisplay#dynaButton=", "FightMenuDisplay#teraButton=",
             "PokeBattle_Battle#pbDynamax", "PokeBattle_Battler#showAbilityMessage"].freeze

  def setup
    super
    helper = Module.new do
      def self.get_move_type(_pokemon, move, battle)
        raise "no battle" if battle.nil?
        move.type == 0 ? 10 : move.type
      end
    end
    Object.const_set(:MoveTypeHelper, helper)
  end

  def teardown
    Object.send(:remove_const, :MoveTypeHelper) if Object.const_defined?(:MoveTypeHelper)
    super
  end

  test "the plugin hooks the three buttons, the Dynamax and the ability strip, all of them methods BES defines" do
    sources = { "plugins/bes_battle.rb" => Harness.source(PLUGIN) }
    pairs = ReaderSites.registrations(sources).map { |r| "#{r[:cname]}##{r[:meth]}" }.sort
    assert_equal TARGETS.sort, pairs
    getters = TARGETS.map { |t| t.sub(/=\z/, "") }
    assert_equal [], getters.reject { |t| ReferenceNames.probe?(t) }
  end

  test "a button coming up is said available, queued, in the words of its mechanic" do
    { :@zButton => [:zmove, :bt_m_zmove], :@dynaButton => [:dynamax, :bt_m_dynamax],
      :@teraButton => [:tera, :bt_m_tera] }.each do |ivar, (mech, name)|
      SpeakCapture.clear
      press(Object.new, [ivar, 0], [ivar, 1])
      assert_equal [[T.t(:bt_special_ready, :name => T.t(name)), false]], SpeakCapture.log, mech.to_s
    end
  end

  test "registering Tera says the type its button paints, and cancelling it says no type" do
    disp = Object.new
    disp.instance_variable_set(:@battler, BesFightBattler.new([], Struct.new(:teratype).new(11), :battle))
    press(disp, [:@teraButton, 0], [:@teraButton, 1])
    SpeakCapture.clear
    press(disp, [:@teraButton, 2])
    press(disp, [:@teraButton, 1])
    name = T.t(:bt_m_tera)
    assert_equal [["#{T.t(:bt_special_on, :name => name)}, Tipo11", true], [T.t(:bt_special_off, :name => name), true]],
                 SpeakCapture.log
  end

  test "registering a button and cancelling it are said at once" do
    disp = Object.new
    press(disp, [:@teraButton, 0], [:@teraButton, 1])
    SpeakCapture.clear
    press(disp, [:@teraButton, 2])
    press(disp, [:@teraButton, 1])
    assert_equal [[T.t(:bt_special_on, :name => T.t(:bt_m_tera)), true], [T.t(:bt_special_off, :name => T.t(:bt_m_tera)), true]],
                 SpeakCapture.log
  end

  test "a registered Dynamax reads the focused move again, whose name it changes" do
    disp = fight_menu
    PokeAccess::Battle.read_fight_move(disp, false)
    press(disp, [:@dynaButton, 0], [:@dynaButton, 1])
    SpeakCapture.clear
    press(disp, [:@dynaButton, 2])
    assert_equal [[T.t(:bt_special_on, :name => T.t(:bt_m_dynamax)), true], [surf_line, false]], SpeakCapture.log
  end

  test "a registered Z-Move or Tera button reads no move again, as neither changes its name" do
    [[:@zButton, :bt_m_zmove], [:@teraButton, :bt_m_tera]].each do |ivar, name|
      disp = fight_menu
      PokeAccess::Battle.read_fight_move(disp, false)
      press(disp, [ivar, 0], [ivar, 1])
      SpeakCapture.clear
      press(disp, [ivar, 2])
      assert_equal [[T.t(:bt_special_on, :name => T.t(name)), true]], SpeakCapture.log, name.to_s
    end
  end

  test "the key registering the Dynamax over a Z-Move or Ultra Burst button painted says it on and reads the move" do
    [:@zButton, :@ultraButton].each do |ivar|
      disp = fight_menu
      PokeAccess::Battle.read_fight_move(disp, false)
      press(disp, [ivar, 0], [ivar, 1], [:@dynaButton, 0])
      SpeakCapture.clear
      press(disp, [:@dynaButton, 2])
      assert_equal [[T.t(:bt_special_on, :name => T.t(:bt_m_dynamax)), true], [surf_line, false]], SpeakCapture.log,
                   ivar.to_s
    end
  end

  test "a button that stays hidden or stays as it was says nothing" do
    disp = Object.new
    press(disp, [:@zButton, 0])
    press(disp, [:@zButton, 0])
    assert_nothing_spoken
    press(disp, [:@zButton, 1])
    SpeakCapture.clear
    press(disp, [:@zButton, 1])
    assert_nothing_spoken
  end

  test "the buttons are judged once the menu has set them all, whatever the order it sets them in" do
    disp = Object.new
    set(disp, [:@teraButton, 0], [:@teraButton, 1], [:@zButton, 0], [:@dynaButton, 0], [:@dynaButton, 1])
    assert_nothing_spoken
    PokeAccess::BesBattle.poll
    assert_equal [[T.t(:bt_special_ready, :name => T.t(:bt_m_dynamax)), false]], SpeakCapture.log
  end

  test "of the Dynamax and the Tera buttons that are both up, the menu paints and the player registers the Dynamax" do
    disp = Object.new
    press(disp, [:@teraButton, 0], [:@teraButton, 1], [:@zButton, 0], [:@dynaButton, 0], [:@dynaButton, 1])
    press(disp, [:@dynaButton, 2])
    dynamax = T.t(:bt_m_dynamax)
    assert_equal [[T.t(:bt_special_ready, :name => dynamax), false], [T.t(:bt_special_on, :name => dynamax), true]],
                 SpeakCapture.log
  end

  test "the Tera button is said once the Dynamax button is not up" do
    disp = Object.new
    press(disp, [:@teraButton, 0], [:@teraButton, 1], [:@dynaButton, 0], [:@dynaButton, 1])
    SpeakCapture.clear
    press(disp, [:@teraButton, 0], [:@teraButton, 1], [:@dynaButton, 0])
    assert_equal [[T.t(:bt_special_ready, :name => T.t(:bt_m_tera)), false]], SpeakCapture.log
  end

  test "a button the menu paints under another is not said: all of them under the Mega, the Z-Move under the Ultra Burst" do
    mega = Object.new
    press(mega, [:@megaButton, 0], [:@megaButton, 1], [:@teraButton, 0], [:@teraButton, 1], [:@zButton, 0], [:@zButton, 1],
          [:@dynaButton, 0], [:@dynaButton, 1])
    assert_nothing_spoken "under the Mega"
    ultra = Object.new
    press(ultra, [:@ultraButton, 0], [:@ultraButton, 1], [:@zButton, 0], [:@zButton, 1])
    assert_nothing_spoken "under the Ultra Burst"
  end

  test "the Tera button is painted ahead of the Ultra Burst one, so it is said" do
    press(Object.new, [:@ultraButton, 0], [:@ultraButton, 1], [:@teraButton, 0], [:@teraButton, 1])
    assert_equal [[T.t(:bt_special_ready, :name => T.t(:bt_m_tera)), false]], SpeakCapture.log
  end

  test "a new turn says its button again" do
    disp = Object.new
    2.times do
      press(disp, [:@zButton, 0], [:@zButton, 1])
    end
    assert_equal [T.t(:bt_special_ready, :name => T.t(:bt_m_zmove))] * 2, SpeakCapture.lines
  end

  test "judging a menu once its frame is over leaves nothing waiting" do
    disp = Object.new
    PokeAccess::BesBattle.touched(disp, 1)
    PokeAccess::BesBattle.poll
    SpeakCapture.clear
    PokeAccess::BesBattle.poll
    assert_nothing_spoken
  end

  test "menus waiting to be judged are forgotten with the other caches" do
    PokeAccess::BesBattle.touched(Object.new, 1)
    PokeAccess::BesBattle.reset
    PokeAccess::BesBattle.poll
    assert_nothing_spoken
  end

  test "through its hooks, a new turn says the button again" do
    attached(BOUND) do
      menu = Display.new
      2.times do
        [:teraButton=, :zButton=].each { |setter| menu.send(setter, 0) }
        menu.teraButton = 1
        PokeAccess::Frame.run_pollers
      end
    end
    assert_equal [T.t(:bt_special_ready, :name => T.t(:bt_m_tera))] * 2, SpeakCapture.lines
  end

  test "through its hooks, the fight menu's buttons are said as the game sets them, a frame later" do
    attached(BOUND) do
      menu = Display.new
      [:teraButton=, :zButton=].each { |setter| menu.send(setter, 0) }
      menu.teraButton = 1
      assert_nothing_spoken
      PokeAccess::Frame.run_pollers
      menu.teraButton = 2
      PokeAccess::Frame.run_pollers
    end
    assert_equal [[T.t(:bt_special_ready, :name => T.t(:bt_m_tera)), false],
                  [T.t(:bt_special_on, :name => T.t(:bt_m_tera)), true]], SpeakCapture.log
  end

  test "a battler that Dynamaxes is said by the name the game's messages give it" do
    battle = BesBattleStub.new([BesDynamaxBattler.new("Pikachu", true, false), BesDynamaxBattler.new("El Onix rival", true, true)])
    PokeAccess::BesBattle.dynamaxed(battle, 0)
    PokeAccess::BesBattle.dynamaxed(battle, 1)
    assert_equal [[T.t(:bes_dynamaxed, :name => "Pikachu"), false], [T.t(:bes_gigantamaxed, :name => "El Onix rival"), false]],
                 SpeakCapture.log
  end

  test "a battler that tells nothing of Gigantamax is said as a Dynamax" do
    plain = Class.new { def isDynamax?; true; end; def pbThis; "Pikachu"; end }.new
    PokeAccess::BesBattle.dynamaxed(BesBattleStub.new([plain]), 0)
    assert_equal [[T.t(:bes_dynamaxed, :name => "Pikachu"), false]], SpeakCapture.log
  end

  test "through its hook, a Dynamax is said for the battler at the index the battle was given" do
    attached(BOUND) do
      Match.new([BesDynamaxBattler.new("Pikachu", false, false), BesDynamaxBattler.new("Onix", true, false)]).pbDynamax(1)
    end
    assert_equal [[T.t(:bes_dynamaxed, :name => "Onix"), false]], SpeakCapture.log
  end

  test "through its hook, the ability strip is held for the battler it is given, not the one it runs on" do
    shown = Struct.new(:pokemon, :ability).new(Struct.new(:name).new("Pikachu"), 9)
    attached(BOUND) { Fighter.new.showAbilityMessage(shown) }
    assert_nothing_spoken
    PokeAccess::BattleScene.flush_strip
    assert_equal [[T.t(:bt_ability, :name => "Pikachu", :ability => "Habilidad9"), false]], SpeakCapture.log
  end

  test "a Dynamax that did not happen says nothing" do
    battle = BesBattleStub.new([BesDynamaxBattler.new("Pikachu", false, false), nil])
    PokeAccess::BesBattle.dynamaxed(battle, 0)
    PokeAccess::BesBattle.dynamaxed(battle, 1)
    assert_nothing_spoken
  end

  test "the fight button's type is the one the game's helper works out, else the move's own" do
    move = BesFightMove.new("Weather Ball", 311, 10, 10, 0)
    assert_equal 10, PokeAccess::Battle.fight_type(move, BesFightBattler.new([move], :pokemon, :battle))
    assert_equal 0, PokeAccess::Battle.fight_type(move, BesFightBattler.new([move], :pokemon, nil))
    Object.send(:remove_const, :MoveTypeHelper)
    assert_equal 0, PokeAccess::Battle.fight_type(move, BesFightBattler.new([move], :pokemon, :battle))
  end

  test "the databox icons of the Ultra Burst, Dynamax and Tera states are marks, as the game draws them" do
    icons = ["Graphics/Pictures/Battle/battleUltraBurstBox", "Graphics/Pictures/Battle/battleDynamaxBox.png",
             "Graphics/Pictures/teraTypes"]
    assert_equal [T.t(:bt_m_ultra), T.t(:bt_m_dynamax), T.t(:bt_m_tera)], PokeAccess::Battle.marks_of(icons)
  end

  private

  # Sets the buttons of a menu as the game does, [ivar, state] one after another, each reported to the plugin.
  def set(disp, *buttons)
    buttons.each do |ivar, state|
      disp.instance_variable_set(ivar, state)
      PokeAccess::BesBattle.touched(disp, state)
    end
  end

  # Sets them and lets the frame end, when they are judged.
  def press(disp, *buttons)
    set(disp, *buttons)
    PokeAccess::BesBattle.poll
  end

  # The line of the fight menu's move, as the fight menu reads it.
  def surf_line
    ["Surf", T.t(:mv_type, :t => "Tipo11"), T.t(:cat_special), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". ")
  end

  def fight_menu
    surf = BesFightMove.new("Surf", 58, 15, 15, 11)
    disp = Object.new
    disp.instance_variable_set(:@battler, BesFightBattler.new([surf], :pokemon, :battle))
    disp.instance_variable_set(:@index, 0)
    disp
  end

  # The fight menu as BES defines it, as far as the hooks go: a setter for each button.
  Display = Class.new do
    def zButton=(v); @zButton = v; end
    def dynaButton=(v); @dynaButton = v; end
    def teraButton=(v); @teraButton = v; end
  end

  # The battle, whose pbDynamax BES runs with no message, and a battler, whose showAbilityMessage slides the strip in
  # for the battler it is given.
  Match = Class.new do
    attr_reader :battlers
    def initialize(battlers); @battlers = battlers; end
    def pbDynamax(_index); :done; end
  end

  Fighter = Class.new do
    def showAbilityMessage(_battler, _hide = true); :shown; end
  end

  # Runs the block with the hook chains bound to the stand-ins at load attached, then takes them away, putting back
  # whatever chains held those keys before. The stand-ins hold the game's names only while bind evaluates the plugin.
  def attached(bound)
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    held = bound.keys.select { |k| chains.key?(k) }.map { |k| [k, chains[k]] }
    chains.update(bound)
    yield
  ensure
    bound.each_key { |k| chains.delete(k) }
    (held || []).each { |k, v| chains[k] = v }
  end

  class << self
    private

    # Evaluates the plugin over the stand-ins set for the moment under their game names (top-level name => class), and
    # answers the hook chains bound to them, to attach per test; all else the evaluation changed (the names, other
    # chains, function bodies, overrides, the missing list and the battle marks) is put back as it was.
    def bind(stand_ins, rels)
      hooks = PokeAccess::Hooks
      chains = hooks.instance_variable_get(:@chains)
      chains_was = {}
      chains.each { |k, v| chains_was[k] = v.dup }
      bodies_was = {}
      hooks.fn_bodies.each { |k, v| bodies_was[k] = v.dup }
      overrides = hooks.overrides.length
      missing = hooks.missing.dup
      marks = PokeAccess::Battle::ICON_MARKS.dup
      ours = lambda { |key| stand_ins.keys.any? { |n| key.start_with?("#{n}#", "#{n}::") } }
      chains.delete_if { |k, _v| ours.call(k) }
      priors = stand_ins.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
      stand_ins.each { |n, k| Object.const_set(n, k) }
      verbose = $VERBOSE
      $VERBOSE = nil
      rels.each do |rel|
        path = File.join(Harness::ROOT, rel)
        eval(Harness.source(path), TOPLEVEL_BINDING, path)
      end
      chains.select { |k, _v| ours.call(k) }
    ensure
      $VERBOSE = verbose
      stand_ins.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
      (priors || []).each { |n, k| Object.const_set(n, k) if k }
      (chains.keys - chains_was.keys).each do |key|
        cname, meth = key.split("#", 2)
        k = PokeAccess.const_at(cname)
        orig = "#{meth}__pa_orig_#{cname.gsub(/[^a-zA-Z0-9]/, '_')}"
        unwrap = !ours.call(key) && k.is_a?(Module) && (k.method_defined?(orig) || k.private_method_defined?(orig))
        k.send(:alias_method, meth, orig) if unwrap
        chains.delete(key)
      end
      chains_was.each { |k, v| chains[k] = v }
      bodies = hooks.fn_bodies
      bodies.keys.each { |k| bodies_was.key?(k) ? bodies[k].replace(bodies_was[k]) : bodies.delete(k) }
      hooks.overrides.slice!(overrides..-1)
      hooks.missing.replace(missing)
      PokeAccess::Battle::ICON_MARKS.replace(marks)
    end
  end

  # The plugin's hook chains on the stand-ins, bound once as this file loads, so every test's reading counts.
  BOUND = bind({ :FightMenuDisplay => Display, :PokeBattle_Battle => Match, :PokeBattle_Battler => Fighter },
               ["plugins/bes_battle.rb"])
end
