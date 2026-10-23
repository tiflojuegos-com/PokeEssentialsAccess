# Page one's Pokedex number as painted, said after the data sheet's heading: the value on the Dex label's row or, where
# the label is part of the background, the topmost value on the right half; question marks as unknown.
class SummaryDexNumberTest < PokeAccessTest
  T = PokeAccess::I18n
  DEX = "N\xC2\xB0 Dex"
  MALE = "\xE2\x99\x82"

  test "reads the value on the Dex label's row, not the level beside the name" do
    page = [["DATOS", 26, 16], ["Pika", 46, 62], ["100", 46, 92], [DEX, 238, 80], ["025", 435, 80],
            ["Especie", 238, 112], ["Pikachu", 435, 112]]
    assert_equal "025", dex_of(page)
  end

  test "reads the value on the label's row when the page paints it after the other labels" do
    page = [["No. Dex", 238, 86], ["Especie", 238, 118], ["Pikachu", 435, 118], ["Puntos Exp.", 238, 246],
            ["250", 488, 278], ["012", 435, 86]]
    assert_equal "012", dex_of(page)
  end

  test "reads the label's value even where a row above it sits on the right half" do
    assert_equal "025", dex_of([["Pikachu", 300, 40], [DEX, 238, 80], ["025", 435, 80]])
  end

  test "takes a value up to eight pixels off the label's row as its own" do
    { 72 => "025", 88 => "025", 89 => nil }.each do |y, want|
      got = dex_of([[DEX, 238, 80], ["025", 435, y]])
      want ? assert_equal(want, got, "a value at y #{y}") : assert_nil(got, "a value at y #{y}")
    end
  end

  test "leaves out a number on the label's row that is not right of the label" do
    assert_equal "025", dex_of([["123", 150, 80], [DEX, 238, 80], ["025", 435, 80]]), "a number left of it"
    assert_nil dex_of([[DEX, 238, 80], ["123", 238, 80]]), "a number at its own x"
  end

  test "takes three or four digits as a number, and no other count" do
    { "025" => "025", "1025" => "1025", "25" => nil, "10250" => nil }.each do |painted, want|
      got = dex_of([[DEX, 238, 80], [painted, 435, 80]])
      want ? assert_equal(want, got, "painted #{painted}") : assert_nil(got, "painted #{painted}")
    end
  end

  test "reads a number the page paints in colour" do
    assert_equal "025", dex_of([[DEX, 238, 80], ["<c3=F83818,E09890>025", 435, 80]])
  end

  test "leaves out rows painted with no position" do
    pairs = [[DEX, :positions, 238, 80], ["123", :formatted, nil, 80], ["025", :positions, 435, 80]]
    assert_equal "025", PokeAccess::Summary.painted_dex_number(pairs)
  end

  test "with no label, reads the topmost value on the right half" do
    page = [["Nombre", 238, 112], ["Pikachu", 435, 112], ["Tipo", 238, 144], ["Planta", 435, 144], ["007", 435, 80]]
    assert_equal "007", dex_of(page)
  end

  test "with no label, leaves out the left half even above the number, its middle included" do
    assert_equal "007", dex_of([["Nombre", 238, 48], ["007", 435, 80]]), "the labels' column"
    assert_equal "007", dex_of([["Nombre", 256, 48], ["007", 435, 80]]), "a row starting at the middle"
  end

  test "with no label, has no number when the topmost row on the right half is not one" do
    assert_nil dex_of([["Pikachu", 435, 60], ["007", 435, 80]])
  end

  test "says the question marks of a Pokemon outside every dex as unknown" do
    assert_equal T.t(:pdx_unknown_short), dex_of([["No. Dex", 238, 86], ["???", 435, 86]])
  end

  test "has no number for a page that paints none" do
    assert_nil dex_of([])
    assert_nil PokeAccess::Summary.painted_dex_number(nil), "nor for a page not captured"
  end

  test "the data sheet on opening says the number page one paints after the heading" do
    scene = PokemonSummaryScene.new
    scene.instance_variable_set(:@page_one_paint, [[DEX, 238, 80], ["025", 435, 80]])
    scene.pbStartScene([Poke.build(:name => "Pika", :level => 20)], 0)
    assert_equal [[pika_sheet(T.t(:sum_dex, :n => "025")), false]], SpeakCapture.log
  end

  private

  # The number painted_dex_number reads from a page painted as [text, x, y] positions.
  def dex_of(rows)
    PokeAccess::Summary.painted_dex_number(rows.map { |r| [r[0], :positions, r[1], r[2]] })
  end

  # The gen-6 data sheet of the stub Pika at level 20, with after_heading said after its heading: species, nature and
  # ability from the gen-6 data, no item, its six stats and the lines of a Pokemon with no original trainer.
  def pika_sheet(after_heading)
    [T.t(:sum_data_of, :name => "Pika #{MALE}", :level => 20), after_heading, T.t(:sum_species, :s => "Especie1"),
     T.t(:sum_nature, :n => "Naturaleza0"), T.t(:sum_ability, :a => "Habilidad1"), T.t(:sum_item, :i => T.t(:sum_none)),
     T.t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35),
     T.t(:sum_ot, :name => T.t(:sum_loaned)), T.t(:sum_id, :id => T.t(:pdx_unknown_short))].join(" ")
  end
end
