# The v22 Pokedex list (UI::PokedexVisuals): a caught species is named with "caught" and a seen one with "seen" (both
# marks from the medium level), one never seen only as unknown; the whole row goes to the info key.
class PokedexListV22GdTest < PokeAccessTest
  LIST = [:BULBASAUR, :CHARMANDER, :MEWTWO].freeze

  test "names a caught species and says it is caught" do
    read_rows(0)
    assert_equal [["SpeciesBULBASAUR, #{t(:dex_caught)}", true]], SpeakCapture.log
  end

  test "names a species only seen and says it is seen" do
    read_rows(1)
    assert_equal [["SpeciesCHARMANDER, #{t(:dex_seen)}", true]], SpeakCapture.log
  end

  test "says a species never seen is unknown, without its name" do
    read_rows(2)
    assert_equal [[t(:dex_unknown), true]], SpeakCapture.log
  end

  test "says nothing when the cursor is redrawn on the same row" do
    read_rows(0, 0)
    assert_equal ["SpeciesBULBASAUR, #{t(:dex_caught)}"], SpeakCapture.lines
  end

  test "says each row the cursor moves to" do
    read_rows(0, 1, 0)
    assert_equal ["SpeciesBULBASAUR, #{t(:dex_caught)}", "SpeciesCHARMANDER, #{t(:dex_seen)}",
                  "SpeciesBULBASAUR, #{t(:dex_caught)}"], SpeakCapture.lines
  end

  test "leaves the caught and seen marks out at the brief level" do
    said = [0, 1].map do |row|
      vb_levels do
        SpeakCapture.clear
        read_rows(row)
        SpeakCapture.last
      end
    end
    caught = "SpeciesBULBASAUR, #{t(:dex_caught)}"
    seen = "SpeciesCHARMANDER, #{t(:dex_seen)}"
    assert_equal [["SpeciesBULBASAUR", caught, caught], ["SpeciesCHARMANDER", seen, seen]], said
  end

  test "puts the whole row on the info key, marks included, whatever the level" do
    PokeAccess::Config.verbosity = :brief
    read_rows(1)
    whole = "SpeciesCHARMANDER, #{t(:dex_seen)}"
    assert_equal [whole, whole], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "puts unknown on the info key for a species never seen" do
    read_rows(2)
    assert_equal t(:dex_unknown), PokeAccess::Info.info_text
  end

  test "says unknown, never the name, when the pokedex cannot answer" do
    dex = Object.new
    def dex.owned?(_species); raise "no dex"; end
    def dex.seen?(_species); raise "no dex"; end
    with_pokedex(dex) { UI::PokedexVisuals.new(LIST).set_index(0) }
    assert_equal [[t(:dex_unknown), true]], SpeakCapture.log
  end

  test "says nothing on a row with no species" do
    read_rows(LIST.length)
    assert_nothing_spoken
  end

  private

  # Moves a fresh list's cursor to each index in turn, the player having caught Bulbasaur and seen Charmander.
  def read_rows(*indexes)
    with_pokedex(fake_dex([:BULBASAUR], [:BULBASAUR, :CHARMANDER])) do
      vis = UI::PokedexVisuals.new(LIST)
      indexes.each { |i| vis.set_index(i) }
    end
  end

  # A pokedex owning and seeing the given species.
  def fake_dex(owned, seen)
    dex = Object.new
    dex.define_singleton_method(:owned?) { |species| owned.include?(species) }
    dex.define_singleton_method(:seen?) { |species| seen.include?(species) }
    dex
  end

  # Runs the block with $player's pokedex swapped for dex.
  def with_pokedex(dex)
    previous = $player.pokedex
    $player.instance_variable_set(:@dex, dex)
    yield
  ensure
    $player.instance_variable_set(:@dex, previous)
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end
end
