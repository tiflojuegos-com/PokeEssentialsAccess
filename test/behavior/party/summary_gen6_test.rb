# The gen-6 summary scene: the info key follows the Pokemon shown unless a detail cursor is up, opening reads the data
# sheet (a Shadow's ending on its heart), the memo is read as painted or composed, and the stats colour by nature.
class SummaryGen6Test < PokeAccessTest
  T = PokeAccess::I18n
  MALE = "\xE2\x99\x82"
  # The paragraph a Shadow Pokemon's page one paints about its heart.
  HEART = "La puerta de su corazón está cerrada."
  # A sprite as the detail cursors are asked: only whether it shows.
  Cursor = Struct.new(:visible)

  test "the info key follows the Pokemon shown as the summary cycles through the party" do
    bulba = Poke.build(:name => "Bulba", :species => 1)
    char = Poke.build(:name => "Char", :species => 4)
    scene = World.summary_scene(:pokemon => bulba)
    scene.pbUpdate
    assert_equal PokeAccess::Info.pokemon_info(bulba), PokeAccess::Info.info_text, "on the Pokemon entered"
    scene.pokemon = char
    scene.pbUpdate
    assert_equal PokeAccess::Info.pokemon_info(char), PokeAccess::Info.info_text, "on the one switched to"
  end

  test "while the move or ribbon cursor is up, the info key stays on that detail" do
    %w[movesel ribbonsel].each do |cursor|
      scene = World.summary_scene(:pokemon => Poke.build(:name => "Bulba"))
      scene.instance_variable_set(:@sprites, cursor => Cursor.new(true))
      PokeAccess::Info.set_info(:text, "Placaje")
      scene.pbUpdate
      assert_equal "Placaje", PokeAccess::Info.info_text, "with #{cursor} up"
    end
  end

  test "a detail cursor that is hidden leaves the info key to the Pokemon" do
    bulba = Poke.build(:name => "Bulba")
    scene = World.summary_scene(:pokemon => bulba)
    scene.instance_variable_set(:@sprites, "movesel" => Cursor.new(false))
    PokeAccess::Info.set_info(:text, "Placaje")
    scene.pbUpdate
    assert_equal PokeAccess::Info.pokemon_info(bulba), PokeAccess::Info.info_text
  end

  test "opening the summary reads the data sheet, queued" do
    PokemonSummaryScene.new.pbStartScene([Poke.build(:name => "Bulba", :species => 1)], 0)
    assert_equal [[sheet("Bulba"), false]], SpeakCapture.log
  end

  test "a Shadow Pokemon's data sheet ends on the heart paragraph its page one paints" do
    nox = Poke.build(:name => "Nox")
    def nox.shadowPokemon?; true; end
    open_painting_heart(nox)
    assert_equal [[sheet("Nox", HEART), false]], SpeakCapture.log
  end

  test "a Shadow Pokemon whose data sheet cannot be read says nothing, not its heart paragraph alone" do
    broken = Poke.build(:name => "Nox")
    def broken.shadowPokemon?; true; end
    def broken.species; raise "sin especie"; end
    open_painting_heart(broken)
    assert_nothing_spoken
  end

  test "the memo page is read as painted, a game's own ways of meeting a Pokemon included" do
    scene = PokemonSummaryScene.new(Poke.build(:name => "Nox"))
    paint = "<c3=484848,C8C8C8>Naturaleza<c3=EC0000,C8C8C8> Firme.\n<c3=EC0000,C8C8C8>Reino de las papeleras\n" \
            "<c3=484848,C8C8C8>Reclutado a nivel 20\ntras un intenso combate."
    scene.instance_variable_set(:@memo_paint, paint)
    scene.drawPageTwo
    assert_equal [["#{T.t(:sm_memo)}. Naturaleza Firme. Reino de las papeleras. Reclutado a nivel 20. tras un intenso combate.",
                   false]], SpeakCapture.log
  end

  test "with nothing painted, the memo page says the nature and the characteristic of the Pokemon" do
    PokemonSummaryScene.new(Poke.build(:name => "Nox")).drawPageTwo
    assert_equal [["#{T.t(:sm_memo)}. #{T.t(:sm_nature, :n => 'Naturaleza0')}. #{T.t(:sm_char_1)}.", false]],
                 SpeakCapture.log
  end

  test "the stats page colours the stats a gen-6 nature index raises and lowers" do
    { 0 => nil, 1 => [1, 2], 5 => [2, 1], 13 => [3, 4], 24 => nil }.each do |nature, stats|
      want = stats ? T.t(:sm_nature_effect, :up => "Estadistica#{stats[0]}", :down => "Estadistica#{stats[1]}") : nil
      got = PokeAccess::Summary.nature_effect_line(Poke.build(:nature => nature))
      want ? assert_equal(want, got, "nature #{nature}") : assert_nil(got, "nature #{nature}, which raises what it lowers")
    end
  end

  private

  # The gen-6 data sheet of a stub Pokemon named name, then the given sentences: level 25, species, nature and ability
  # from the gen-6 data, no item, the stub's six stats and the lines of a Pokemon with no original trainer.
  def sheet(name, *after)
    ([T.t(:sum_data_of, :name => "#{name} #{MALE}", :level => 25), T.t(:sum_species, :s => "Especie1"),
      T.t(:sum_nature, :n => "Naturaleza0"), T.t(:sum_ability, :a => "Habilidad1"), T.t(:sum_item, :i => T.t(:sum_none)),
      T.t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35),
      T.t(:sum_ot, :name => T.t(:sum_loaned)), T.t(:sum_id, :id => T.t(:pdx_unknown_short))] + after).join(" ")
  end

  # Opens the summary on pk, its page one also painting the heart paragraph as a formatted text.
  def open_painting_heart(pk)
    scene = PokemonSummaryScene.new
    heart = HEART
    scene.define_singleton_method(:drawPageOne) do |*args|
      drawFormattedTextEx(nil, 232, 78, 276, heart)
      super(*args)
    end
    scene.pbStartScene([pk], 0)
  end
end
