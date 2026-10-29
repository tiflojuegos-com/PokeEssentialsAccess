# The save screen's summary panel where a plugin paints it instead of the locwindow (core/menus/save_panel.rb): the BW
# Save Screen of Dark Horizon and Golden Crown, which shows the party as icons over one positions batch, and the HGSS
# Save Screen's label and value pairs. The panel is said queued, top to bottom and left to right, then the team.

# The BW Save Screen's pbStartScreen: an icon sprite per party member (pokemon0...), then the summary painted in one
# pbDrawTextPositions batch, in the plugin's order rather than the screen's.
class BwSaveScreenStandIn
  Icon = Struct.new(:pokemon)

  def initialize(rows, party = [])
    @rows = rows
    @party = party
  end

  def pbStartScreen
    @sprites = {}
    @party.each_with_index { |pk, i| @sprites["pokemon#{i}"] = Icon.new(pk) }
    @sprites["overlay"] = :overlay
    pbDrawTextPositions(nil, @rows) unless @rows.empty?
    :started
  end
end

# A save screen whose own pbStartScreen fails, as a broken game script would.
class FailingSaveScreenStandIn
  def pbStartScreen
    raise ArgumentError, "the game's own save screen fails"
  end
end

PokeAccess::SavePanel.bind("BwSaveScreenStandIn")
PokeAccess::SavePanel.bind("FailingSaveScreenStandIn")

class BwSaveScreenGdTest < PokeAccessTest
  # Golden Crown's batch (BGSTYLE 1, the clock on): the clock, the counts, the map, the play time and the date.
  CROWN = [["14 : 05", 256, -2, 2], ["Badges: 3", 48, 197, false], ["Pokédex: 12", 256, 197, false],
           ["Ruta 1", 48, 82, false], ["Time: 01:23", 48, 227, false], ["28 Oct 2026", 46, 50, false]].freeze

  # Dark Horizon's edited batch: the shadow counts, the play time and the difficulty in place of the badges and the
  # Pokedex, every row 11 pixels lower.
  HORIZON = [["09 : 30", 256, 9, 2], ["Purified: 1", 48, 238, false], ["Snagged: 2", 48, 208, false],
             ["Pueblo Origen", 48, 93, false], ["Time: 0 : 07", 256, 208, false], ["5 Mar 2026", 46, 61, false],
             ["Diff: Hard Mode", 256, 238, false]].freeze

  # The HGSS Save Screen: the map, then each label with its value on the far side of the same row.
  HGSS = [["Ruta 1", 256, 38, 2], ["PLAYER:", 112, 70, 0], ["Rojo", 412, 70, 1], ["BADGES:", 112, 102, 0],
          ["3", 412, 102, 1], ["TIME:", 112, 166, 0], ["01:23", 412, 166, 1]].freeze

  test "the BW panel is said as it lies on the screen, row by row and left to right, then the team its icons show" do
    BwSaveScreenStandIn.new(CROWN, [Poke.build(:species => 1), Poke.build(:species => 4)]).pbStartScreen
    want = "14 : 05, 28 Oct 2026, Ruta 1, Badges: 3, Pokédex: 12, Time: 01:23. #{team('Species1, Species4')}"
    assert_equal [[want, false]], SpeakCapture.log
  end

  test "Dark Horizon's edited rows are said as painted, its shadow counts and difficulty included" do
    BwSaveScreenStandIn.new(HORIZON, [Poke.build(:species => 7)]).pbStartScreen
    want = "09 : 30, 5 Mar 2026, Pueblo Origen, Snagged: 2, Time: 0 : 07, Purified: 1, Diff: Hard Mode. " \
           "#{team('Species7')}"
    assert_equal [want], SpeakCapture.lines
  end

  test "a shiny icon is said shiny and an egg's icon as an egg, in the icons' order" do
    egg = Poke.build(:species => 9)
    def egg.egg?; true; end
    party = [Poke.build(:species => 2, :shiny => true), egg]
    BwSaveScreenStandIn.new(CROWN, party).pbStartScreen
    shown = "Species2 #{PokeAccess::I18n.t(:pk_shiny)}, #{PokeAccess::I18n.t(:pty_egg)}"
    assert_spoken_once(/\. #{Regexp.escape(team(shown))}\z/)
  end

  test "a label ending in a colon is said with the value on the far side of its row" do
    BwSaveScreenStandIn.new(HGSS).pbStartScreen
    assert_equal ["Ruta 1, PLAYER: Rojo, BADGES: 3, TIME: 01:23"], SpeakCapture.lines
  end

  test "a panel with no party icons is said without a team line, and one that paints nothing says nothing" do
    BwSaveScreenStandIn.new(CROWN).pbStartScreen
    assert_equal ["14 : 05, 28 Oct 2026, Ruta 1, Badges: 3, Pokédex: 12, Time: 01:23"], SpeakCapture.lines
    SpeakCapture.clear
    BwSaveScreenStandIn.new([], [Poke.build]).pbStartScreen
    assert_nothing_spoken
  end

  test "the locwindow, where the screen builds one, is read instead of the paint" do
    PokemonSave_Scene.new.pbStartScreen
    assert_equal ["Ruta 5, Player, Ceniza, Time, 3h 12m, Badges, 3"], SpeakCapture.lines
  end

  test "an error of the game's own pbStartScreen reaches the game, and is not logged as the mod's" do
    assert_raises(ArgumentError) { FailingSaveScreenStandIn.new.pbStartScreen }
    logged = (File.readlines(PokeAccess.marker_file) rescue []).grep(/hook body FailingSaveScreenStandIn/)
    assert_equal [], logged
    assert_nothing_spoken
  end

  test "the screen keeps what its pbStartScreen answers" do
    assert_equal :started, BwSaveScreenStandIn.new(CROWN).pbStartScreen
  end

  test "a capture armed before the screen opens is still armed after it" do
    PokeAccess::PaintCapture.arm(:bw_save_outer)
    BwSaveScreenStandIn.new(CROWN).pbStartScreen
    assert PokeAccess::PaintCapture.armed?(:bw_save_outer), "the outer capture survives the panel's sample"
    PokeAccess::PaintCapture.take(:bw_save_outer)
  end

  private

  # The team line for the species the icons show.
  def team(list)
    PokeAccess::I18n.t(:load_party, :list => list)
  end
end
