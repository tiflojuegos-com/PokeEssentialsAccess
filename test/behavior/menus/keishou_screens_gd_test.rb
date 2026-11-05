# Keishou's other screens, on stand-ins shaped as its scripts: the Charm Case's rows (plugins/charm_case.rb), the Punch Bag
# (plugins/punch_bag_v12.rb), the tournament record (games/keishou/aki_record.rb), its Rock Climb
# (games/keishou/rock_climb.rb) and the summary's Tera Type (plugins/terastal_phenomenon.rb).
class AkiEventScene
  attr_accessor :team

  def pbUpdate; nil; end
  def pbEndScene; nil; end

  # Paints as the game does: each member with those before it, then the record rows, then runs a frame of its loop.
  def pbAkiRecordScreen(team)
    names = []
    team.each do |pk|
      names.push([pk.name, 40, 13, 0])
      pbDrawTextPositions(nil, names)
    end
    pbDrawTextPositions(nil, [["Tournament Record", 256, 70, 2], ["Endless - Hard Mode", 256, 117, 2],
                              ["Armorite Ore earned: 12", 256, 268, 2], ["Trainers beaten: 7", 256, 297, 2]])
    pbUpdate
    pbUpdate
    :closed
  end
end

aki = File.join(Harness::ROOT, "games", "keishou", "aki_record.rb")
eval(Harness.source(aki), TOPLEVEL_BINDING, aki)

# The Charm Case's scene, down to what the reader hooks and looks at: its list and the count in its corner.
class CharmCase_Scene
  attr_reader :sprites

  def initialize(win, count)
    @sprites = { "itemwindow" => win, "CharmCount" => Struct.new(:text, :visible).new(count, true) }
  end

  def pbStartCharmScene(_stock = nil, _adapter = nil); nil; end
  def pbEndCharmScene; nil; end
  def pbRefresh; nil; end
  def update; nil; end
end
charm = File.join(Harness::ROOT, "plugins", "charm_case.rb")
eval(Harness.source(charm), TOPLEVEL_BINDING, charm)
# The Rock Climb's module alone: its route step and carrier would reach every other test here.
climb = File.join(Harness::ROOT, "games", "keishou", "rock_climb.rb")
climb_src = Harness.source(climb)
eval(climb_src[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, climb)

class KeishouScreensGdTest < PokeAccessTest
  T = PokeAccess::I18n

  # What the info key holds as its line.
  def info_row; PokeAccess::Info.instance_variable_get(:@row); end

  # The Charm Case's window, as Window_CharmCase counts its rows: the stock, Close Case, and one each for the added rows.
  class CharmWindow
    attr_accessor :index

    def initialize(stock, adapter, elements, nature)
      @stock = stock
      @adapter = adapter
      @elements = elements
      @nature = nature
    end

    def itemCount
      n = @stock.length + 1
      n += 1 if @elements
      n += 1 if @nature
      n
    end
  end

  class CharmAdapter
    def getDisplayName(item); "Name of #{item}"; end
  end

  # The player as the plugin reads it.
  class CharmPlayer
    attr_accessor :elementCharmlist, :on

    def initialize(elements, on)
      @elementCharmlist = elements
      @on = on
    end

    def activeCharm?(charm); @on.include?(charm); end
  end

  def with_charm_player(elements, on)
    kept = $player
    $player = CharmPlayer.new(elements, on)
    # The game's own function, at the top level as the plugin defines it.
    Object.send(:define_method, :activeCharm?) { |c| $player.activeCharm?(c) }
    Object.send(:private, :activeCharm?)
    yield
  ensure
    Object.send(:remove_method, :activeCharm?)
    $player = kept
  end

  def rows(stock, elements, on)
    win = CharmWindow.new(stock, CharmAdapter.new, !elements.empty?, on.include?(:NATURECHARM))
    with_charm_player(elements, on) { (0...win.itemCount).map { |i| PokeAccess::CharmCase.entry(win, i) } }
  end

  test "each charm says its name and whether it is on, which only its picture shows" do
    assert_equal ["Name of A, #{T.t(:val_on)}", "Name of B, #{T.t(:val_off)}", "Close Case"], rows([:A, :B], [], [:A])
  end

  test "the added rows fall where drawItem paints them, Wishing over the last stock row, with all three" do
    got = rows([:A, :WISHINGCHARM], [:FIRE], [:WISHINGCHARM, :NATURECHARM])
    assert_equal ["Name of A, #{T.t(:val_off)}", "Nature Charm", "Elemental Charms", "Wishing Charm", "Close Case"], got
  end

  test "with Elemental Charms alone it sits just before Close Case; with Nature alone too" do
    assert_equal ["Name of A, #{T.t(:val_off)}", "Elemental Charms", "Close Case"], rows([:A], [:FIRE], [])
    assert_equal ["Name of A, #{T.t(:val_off)}", "Nature Charm", "Close Case"], rows([:A], [], [:NATURECHARM])
  end

  test "with Elemental and Nature and no Wishing, each takes its place" do
    assert_equal [2, 2], PokeAccess::CharmCase.tail_places(false, false, false)
    assert_equal [3, 2], PokeAccess::CharmCase.tail_places(false, true, true)
    assert_equal [2, 3], PokeAccess::CharmCase.tail_places(true, true, false)
    assert_equal [3, 2], PokeAccess::CharmCase.tail_places(true, false, true)
    assert_equal [4, 3], PokeAccess::CharmCase.tail_places(true, true, true)
  end

  test "a charm row keeps the item for the info key" do
    win = CharmWindow.new([:A], CharmAdapter.new, false, false)
    with_charm_player([], [:A]) { PokeAccess::CharmCase.entry(win, 0) }
    assert_equal "Name of A, #{T.t(:val_on)}", info_row
    assert_equal :item, PokeAccess::Info.instance_variable_get(:@kind)
  end

  def info_kept
    [PokeAccess::Info.instance_variable_get(:@kind), PokeAccess::Info.instance_variable_get(:@data), info_row]
  end

  test "an added row keeps the item its description box shows for the info key, Close Case its own words" do
    win = CharmWindow.new([:A, :WISHINGCHARM], CharmAdapter.new, true, true)
    kept = with_charm_player([:FIRE], [:WISHINGCHARM, :NATURECHARM]) do
      (1...win.itemCount).map do |i|
        PokeAccess::CharmCase.entry(win, i)
        info_kept
      end
    end
    assert_equal [[:item, :NATURECHARM, "Nature Charm"], [:item, :ELEMENTCHARM, "Elemental Charms"],
                  [:item, :WISHINGCHARM, "Wishing Charm"], [:text, "Close Case", "Close Case"]], kept
  end

  test "toggling a charm under a still cursor brings the info key up to date, the count beside it" do
    win = CharmWindow.new([:A], CharmAdapter.new, false, false)
    win.index = 0
    scene = CharmCase_Scene.new(win, "Active Charms: \n       1/3")
    with_charm_player([], []) do
      PokeAccess::CharmCase.entry(win, 0)
      assert_equal "Name of A, #{T.t(:val_off)}", info_row
      $player.on = [:A]
      scene.sprites["CharmCount"].text = "Active Charms: \n       2/3"
      scene.pbRefresh
      assert_equal [:item, :A, "Name of A, #{T.t(:val_on)}"], info_kept
      assert_equal "Name of A, #{T.t(:val_on)}. Active Charms: 2/3", PokeAccess::Info.row_text
    end
  end

  test "the count is said as the screen opens and then only as it changes, queued" do
    win = CharmWindow.new([:A], CharmAdapter.new, false, false)
    scene = CharmCase_Scene.new(win, "Active Charms: \n       1/3")
    scene.pbStartCharmScene
    assert_equal [["Active Charms: 1/3", false]], SpeakCapture.log
    SpeakCapture.clear
    2.times { scene.update }
    assert_equal [], SpeakCapture.log
    scene.sprites["CharmCount"].text = "Active Charms: \n       2/3"
    2.times { scene.update }
    assert_equal [["Active Charms: 2/3", false]], SpeakCapture.log
  end

  test "a screen with its count hidden says none" do
    win = CharmWindow.new([:A], CharmAdapter.new, false, false)
    scene = CharmCase_Scene.new(win, "Active Charms: 1/3")
    scene.sprites["CharmCount"].visible = false
    scene.pbStartCharmScene
    scene.update
    assert_equal [], SpeakCapture.log
  end

  # The Punch Bag's scene, as its pbMain leaves what the reader looks at.
  class BagScene
    attr_accessor :sprites

    def initialize(text, arrow_x, visible = true)
      @sprites = { "scorebox" => Struct.new(:text).new(text), "arrow" => Struct.new(:visible).new(visible) }
      @arrowX = arrow_x
      @arrowXMiddle = 200
    end

    attr_writer :arrowX
  end

  def with_gauge
    log = []
    meta = (class << PokeAccess::Sound; self; end)
    meta.send(:alias_method, :bag_spec_gauge, :gauge)
    PokeAccess::Sound.define_singleton_method(:gauge) { |f| log.push(f) }
    yield log
  ensure
    meta.send(:alias_method, :gauge, :bag_spec_gauge)
    meta.send(:remove_method, :bag_spec_gauge)
  end

  test "the punch bag opens with the score window's lines as sentences, and gives a tick only when the arrow moves" do
    s = BagScene.new("Score: 0 \nHits: 0/10", 72)
    with_gauge do |log|
      PokeAccess::PunchBagV12.playing(s) do
        2.times { PokeAccess::PunchBagV12.poll }
        s.arrowX = 200
        PokeAccess::PunchBagV12.poll
      end
      PokeAccess::PunchBagV12.poll
      assert_equal [0.0, 1.0], log, "the bar's end, then its centre, once each; nothing after the game ends"
    end
    assert_includes SpeakCapture.log[0][0], "Score: 0. Hits: 0/10"
    assert_equal false, SpeakCapture.log[0][1]
  end

  test "a hidden arrow gives no tick" do
    s = BagScene.new("Score: 0", 72, false)
    with_gauge do |log|
      PokeAccess::PunchBagV12.playing(s) { PokeAccess::PunchBagV12.poll }
      assert_equal [], log
    end
  end

  test "a hit says its stars, then the score as it now reads, interrupting" do
    PokeAccess::PunchBagV12.hit(BagScene.new("Score: 7 \nHits: 2/10", 0), 3)
    assert_equal [["#{T.t(:pbag_stars, :n => 3)}. Score: 7. Hits: 2/10", true]], SpeakCapture.log
    assert_equal "Score: 7. Hits: 2/10", info_row
  end

  AkiMember = Struct.new(:name)

  def aki_team(*names); names.map { |n| AkiMember.new(n) }; end

  test "the tournament record is said whole on its loop's first frame, once, the team after the record" do
    assert_equal :closed, AkiEventScene.new.pbAkiRecordScreen(aki_team("Pikachu", "Eevee"))
    want = PokeAccess.sentences(["Tournament Record", "Endless - Hard Mode", "Armorite Ore earned: 12", "Trainers beaten: 7",
                                 T.t(:zden_party, :list => "Pikachu, Eevee")])
    assert_equal [[want, false]], SpeakCapture.log
  end

  test "a record with nothing painted says nothing" do
    assert_nil PokeAccess::KeishouAkiRecord.line([], aki_team("Pikachu"))
  end

  test "two members of the same name are both said" do
    AkiEventScene.new.pbAkiRecordScreen(aki_team("Pikachu", "Pikachu", "Eevee"))
    assert_includes SpeakCapture.log[0][0], T.t(:zden_party, :list => "Pikachu, Pikachu, Eevee")
  end

  test "closing the record forgets it for the info key" do
    PokeAccess::Info.set_info(:text, "x", "x")
    AkiEventScene.new.pbAkiRecordScreen([])
    assert_nil info_row
  end

  # A map of climbable columns for the Rock Climb's module.
  def with_rock(tiles)
    meta = (class << PokeAccess::World::Terrain; self; end)
    meta.send(:alias_method, :climb_spec_flag, :flag?)
    PokeAccess::World::Terrain.define_singleton_method(:flag?) { |x, y, name| name == :can_climb && tiles.include?([x, y]) }
    probe = (class << PokeAccess::World::Probe; self; end)
    probe.send(:alias_method, :climb_spec_landing, :landing)
    PokeAccess::World::Probe.define_singleton_method(:landing) { |x, y| [x, y] }
    yield
  ensure
    meta.send(:alias_method, :flag?, :climb_spec_flag)
    meta.send(:remove_method, :climb_spec_flag)
    probe.send(:alias_method, :landing, :climb_spec_landing)
    probe.send(:remove_method, :climb_spec_landing)
  end

  test "a climb runs straight to the first tile past the rock, up or down" do
    with_rock([[5, 4], [5, 3], [5, 2]]) do
      assert_equal [5, 1], PokeAccess::KeishouRockClimb.climb(5, 5, 8)
      assert_equal [5, 5], PokeAccess::KeishouRockClimb.climb(5, 1, 2)
    end
  end

  test "it only climbs facing up or down, and with rock in front" do
    with_rock([[6, 5], [5, 3]]) do
      assert_nil PokeAccess::KeishouRockClimb.climb(5, 5, 6), "this copy has no sideways climb"
      assert_nil PokeAccess::KeishouRockClimb.climb(5, 5, 8), "no rock on the next tile"
    end
  end

  test "the Tera Type joins the summary's header and the PC's panel where each setting has it on" do
    pk = Struct.new(:tera_type).new(:FIRE)
    name = PokeAccess::Data.type_name(:FIRE)
    mark = T.t(:ss2_adv_tera, :t => name)
    assert_equal mark, PokeAccess::TerastalPhenomenon.mark(pk)
    assert_nil PokeAccess::TerastalPhenomenon.mark(Struct.new(:name).new("x")), "a release with no Tera Type says none"
  end
end
