# The continue screen's save as the mod words it when its panel paints nothing to read: the map id is always
# pbStartScene's last argument and the play time whichever middle one carries it, in the four shapes games pass:
#   (commands, showContinue, trainer, framecount, mapid)              seven gen-6 games
#   (commands, show_continue, trainer, stats, map_id)                 anil, emerald, relict, royal
#   (commands, show_continue, trainer, frame_count, map_id)           Fire Ash, both Infinite Fusions
#   (commands, show_continue, trainer, frame_count, stats, map_id)    Soulstones 2

class LoadPanelTest < PokeAccessTest
  T = PokeAccess::I18n
  # An hour and a half of play as gen-6 counts it, in frames at its 40 a second.
  FRAMES = (3600 + 30 * 60) * 40

  test "takes the map id from the last argument in every shape" do
    shapes.each do |what, (args, _seconds)|
      assert_equal 35, PokeAccess::LoadPanel.map_id(args), what
    end
  end

  test "takes the play time from whichever middle argument carries it" do
    shapes.each do |what, (args, seconds)|
      assert_equal seconds, PokeAccess::LoadPanel.seconds(args), what
    end
  end

  test "has no play time when no middle argument carries one, the map id never taken for frames" do
    assert_nil PokeAccess::LoadPanel.seconds(["cmds", true, trainer, nil, 77])
  end

  test "has no summary without a save to continue or a trainer" do
    { "nothing to continue" => ["cmds", false, trainer, FRAMES, 35],
      "no trainer"          => ["cmds", true, nil, FRAMES, 35] }.each do |what, args|
      assert_nil PokeAccess::LoadPanel.summary(args), what
    end
  end

  test "words the save from its own data: name, badges, Pokedex, play time and map, then the team" do
    saved = trainer(:badge_count => 3, :seen => 12, :party => [Poke.build(:species => 25)])
    words = [T.t(:load_save, :name => "Ash"), T.t(:tr_badges, :n => 3), T.t(:load_dex, :n => 12),
             T.t(:load_play, :h => 1, :m => 30), T.t(:load_at, :map => "Mapa 35")].join(", ")
    assert_equal "#{words}. #{T.t(:load_party, :list => 'Especie25')}",
                 PokeAccess::LoadPanel.summary(["cmds", true, saved, FRAMES, 35])
  end

  test "reads the badges from gen-6's numbadges as from badge_count" do
    [:numbadges, :badge_count].each do |field|
      line = PokeAccess::LoadPanel.summary(["cmds", true, trainer(field => 5), nil, 77])
      assert_equal "#{T.t(:load_save, :name => 'Ash')}, #{T.t(:tr_badges, :n => 5)}", line, field.to_s
    end
  end

  test "leaves out what the save does not hold, and a map the game has no name for or a blank one" do
    with_map_named(40, "") do
      { 77 => "no name", 40 => "a blank name" }.each do |map, what|
        line = PokeAccess::LoadPanel.summary(["cmds", true, trainer, nil, map])
        assert_equal T.t(:load_save, :name => "Ash"), line, what
      end
    end
  end

  test "the team line says which members are shiny where the screen's icons show it, and only there" do
    party = [Poke.build(:species => 25, :shiny => true), Poke.build(:species => 4)]
    assert_equal T.t(:load_party, :list => "Especie25 #{T.t(:pk_shiny)}, Especie4"),
                 PokeAccess::LoadPanel.team_line(party, true), "icons in their colours"
    assert_equal T.t(:load_party, :list => "Especie25, Especie4"), PokeAccess::LoadPanel.team_line(party), "elsewhere"
  end

  test "the summary stays on the info key and Ctrl+T while the cursor is on Continue, and leaves with it" do
    saved = trainer(:numbadges => 2)
    scene = PokemonLoadScene.new
    scene.pbStartScene(["Continuar", "Nueva partida"], true, saved, FRAMES, 35)
    summary = PokeAccess::LoadPanel.summary(["cmds", true, saved, FRAMES, 35], scene)
    win = Window_DrawableCommand.new(["Continuar", "Nueva partida"])
    scene.instance_variable_get(:@sprites)["cmdwindow"] = win
    [[0, summary], [1, nil], [0, summary]].each do |index, want|
      win.index = index
      scene.pbUpdate
      assert_equal [want, want], [PokeAccess::Info.info_text, PokeAccess::Info.row_text], "the cursor on row #{index}"
    end
  end

  test "says each command row as the screen's own frame moves the cursor, the summary still on the info key" do
    saved = trainer(:numbadges => 2)
    scene = PokemonLoadScene.new
    scene.pbStartScene(["Continuar", "Nueva partida"], true, saved, FRAMES, 35)
    summary = PokeAccess::LoadPanel.summary(["cmds", true, saved, FRAMES, 35], scene)
    win = Window_DrawableCommand.new(["Continuar", "Nueva partida"])
    scene.instance_variable_get(:@sprites)["cmdwindow"] = win
    SpeakCapture.clear
    win.index = 0
    scene.pbUpdate
    on_continue = PokeAccess::Info.info_text
    win.index = 1
    scene.pbUpdate
    assert_equal [[["Continuar", false], ["Nueva partida", true]], summary],
                 [SpeakCapture.log, on_continue]
  end

  test "the screen started again on another save, as Multi Save's arrows do, puts that save's summary on the info key" do
    scene = PokemonLoadScene.new
    win = Window_DrawableCommand.new(["Continuar", "Nueva partida"])
    summaries = [trainer(:numbadges => 2), trainer(:numbadges => 5)].map do |saved|
      scene.pbStartScene(["Continuar", "Nueva partida"], true, saved, FRAMES, 35)
      scene.instance_variable_get(:@sprites)["cmdwindow"] = win
      scene.pbUpdate
      summary = PokeAccess::LoadPanel.summary(["cmds", true, saved, FRAMES, 35], scene)
      assert_equal summary, PokeAccess::Info.info_text, "the save on show"
      summary
    end
    refute_equal summaries[0], summaries[1]
  end

  private

  # Runs the block with the game's map table naming map id as name, the table the locator kept put back afterwards.
  def with_map_named(id, name)
    loc = PokeAccess::Locator
    saved = loc.instance_variable_get(:@mapinfos)
    loc.instance_variable_set(:@mapinfos, (saved || loc.load_mapinfos).merge(id => TestMapInfo.new(id, name)))
    yield
  ensure
    loc.instance_variable_set(:@mapinfos, saved)
  end

  # The shapes by name (gen-6's and Fire Ash's are one): pbStartScene's arguments, on map 35, and the play time in
  # seconds they carry.
  def shapes
    stats = Object.new
    def stats.play_time; 7200; end
    {
      "gen-6 and Fire Ash, a frame count" => [["cmds", true, trainer, FRAMES, 35], 5400],
      "modern, a stats object"            => [["cmds", true, trainer, stats, 35], 7200],
      "Soulstones 2, frames then stats"   => [["cmds", true, trainer, FRAMES, stats, 35], 5400]
    }
  end

  # The saved trainer Ash, holding only the fields given: :numbadges or :badge_count, :seen (the Pokedex's seen
  # count) and :party.
  def trainer(fields = {})
    tr = Object.new
    def tr.name; "Ash"; end
    fields.each do |field, value|
      case field
      when :seen
        dex = Object.new
        dex.define_singleton_method(:seen_count) { value }
        tr.define_singleton_method(:pokedex) { dex }
      else
        tr.define_singleton_method(field) { value }
      end
    end
    tr
  end
end
