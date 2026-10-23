# Reborn's own screens and what rv_common reads of its engine: the map names its $cache keeps, the Inspect report the
# info key says whole, and the Move Tutor app of the Pokegear.
Harness.load_common("rv_common")

# Reborn's Move Tutor app: the tutor moves behind a hidden list (the cursor's row, and whether the list has the cursor),
# whose pbUpdate drives the page.
class MoveTutorScene
  List = Struct.new(:index, :active)

  def initialize(moves)
    @moves = moves
    @sprites = { "commands" => List.new(0, true) }
  end

  def pbUpdate; nil; end
end

# The bag class the game asks what each party member can do with a move; each test gives its own answer.
class PokemonBag; end

# Reborn's Move Tutor profile evaluated once over the scene above, as boot does (a second evaluation would hook it
# again); the profiles it declares are put back.
begin
  profiles = PokeAccess::Game.profiles.dup
  tutor = File.join(Harness::ROOT, "games", "reborn", "move_tutor.rb")
  eval(Harness.source(tutor), TOPLEVEL_BINDING, tutor)
ensure
  PokeAccess::Game.profiles.replace(profiles)
end

class RebornScreensTest < PokeAccessTest
  Cache = Struct.new(:pkmn, :moves, :abil, :mapinfos)
  CacheWithoutMaps = Struct.new(:pkmn, :moves, :abil)
  OtherCache = Struct.new(:mapinfos)
  MapInfo = Struct.new(:name)
  MoveData = Struct.new(:move, :type, :maxpp)
  Member = Struct.new(:name)
  Trainer = Struct.new(:party)
  MessageWindow = Struct.new(:text)
  MOVES = { :SURF => MoveData.new(:SURF, :WATER, 15), :CUT => MoveData.new(:CUT, :NORMAL, 30),
            :SKETCH => MoveData.new(:SKETCH, :NORMAL, 1), :STRUGGLE => MoveData.new(:STRUGGLE, :NORMAL, 0) }
  TYPES = { :WATER => "Water", :NORMAL => "Normal" }
  PARTY = ["Lapras", "Vaporeon", "Pidgey"]

  test "the engine's map infos are those its $cache keeps" do
    infos = { 5 => MapInfo.new("Opal Ward") }
    with_cache(Cache.new({}, {}, {}, infos)) do
      assert_same infos, PokeAccess::DataRV.map_infos
    end
  end

  test "an engine whose $cache keeps no map infos, or no engine of its kind, gives none" do
    other = OtherCache.new({ 5 => MapInfo.new("Opal Ward") })
    { "a $cache without map infos" => CacheWithoutMaps.new({}, {}, {}), "no $cache" => nil,
      "another engine's $cache with map infos" => other }.each do |what, cache|
      with_cache(cache) { assert_nil PokeAccess::DataRV.map_infos, "with #{what}" }
    end
  end

  test "the locator names a map by the engine's map infos" do
    locator = PokeAccess::Locator
    kept = locator.instance_variable_get(:@mapinfos)
    locator.instance_variable_set(:@mapinfos, nil)
    with_cache(Cache.new({}, {}, {}, { 5 => MapInfo.new("Opal Ward") })) do
      Harness.with_provider(PokeAccess::DataRV) { assert_equal "Opal Ward", locator.map_name(5) }
    end
  ensure
    locator.instance_variable_set(:@mapinfos, kept)
  end

  test "the Inspect report reads whole, its message first and each line without its padding" do
    rows = ["Type: Water", "Attack:               55  ", nil, "Crit. Rate:    4.2%    +0/3", "Revealed Moves:",
            "Surf:  15 PP left"]
    assert_equal "Inspecting Lapras: Type: Water. Attack: 55. Crit. Rate: 4.2% +0/3. Revealed Moves: Surf: 15 PP left",
                 PokeAccess::InspectRV.report_text(MessageWindow.new("Inspecting Lapras:"), rows)
  end

  test "the Move Tutor says the focused move's type, PP and who can learn or knows it, queued behind its name" do
    with_tutor([:SURF, :CUT], :SURF => [1, 2, 0]) do |scene|
      scene.pbUpdate
      line = [t(:mv_type, :t => "Water"), t(:mv_pp, :pp => 15, :tot => 15), t(:tut_can_list, :names => "Lapras"),
              t(:tut_knows_list, :names => "Vaporeon")].join(". ")
      assert_equal [[line, false]], SpeakCapture.log
    end
  end

  test "the Move Tutor says each move once while the cursor stays on it" do
    with_tutor([:SURF, :CUT], :SURF => [1, 2, 0]) do |scene|
      scene.pbUpdate
      SpeakCapture.clear
      scene.pbUpdate
      assert_nothing_spoken
    end
  end

  test "the Move Tutor says so when nobody in the party can learn the move" do
    with_tutor([:SURF, :CUT], :CUT => [0, 0, 0]) do |scene|
      list(scene).index = 1
      scene.pbUpdate
      line = [t(:mv_type, :t => "Normal"), t(:mv_pp, :pp => 30, :tot => 30), t(:tut_nobody)].join(". ")
      assert_equal [[line, false]], SpeakCapture.log
    end
  end

  test "the Move Tutor says only who knows a move the rest of the party cannot learn" do
    with_tutor([:SURF], :SURF => [2, 0, 0]) do |scene|
      scene.pbUpdate
      line = [t(:mv_type, :t => "Water"), t(:mv_pp, :pp => 15, :tot => 15), t(:tut_knows_list, :names => "Lapras")]
      assert_equal [[line.join(". "), false]], SpeakCapture.log
    end
  end

  test "the Move Tutor says the PP of a move that has some and leaves it out for one with none" do
    { :SKETCH => [t(:mv_type, :t => "Normal"), t(:mv_pp, :pp => 1, :tot => 1), t(:tut_nobody)],
      :STRUGGLE => [t(:mv_type, :t => "Normal"), t(:tut_nobody)] }.each do |move, parts|
      with_tutor([move], move => [0, 0, 0]) do |scene|
        scene.pbUpdate
        assert_equal [[parts.join(". "), false]], SpeakCapture.log, "for #{move}"
      end
      SpeakCapture.clear
    end
  end

  test "the Move Tutor says nothing while its list does not have the cursor" do
    with_tutor([:SURF], :SURF => [1, 2, 0]) do |scene|
      list(scene).active = false
      scene.pbUpdate
      assert_nothing_spoken
    end
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Runs the block with the engine's $cache set to cache, put back after.
  def with_cache(cache)
    had = $cache
    $cache = cache
    yield
  ensure
    $cache = had
  end

  # Runs the block on a Move Tutor app listing moves, with the engine's data provider naming types through the game's
  # getTypeName, the party above and the game's pbPartyCanLearnThisMove? answering marks for each move (1 can learn it,
  # 2 knows it, 0 cannot); $cache, $Trainer and the game's answer are put back after.
  def with_tutor(moves, marks)
    had_trainer = $Trainer
    $Trainer = Trainer.new(PARTY.map { |n| Member.new(n) })
    with_party_marks(marks) do
      with_cache(Cache.new({}, MOVES, {}, {})) do
        Harness.with_provider(PokeAccess::DataRV) do
          GameFunctions.with(:getTypeName => lambda { |ty| TYPES[ty].to_s }) { yield MoveTutorScene.new(moves) }
        end
      end
    end
  ensure
    $Trainer = had_trainer
  end

  # Runs the block with PokemonBag.pbPartyCanLearnThisMove? answering marks, a party unable for a move left out; the
  # answer there was before is put back, or none.
  def with_party_marks(marks)
    meta = PokemonBag.singleton_class
    had = meta.method_defined?(:pbPartyCanLearnThisMove?) ? PokemonBag.method(:pbPartyCanLearnThisMove?) : nil
    PokemonBag.define_singleton_method(:pbPartyCanLearnThisMove?) { |move| marks.fetch(move, [0, 0, 0]) }
    yield
  ensure
    had ? PokemonBag.define_singleton_method(:pbPartyCanLearnThisMove?, had) : meta.send(:remove_method, :pbPartyCanLearnThisMove?)
  end

  # The app's move list.
  def list(scene)
    scene.instance_variable_get(:@sprites)["commands"]
  end
end
