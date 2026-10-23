# The stock gen-6 fight menu's Mega Evolution and Ultra Burst buttons (megaButton=, ultraButton=, set every turn: 0
# hidden, 1 available, 2 pressed): a button coming up is said queued, behind the move; pressing and releasing it is
# said at once. The gen-6 battle hooks are evaluated again over a FightMenuDisplay made here, as this file loads.
class MegaReadyTest < PokeAccessTest
  T = PokeAccess::I18n

  # The stock gen-6 FightMenuDisplay as far as the hooks go: the cursor, the battler and the two buttons.
  Display = Class.new do
    def initialize; @index = 0; @battler = nil; end
    def setIndex(v); @index = v; end
    def battler=(b); @battler = b; end
    def megaButton=(v); @megaButton = v; end
    def ultraButton=(v); @ultraButton = v; end
  end

  test "says the Mega button coming up, queued behind the move the menu opens on" do
    with_fight_menu do |menu|
      menu.battler = Struct.new(:moves).new([Struct.new(:name, :id, :pp, :totalpp).new("Ember", 1, 15, 15)])
      menu.setIndex(0)
      menu.megaButton = 1
    end
    move = ["Ember", T.t(:cat_special), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". ")
    assert_equal [[move, true], [T.t(:bt_mega_ready), false]], SpeakCapture.log
  end

  test "says pressing and releasing the Mega button at once" do
    with_fight_menu do |menu|
      menu.megaButton = 1
      SpeakCapture.clear
      menu.megaButton = 2
      menu.megaButton = 1
    end
    assert_equal [[T.t(:bt_mega_on), true], [T.t(:bt_mega_off), true]], SpeakCapture.log
  end

  test "says the Mega button coming up again each turn" do
    with_fight_menu do |menu|
      [0, 1, 2, 0, 1].each { |v| menu.megaButton = v }
    end
    assert_equal [[T.t(:bt_mega_ready), false], [T.t(:bt_mega_on), true], [T.t(:bt_mega_ready), false]],
                 SpeakCapture.log
  end

  test "says nothing for a button that stays hidden, stays as it was or is set pressed straight away" do
    [[0, 0], [1, 1], [2, 2], [0, 2], [nil, 2], [1, 0], [2, 0], [1, 3]].each do |from, to|
      with_fight_menu do |menu|
        menu.megaButton = from unless from.nil?
        SpeakCapture.clear
        menu.megaButton = to
      end
      assert_nothing_spoken "from #{from.inspect} to #{to}"
    end
  end

  test "says the Ultra Burst button in its own words" do
    with_fight_menu do |menu|
      [0, 1, 2, 1].each { |v| menu.ultraButton = v }
    end
    assert_equal [[T.t(:bt_ultra_ready), false], [T.t(:bt_ultra_on), true], [T.t(:bt_ultra_off), true]],
                 SpeakCapture.log
  end

  test "keeps each button's state apart" do
    with_fight_menu do |menu|
      menu.megaButton = 1
      menu.ultraButton = 1
      menu.megaButton = 2
      menu.ultraButton = 2
    end
    assert_equal [T.t(:bt_mega_ready), T.t(:bt_ultra_ready), T.t(:bt_mega_on), T.t(:bt_ultra_on)], SpeakCapture.lines
  end

  private

  # Yields a new display with the gen-6 battle hooks bound to it attached, the class set as FightMenuDisplay meanwhile.
  def with_fight_menu
    attached({ :FightMenuDisplay => Display }, BOUND) { yield Display.new }
  end

  # Runs the block with the stand-ins under their game names (top-level name => class) and the hook chains bound to
  # them at load attached, then takes both away, putting back whatever held those names and chains before.
  def attached(stand_ins, bound)
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    held = bound.keys.select { |k| chains.key?(k) }.map { |k| [k, chains[k]] }
    chains.update(bound)
    priors = stand_ins.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
    stand_ins.each { |n, k| Object.const_set(n, k) }
    yield
  ensure
    stand_ins.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    (priors || []).each { |n, k| Object.const_set(n, k) if k }
    bound.each_key { |k| chains.delete(k) }
    (held || []).each { |k, v| chains[k] = v }
  end

  class << self
    private

    # Evaluates the mod files at rels, read as the harness reads them, over the stand-ins set for the moment under
    # their game names (top-level name => class), and answers the hook chains bound to them, to attach per test; all
    # else the evaluation changed (the names, other chains, function bodies, overrides, the missing list, the battle
    # marks and singletons) is put back as it was.
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
      singletons = [:shown_sex, :shown_level].map { |n| [n, PokeAccess::Battle.method(n)] }
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
      singletons.each { |n, m| PokeAccess::Battle.define_singleton_method(n, m) }
    end
  end

  # The gen-6 battle hooks' chains on Display, bound once as this file loads: evaluating a file again starts its
  # coverage afresh, so binding before any test lets every test's reading count.
  BOUND = bind({ :FightMenuDisplay => Display }, ["core/battle/gen6/battle_g6.rb"])
end
