# The continue panel said as it paints itself, then the saved team; the save on offer as the multi-save titles write
# it; and Awakening's panel (games/awakening/load_panel.rb): its map off the route's row and its finished endings.

# Only Awakening's module is evaluated, not its profile block, whose overrides would reach every other test here.
unless defined?(PokeAccess::AwakeningLoad)
  awakening_path = File.join(Harness::ROOT, "games", "awakening", "load_panel.rb")
  eval(Harness.source(awakening_path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, awakening_path)
end

class LoadPanelPaintedTest < PokeAccessTest
  Awakening = PokeAccess::AwakeningLoad

  test "the continue panel is said as it paints itself, its title left out, then the saved team" do
    PokemonLoadScene.new.pbStartScene(["Continuar", "Nuevo juego"], true, trainer([Poke.build(:species => 1)]), 0, 5)
    assert_equal [[["Ruta 5", "Rojo", "Medallas: 3", party_line("Especie1")].join(". "), false]], SpeakCapture.log
  end

  test "an egg in the saved team is said as an egg" do
    egg = Poke.build(:species => 4)
    def egg.egg?; true; end
    PokemonLoadScene.new.pbStartScene(["Continuar"], true, trainer([Poke.build(:species => 1), egg]), 0, 5)
    assert_equal [["Ruta 5", "Rojo", "Medallas: 3", party_line("Especie1, #{PokeAccess::I18n.t(:pty_egg)}")].join(". ")],
                 SpeakCapture.lines
  end

  test "a save with no team yet is said without a team line" do
    PokemonLoadScene.new.pbStartScene(["Continuar"], true, trainer([]), 0, 5)
    assert_equal [["Ruta 5. Rojo. Medallas: 3", false]], SpeakCapture.log
  end

  test "the hooked panels keep the value their refresh returns" do
    { "the continue panel" => [true, [["Continuar", 32, 10], ["Medallas:", 32, 112], ["3", 206, 112], ["Rojo", 112, 64],
                                      ["Ruta 5", 386, 10]]],
      "another command's" => [false, [["Continuar", 32, 10]]] }.each do |what, (continues, painted)|
      assert_equal painted, PokemonLoadPanel.new("Continuar", continues, trainer([]), "Ruta 5").refresh, what
    end
  end

  test "with no save to continue the screen opens silent" do
    PokemonLoadScene.new.pbStartScene(["Nuevo juego"], false, trainer([]), 0, 5)
    assert_nothing_spoken
  end

  test "the save on offer is said queued, as the title writes it" do
    PokemonLoadScene.new.pbDrawCurrentSaveFile("Partida 2", true)
    assert_equal [["Partida 2 Auto Save", false]], SpeakCapture.log
  end

  test "an empty save name is not said" do
    PokemonLoadScene.new.pbDrawCurrentSaveFile("")
    assert_nothing_spoken
  end

  test "Awakening's map is read off the route's row, on a line after it" do
    assert_equal ["Rojo", "Capítulo 4", "Alineación Orden", "Pueblo Raíz"], Awakening.lines(panel)
  end

  test "without the profile the core joins Awakening's map into the route's row" do
    assert_equal "Alineación Orden Pueblo Raíz", PokeAccess::LoadPanel.lines_of(panel).last
  end

  test "an Awakening cell is the map from its place column on" do
    { 299 => ["Alineación Orden Pueblo Raíz"], 300 => ["Alineación Orden", "Pueblo Raíz"] }.each do |x, want|
      pairs = [["Alineación", :positions, 32, 176], ["Orden", :positions, 192, 176], ["Pueblo Raíz", :positions, x, 176]]
      assert_equal want, Awakening.lines(pairs), "the map's cell at x #{x}"
    end
  end

  test "an empty Awakening map cell is left out" do
    pairs = [["Alineación", :positions, 32, 176], ["", :positions, 376, 176]]
    assert_equal ["Alineación"], Awakening.lines(pairs)
  end

  test "Awakening's finished endings are said in the icons' order, the true one last" do
    t = PokeAccess::I18n
    assert_equal t.t(:awk_endings, :list => [t.t(:awk_end_order), t.t(:awk_end_neutral), t.t(:awk_end_true)].join(", ")),
                 Awakening.endings(lambda { |n| n != 1 }, lambda { |_p| true })
  end

  test "with no Awakening ending finished nothing is said" do
    assert_nil Awakening.endings(lambda { |_n| false }, lambda { |_p| false })
  end

  test "each Awakening ending is the one its New Game Plus check numbers" do
    t = PokeAccess::I18n
    { 1 => :awk_end_chaos, 2 => :awk_end_order, 3 => :awk_end_neutral }.each do |number, key|
      assert_equal t.t(:awk_endings, :list => t.t(key)), Awakening.endings(lambda { |n| n == number }, lambda { |_p| false }),
                   "check #{number}"
    end
  end

  test "Awakening's endings come from the game's own check and the true ending's file" do
    Object.send(:define_method, :checkNewGamePlus) { |n| n == 2 }
    Object.send(:private, :checkNewGamePlus)
    t = PokeAccess::I18n
    got = in_game_folder(true) { Awakening.endings }
    assert_equal t.t(:awk_endings, :list => [t.t(:awk_end_order), t.t(:awk_end_true)].join(", ")), got
  ensure
    Object.send(:remove_method, :checkNewGamePlus)
  end

  test "without the game's check or the true ending's file no Awakening ending is taken as finished" do
    assert_nil in_game_folder(false) { Awakening.endings }
  end

  private

  # The saved trainer: Rojo, with three badges and party as the team.
  def trainer(party)
    tr = Struct.new(:name, :numbadges).new("Rojo", 3)
    tr.define_singleton_method(:party) { party }
    tr
  end

  # The saved team line over the species list it names.
  def party_line(list)
    PokeAccess::I18n.t(:load_party, :list => list)
  end

  # The block's value run from a throwaway game folder, holding Data/realfin.dat (the true ending's mark) when
  # true_ending is true.
  def in_game_folder(true_ending)
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, "Data"))
      File.write(File.join(dir, "Data", "realfin.dat"), "") if true_ending
      Dir.chdir(dir) { yield }
    end
  end

  # Awakening's continue panel as painted: the trainer, the chapter, the alignment row and the map at its far end.
  def panel
    [["Rojo", :positions, 112, 64], ["Capítulo", :positions, 32, 112], ["4", :positions, 192, 112],
     ["Alineación", :positions, 32, 176], ["Orden", :positions, 192, 176], ["Pueblo Raíz", :positions, 376, 176]]
  end
end
