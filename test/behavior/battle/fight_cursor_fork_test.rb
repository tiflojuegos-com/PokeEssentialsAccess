# The move-list cursor method differs by gen-6 fork: the stock FightMenuDisplay has setIndex; both Infinite Fusion
# games inherit index= from a BattleMenuBase parent, with no setIndex, and open the menu with setIndexAndMode. The
# gen-6 battle hooks bind the method the display has; they are evaluated again here over each shape, as this file
# loads.
class FightCursorForkTest < PokeAccessTest
  T = PokeAccess::I18n

  # The stock gen-6 FightMenuDisplay as far as the hooks go: setIndex and index=, and the battler.
  Stock = Class.new do
    def initialize; @index = 0; @battler = nil; end
    def setIndex(v); @index = v; end
    def index=(v); @index = v; end
    def battler=(b); @battler = b; end
  end

  # Infinite Fusion's BattleMenuBase: index=, mode= and setIndexAndMode, which opens the menu without either setter.
  MenuBase = Class.new do
    def initialize; @index = 0; @mode = 0; @battler = nil; end
    def index=(v); @index = v; end
    def mode=(v); @mode = v; end
    def setIndexAndMode(index, mode); @index = index; @mode = mode; end
  end

  # Infinite Fusion's FightMenuDisplay, all from its base but the battler: no setIndex.
  Fork = Class.new(MenuBase) { def battler=(b); @battler = b; end }

  test "reads the stock display's move on setIndex, and leaves its index= alone" do
    with_display(Stock, STOCK_BOUND) do |menu|
      menu.battler = fighter
      menu.setIndex(1)
      menu.index = 0
    end
    assert_equal [[growl_line, true]], SpeakCapture.log
  end

  test "reads the Infinite Fusion display's move on the index= its base class gives it" do
    with_display(Fork, FORK_BOUND) do |menu|
      menu.battler = fighter
      menu.index = 1
    end
    assert_equal [[growl_line, true]], SpeakCapture.log
  end

  test "leaves the fork's other menus on the same base class unhooked" do
    with_display(Fork, FORK_BOUND) do |menu|
      sibling = Class.new(MenuBase).new
      sibling.instance_variable_set(:@battler, fighter)
      sibling.index = 1
    end
    assert_nothing_spoken
  end

  test "reads the fork's opening move queued, then says the Mega button ready" do
    with_display(Fork, FORK_BOUND) do |menu|
      menu.battler = fighter
      menu.setIndexAndMode(0, 1)
    end
    assert_equal [[ember_line, false], [T.t(:bt_mega_ready), false]], SpeakCapture.log
  end

  test "reads only the fork's opening move when its button is hidden" do
    with_display(Fork, FORK_BOUND) do |menu|
      menu.battler = fighter
      menu.setIndexAndMode(0, 0)
    end
    assert_equal [[ember_line, false]], SpeakCapture.log
  end

  test "primes the fork's button from the opening, so the first press is said" do
    with_display(Fork, FORK_BOUND) do |menu|
      menu.battler = fighter
      menu.setIndexAndMode(0, 1)
      SpeakCapture.clear
      menu.mode = 2
    end
    assert_equal [[T.t(:bt_mega_on), true]], SpeakCapture.log
  end

  test "the displays hold the game's class name only while the hooks bind, not while a test runs" do
    held = [[Stock, STOCK_BOUND], [Fork, FORK_BOUND]].map do |klass, bound|
      with_display(klass, bound) { |_menu| Object.const_defined?(:FightMenuDisplay) ? Object.const_get(:FightMenuDisplay) : nil }
    end
    refute_includes held, Stock
    refute_includes held, Fork
  end

  private

  # A battler with Ember (move 1, 15 of 15 pp) and Growl (move 2, 30 of 40 pp).
  def fighter
    move = Struct.new(:name, :id, :pp, :totalpp)
    Struct.new(:moves).new([move.new("Ember", 1, 15, 15), move.new("Growl", 2, 30, 40)])
  end

  # The fight menu's line for Ember: name, category (from the move data) and pp.
  def ember_line
    ["Ember", T.t(:cat_special), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". ")
  end

  # The fight menu's line for Growl: name, category (from the move data) and pp.
  def growl_line
    ["Growl", T.t(:cat_status), T.t(:mv_pp, :pp => 30, :tot => 40)].join(". ")
  end

  # Yields a new display of klass with the gen-6 battle hooks bound to it attached.
  def with_display(klass, bound)
    attached(bound) { yield klass.new }
  end

  # Runs the block with the hook chains bound to the stand-ins at load attached, then takes them away, putting back
  # whatever chains held those keys before. The stand-ins hold the game's names only while bind evaluates the hooks.
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

  # The gen-6 battle hooks' chains on each display, bound once as this file loads: evaluating a file again starts its
  # coverage afresh, so binding before any test lets every test's reading count.
  STOCK_BOUND = bind({ :FightMenuDisplay => Stock }, ["core/battle/gen6/battle_g6.rb"])
  FORK_BOUND = bind({ :FightMenuDisplay => Fork }, ["core/battle/gen6/battle_g6.rb"])
end
