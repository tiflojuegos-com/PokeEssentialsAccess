# Fancy Badges' ceremony (plugins/fancy_badges.rb): the badge's name, painted under the spinning badge, is said from
# the game's own table, the script copies' FANCY_BADGE_NAMES or the v20+ plugin's FancyBadges::NAMES. The game's
# function exists only inside each test, which evaluates the plugin over it and takes both away after.
class BadgeCeremonyTest < PokeAccessTest
  COPY_NAMES = ["Medalla Corriente", "Medalla Doma", "Medalla Ferro", "Medalla Presa", "Medalla Évoca"]
  PLUGIN_NAMES = ["Medalla Planta", "Medalla Agua"]

  test "says the badge's name from the script copies' table, queued behind what came before" do
    with_ceremony(COPY_NAMES, nil) { renderBadgeAnimation(4) }
    assert_equal [["Medalla Évoca", false]], SpeakCapture.log
  end

  test "says it from the v20+ plugin's table" do
    with_ceremony(nil, PLUGIN_NAMES) { renderBadgeAnimation(1) }
    assert_equal ["Medalla Agua"], SpeakCapture.lines
  end

  test "the script copies' table wins where both are defined" do
    with_ceremony(COPY_NAMES, PLUGIN_NAMES) { renderBadgeAnimation(1) }
    assert_equal ["Medalla Doma"], SpeakCapture.lines
  end

  test "a ceremony with no badge number is the first badge's" do
    with_ceremony(nil, PLUGIN_NAMES) { renderBadgeAnimation(nil) }
    assert_equal ["Medalla Planta"], SpeakCapture.lines
  end

  test "the ceremony still runs as the game's" do
    assert_equal 3, with_ceremony(COPY_NAMES, nil) { renderBadgeAnimation(3) }
  end

  test "says nothing for a badge past the table, or in a game with neither table" do
    { "past the table" => [PLUGIN_NAMES, 2], "no table" => [nil, 0],
      "a table that is no list" => ["Medalla", 0] }.each do |what, (names, n)|
      with_ceremony(nil, names) { renderBadgeAnimation(n) }
      assert_nothing_spoken what
    end
  end

  private

  # The block's value with renderBadgeAnimation defined as the game's (answering its badge number), the plugin evaluated
  # over it, and the tables given (nil for none) set; the function, its wrapper and the tables taken away after.
  def with_ceremony(copy_names, plugin_names)
    path = File.join(Harness::ROOT, "plugins", "fancy_badges.rb")
    PokeAccess::Hooks.fn_bodies.delete("renderBadgeAnimation|before")
    Object.send(:define_method, :renderBadgeAnimation) { |*a| a[0] }
    Object.send(:private, :renderBadgeAnimation)
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    Object.const_set(:FANCY_BADGE_NAMES, copy_names) if copy_names
    if plugin_names
      Object.const_set(:FancyBadges, Module.new)
      FancyBadges.const_set(:NAMES, plugin_names)
    end
    yield
  ensure
    Object.send(:remove_const, :FANCY_BADGE_NAMES) if Object.const_defined?(:FANCY_BADGE_NAMES)
    Object.send(:remove_const, :FancyBadges) if Object.const_defined?(:FancyBadges)
    [:renderBadgeAnimation, :renderBadgeAnimation__pa].each do |m|
      Object.send(:remove_method, m) if Object.private_method_defined?(m) || Object.method_defined?(m)
    end
    PokeAccess::Hooks.fn_bodies.delete("renderBadgeAnimation|before")
  end
end
