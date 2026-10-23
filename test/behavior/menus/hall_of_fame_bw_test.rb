# The Hall of Fame BW plugin's PC viewer (plugins/hall_of_fame_bw.rb): the focused member with the entry number the
# plugin paints (counted back from its newest, not the index), its place in the team and its panel, by verbosity.
class HallOfFameBwTest < PokeAccessTest
  # $PokemonGlobal as the plugin keeps it: the recorded teams and the number of the newest.
  HallGlobal = Struct.new(:hallOfFame, :hallOfFameLastNumber)

  # A recorded member, with what the viewer's panel paints of it.
  Member = Struct.new(:name, :speciesName, :level, :gender, :types, :owner, :obtain_text, :obtain_map)
  Owner = Struct.new(:name, :public_id)

  test "numbers an entry as the game does, counting back from its newest" do
    with_hall([[member("Chispa", "Pikachu")], [member("Bulbi", "Bulbasaur")]], 7) do
      assert_equal [6, 7], [0, 1].map { |i| PokeAccess::HallOfFameBW.entry_number(i) }
    end
  end

  test "numbers an entry by its place when the game keeps no counter" do
    with_hall([[member("Chispa", "Pikachu")], [member("Bulbi", "Bulbasaur")]], nil) do
      assert_equal [1, 2], [0, 1].map { |i| PokeAccess::HallOfFameBW.entry_number(i) }
    end
  end

  test "reads the focused member whole at full: entry, place, nickname, species and sign, level and the panel's rest" do
    t = PokeAccess::I18n
    rocky = member("Rocoso", "Onix", 51, :gender => 0, :types => [:ROCK, :GROUND, :ROCK],
                   :owner => Owner.new("Rojo", 123), :obtain_text => "Ruta 3")
    team = [member("Bulbi", "Bulbasaur"), rocky]
    with_hall([[member("Chispa", "Pikachu")], team], 7) do
      PokeAccess::HallOfFameBW.read(viewer(team, 1, 1))
    end
    whole = [t.t(:hofbw_entry, :n => 7), t.t(:list_pos, :i => 2, :n => 2), "Rocoso", "Onix ♂", t.t(:hofbw_level, :n => 51),
             t.t(:hofbw_types, :t => "TipoROCK/TipoGROUND"), t.t(:hofbw_ot, :name => "Rojo"), t.t(:hofbw_id, :n => "00123"),
             t.t(:hofbw_caught, :map => "Ruta 3")]
    assert_equal [[whole.join(", "), true]], SpeakCapture.log
  end

  test "says where a member was caught by its text, else its map's name, else an unknown place" do
    unknown = PokeAccess::I18n.t(:hofbw_unknown_place)
    names = { 0 => "Mapa de pruebas", 7 => "Ruta 7", 9 => "" }
    GameFunctions.with(:pbGetMapNameFromId => lambda { |id| names.fetch(id) }) do
      { ["Ruta 3", 7] => "Ruta 3", [nil, 7] => "Ruta 7", ["", 9] => unknown, [nil, 0] => unknown,
        [nil, nil] => unknown }.each do |(text, map), said|
        pk = member("Rocoso", "Onix", 51, :obtain_text => text, :obtain_map => map)
        assert_equal said, PokeAccess::HallOfFameBW.caught_in(pk), "obtain_text #{text.inspect}, obtain_map #{map.inspect}"
      end
    end
  end

  test "says the nickname and the species at brief, adds the place and the level from medium and the rest at full" do
    t = PokeAccess::I18n
    team = [member("Bulbi", "Bulbasaur"), member("Rocoso", "Onix", 51, :gender => 0)]
    scene = viewer(team, 0, 1)
    rows = with_hall([team], 3) do
      vb_levels do
        PokeAccess::Cursor.reset(scene, :hof)
        SpeakCapture.clear
        PokeAccess::HallOfFameBW.read(scene)
        SpeakCapture.last
      end
    end
    entry = t.t(:hofbw_entry, :n => 3)
    place = t.t(:list_pos, :i => 2, :n => 2)
    level = t.t(:hofbw_level, :n => 51)
    caught = t.t(:hofbw_caught, :map => t.t(:hofbw_unknown_place))
    assert_equal [[entry, "Rocoso", "Onix"].join(", "), [entry, place, "Rocoso", "Onix", level].join(", "),
                  [entry, place, "Rocoso", "Onix ♂", level, caught].join(", ")], rows
  end

  test "names the entry at brief only as the cursor reaches it" do
    team = [member("Bulbi", "Bulbasaur", 55), member("Rocoso", "Onix", 51)]
    scene = viewer(team, 1, 0)
    PokeAccess::Config.verbosity = :brief
    with_hall([[member("Chispa", "Pikachu")], team], 3) do
      PokeAccess::HallOfFameBW.read(scene)
      scene.instance_variable_set(:@pokemonIndex, 1)
      PokeAccess::HallOfFameBW.read(scene)
    end
    assert_equal [[PokeAccess::I18n.t(:hofbw_entry, :n => 3), "Bulbi", "Bulbasaur"].join(", "), "Rocoso, Onix"],
                 SpeakCapture.lines
  end

  test "keeps the whole card on the info key whatever the verbosity" do
    t = PokeAccess::I18n
    team = [member("Rocoso", "Onix", 51, :gender => 1)]
    PokeAccess::Config.verbosity = :brief
    with_hall([team], 1) { PokeAccess::HallOfFameBW.read(viewer(team, 0, 0)) }
    assert_equal [t.t(:hofbw_entry, :n => 1), "Rocoso", "Onix ♀", t.t(:hofbw_level, :n => 51),
                  t.t(:hofbw_caught, :map => t.t(:hofbw_unknown_place))].join(", "), PokeAccess::Info.info_text
  end

  test "names a member whose nickname is its species once" do
    team = [member("Onix", "Onix", 51)]
    PokeAccess::Config.verbosity = :medium
    with_hall([team], 1) { PokeAccess::HallOfFameBW.read(viewer(team, 0, 0)) }
    t = PokeAccess::I18n
    assert_equal [[t.t(:hofbw_entry, :n => 1), t.t(:list_pos, :i => 1, :n => 1), "Onix", t.t(:hofbw_level, :n => 51)].join(", ")],
                 SpeakCapture.lines
  end

  test "says nothing on a redraw of the same member" do
    team = [member("Bulbi", "Bulbasaur")]
    scene = viewer(team, 0, 0)
    with_hall([team], 1) do
      PokeAccess::HallOfFameBW.read(scene)
      SpeakCapture.clear
      PokeAccess::HallOfFameBW.read(scene)
    end
    assert_nothing_spoken
  end

  test "says nothing with no team recorded on the scene or the cursor past its team" do
    team = [member("Bulbi", "Bulbasaur")]
    with_hall([team], 1) do
      PokeAccess::HallOfFameBW.read(viewer(nil, 0, 0))
      PokeAccess::HallOfFameBW.read(viewer(team, 0, 1))
    end
    assert_nothing_spoken
  end

  private

  # A member named nick of the species, at level, with the panel's other fields given in more.
  def member(nick, species, level = 50, more = {})
    Member.new(nick, species, level, more[:gender], more[:types], more[:owner], more[:obtain_text], more[:obtain_map])
  end

  # The viewer's scene on the recorded team at hall_index, its cursor on member index.
  def viewer(team, hall_index, index)
    World.stub_scene(:@hallEntry => team, :@hallIndex => hall_index, :@pokemonIndex => index)
  end

  # The block's value with $PokemonGlobal keeping teams and the newest entry's number, put back afterwards.
  def with_hall(teams, last)
    saved = $PokemonGlobal
    $PokemonGlobal = HallGlobal.new(teams, last)
    yield
  ensure
    $PokemonGlobal = saved
  end
end
