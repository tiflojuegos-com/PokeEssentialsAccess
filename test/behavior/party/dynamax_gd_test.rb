# The Dynamax plugins (ZUD, the Deluxe Battle Kit's), asked in either spelling: the G-Max Factor mark in the summary
# header and the PC panel, and the Dynamax meter on the stats page, which the kit's NO_DYNAMAX switch hides.
class DynamaxGdTest < PokeAccessTest
  T = PokeAccess::I18n
  SWITCH = 498

  test "marks the G-Max Factor in the summary header, asked in either plugin's spelling" do
    { :gmaxFactor? => "ZUD", :gmax_factor? => "the kit" }.each do |meth, who|
      assert_equal T.t(:dmax_factor), PokeAccess::Summary.header_icons(answering(meth => true)), who
    end
  end

  test "puts the mark after the header's other icons" do
    pk = answering(:gmaxFactor? => true)
    pk.shiny = true
    assert_equal "#{T.t(:pk_shiny)}, #{T.t(:dmax_factor)}", PokeAccess::Summary.header_icons(pk)
  end

  test "draws no mark for a Pokemon without the factor" do
    [answering(:gmax_factor? => false), answering(:gmaxFactor? => false), answering({})].each_with_index do |pk, i|
      assert_equal "", PokeAccess::Summary.header_icons(pk), "case #{i}"
    end
  end

  test "says the Dynamax meter after the stats, asked in either plugin's spelling" do
    zud = answering(:dynamaxAble? => true, :dynamax_lvl => 7)
    kit = answering(:dynamax_able? => true, :dynamax_lvl => 3)
    assert_equal stats_page(T.t(:dmax_level, :n => 7)), PokeAccess::SummaryGameData.stats_text(zud), "ZUD"
    assert_equal stats_page(T.t(:dmax_level, :n => 3)), PokeAccess::SummaryGameData.stats_text(kit), "the kit"
  end

  test "draws no meter for a Pokemon that cannot Dynamax" do
    [answering(:dynamaxAble? => false, :dynamax_lvl => 7), answering(:dynamax_able? => false, :dynamax_lvl => 3),
     answering({})].each_with_index do |pk, i|
      assert_equal stats_page, PokeAccess::SummaryGameData.stats_text(pk), "case #{i}"
    end
  end

  test "says level 0 for a Pokemon that can Dynamax but gives no level" do
    assert_equal stats_page(T.t(:dmax_level, :n => 0)), PokeAccess::SummaryGameData.stats_text(answering(:dynamaxAble? => true))
  end

  test "hides the kit's meter while its switch against Dynamax is on, but not ZUD's" do
    with_no_dynamax(true) do
      assert_equal stats_page, PokeAccess::SummaryGameData.stats_text(answering(:dynamax_able? => true, :dynamax_lvl => 3)),
                   "the kit"
      assert_equal stats_page(T.t(:dmax_level, :n => 7)),
                   PokeAccess::SummaryGameData.stats_text(answering(:dynamaxAble? => true, :dynamax_lvl => 7)),
                   "ZUD draws its meter without asking"
    end
  end

  test "shows the kit's meter while its switch is off" do
    with_no_dynamax(false) do
      assert_equal stats_page(T.t(:dmax_level, :n => 3)),
                   PokeAccess::SummaryGameData.stats_text(answering(:dynamax_able? => true, :dynamax_lvl => 3))
    end
  end

  test "counts the kit's switch as off when there are no game switches to ask" do
    was = $game_switches
    with_no_dynamax(true) do
      $game_switches = nil
      assert_equal stats_page(T.t(:dmax_level, :n => 3)),
                   PokeAccess::SummaryGameData.stats_text(answering(:dynamax_able? => true, :dynamax_lvl => 3))
    end
  ensure
    $game_switches = was
  end

  test "marks the factor last in the PC panel where STORAGE_GMAX_FACTOR is set" do
    with_setting(:STORAGE_GMAX_FACTOR, true) do
      assert_equal pc_panel + [T.t(:dmax_factor)], PokeAccess::Party.pc_details(answering(:gmax_factor? => true))
    end
  end

  test "leaves the PC panel alone for a Pokemon without the factor, or where the setting is off or absent" do
    factor = answering(:gmax_factor? => true)
    with_setting(:STORAGE_GMAX_FACTOR, true) do
      assert_equal pc_panel, PokeAccess::Party.pc_details(answering(:gmax_factor? => false)), "no factor"
    end
    with_setting(:STORAGE_GMAX_FACTOR, false) { assert_equal pc_panel, PokeAccess::Party.pc_details(factor), "setting off" }
    assert_equal pc_panel, PokeAccess::Party.pc_details(factor), "setting absent"
  end

  private

  # Chispa answering each of methods with its value.
  def answering(methods)
    pk = Poke.build(:name => "Chispa")
    methods.each { |m, v| pk.define_singleton_method(m) { v } }
    pk
  end

  # The stats page of such a Pokemon, its stats and ability at Poke.build's defaults (the engine names ability 1
  # "Ability1"), with the given sentences between them.
  def stats_page(*extras)
    stats = T.t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35)
    (["#{T.t(:sm_stats)}. #{stats}"] + extras + [T.t(:sum_ability, :a => "Ability1")]).join(" ")
  end

  # The PC panel the core draws for such a Pokemon: its ability, then no item.
  def pc_panel
    [[T.t(:pc_ability, :a => "Ability1"), :full], [T.t(:pc_no_item), :medium]]
  end

  # Runs the block with the game's Settings::<name> set to value, then puts back what was there, or nothing.
  def with_setting(name, value)
    had = ::Settings.const_defined?(name, false) ? [::Settings.const_get(name)] : nil
    ::Settings.send(:remove_const, name) if had
    ::Settings.const_set(name, value)
    yield
  ensure
    ::Settings.send(:remove_const, name) if ::Settings.const_defined?(name, false)
    ::Settings.const_set(name, had[0]) if had
  end

  # Runs the block with the kit's NO_DYNAMAX naming SWITCH, and that switch on or off.
  def with_no_dynamax(on)
    with_setting(:NO_DYNAMAX, SWITCH) do
      $game_switches[SWITCH] = on
      yield
    end
  end
end
