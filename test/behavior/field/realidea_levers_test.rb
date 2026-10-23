# Realidea's levers (games/realidea/levers.rb): those of the Palancas2 sheet by the colour of their row, and
# "actualizar", the name its mappers leave on doors, chests and levers, as no name at all.
levers = File.join(Harness::ROOT, "games", "realidea", "levers.rb")
eval(Harness.source(levers), TOPLEVEL_BINDING, levers)

class RealideaLeversTest < PokeAccessTest
  Locator = PokeAccess::Locator

  # Leaves the locator's toggles as an empty map builds them, so none placed here outlives the test.
  def teardown
    World.clear_events
    Locator.refresh_lever_cache
    super
  end

  test "a lever of the Palancas2 sheet says the colour of its row, and whether it is pulled" do
    rows = [2, 4, 6, 8].each_with_index.map { |row, i| lever(i + 1, "Palancas2", row) }
    pulled = lever(5, "Palancas2", 8, :active => 1)
    Locator.refresh_lever_cache
    off = t(:loc_lever_off)
    assert_equal ["#{t(:rea_lever_green)}, #{off}", "#{t(:rea_lever_yellow)}, #{off}", "#{t(:rea_lever_red)}, #{off}",
                  "#{t(:rea_lever_lilac)}, #{off}", "#{t(:rea_lever_lilac)}, #{t(:loc_lever_on)}"],
                 (rows + [pulled]).map { |ev| Locator.target_name(ev) }
  end

  test "actualizar names no lever, no chest and no other event" do
    stick = lever(1, "palancas", 2, :name => "actualizar")
    chest = lever(2, "Cofre", 2, :name => "actualizar", :first => [TestCmd.new(355, ["Kernel.pbReceiveItem(:REVIVE)"])])
    cage = TestGameEvent.new(:id => 3, :name => "actualizar", :pages => [TestPage.new(:sprite => "jaula")])
    $game_map.events[3] = cage
    Locator.refresh_lever_cache
    assert_equal ["#{t(:loc_lever)}, #{t(:loc_lever_off)}", "#{t(:loc_chest)}, #{t(:loc_container_closed)}", "jaula"],
                 [stick, chest, cage].map { |ev| Locator.target_name(ev) }
  end

  private

  # A spoken text by its key.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A two-pose event on the map drawn from sheet in the row of facing row, page 1 (running :first, switch 171 on by
  # default) in pattern 1 and page 2, behind switch 171, in pattern 2; :active picks the live page.
  def lever(id, sheet, row, opts = {})
    first = opts.fetch(:first, [TestCmd.new(121, [171, 171, 0])])
    pages = [TestPage.new(:sprite => sheet, :pattern => 1, :direction => row, :list => first),
             TestPage.new(:sprite => sheet, :pattern => 2, :direction => row,
                          :condition => { :switch1_valid => true, :switch1_id => 171 })]
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => id, :y => 4, :name => opts.fetch(:name, "EV00#{id}"),
                                             :pages => pages, :active_page => pages[opts.fetch(:active, 0)])
  end
end
