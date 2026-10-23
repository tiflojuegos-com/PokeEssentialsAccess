# Page one's trainer lines (core/party/summary.rb): the original trainer with the sex gen-6's page tints the name with,
# and the ID as the page paints it, which a game may write other than the Pokemon's own.
class SummaryTrainerTest < PokeAccessTest
  T = PokeAccess::I18n
  ID = "ID No."

  test "says the original trainer as a boy or a girl where the page paints the name blue or red" do
    { 0 => :chr_male, 1 => :chr_female }.each do |sex, key|
      assert_equal T.t(:sum_ot, :name => "Laura, #{T.t(key)}"), facts(trainer("Laura", sex))[0], "otgender #{sex}"
    end
  end

  test "says only the name where the page paints it grey, or the Pokemon keeps no sex for its trainer" do
    assert_equal T.t(:sum_ot, :name => "Mark"), facts(trainer("Mark", 2))[0]
    assert_equal T.t(:sum_ot, :name => "Mark"), facts(trainer("Mark", nil))[0]
  end

  test "says the ID the page paints on the ID label's row over the Pokemon's own" do
    pk = trainer("Kirk", 0)
    assert_equal T.t(:sum_id, :id => "04336"), facts(pk, "04336")[1]
    assert_equal T.t(:sum_id, :id => "02270"), facts(pk)[1], "the Pokemon's own, padded, when none was painted"
  end

  test "reads the five digits right of the ID label on its row" do
    page = [["Dex No.", 238, 80], ["025", 435, 80], [ID, 238, 208], ["04336", 435, 208], ["Exp. Points", 238, 240],
            ["12500", 488, 272]]
    assert_equal "04336", id_of(page)
  end

  test "reads no ID off a page with no ID label, nor a value that is not five digits" do
    assert_nil id_of([["OT", 238, 176], ["Kirk", 435, 176], ["12500", 488, 208]])
    assert_nil id_of([[ID, 238, 208], ["?????", 435, 208]])
    assert_nil PokeAccess::Summary.painted_trainer_id(nil)
  end

  test "the data sheet on opening says the ID page one paints" do
    pk = trainer("Kirk", 0)
    scene = PokemonSummaryScene.new
    scene.instance_variable_set(:@page_one_paint, [[ID, 238, 208], ["04336", 435, 208]])
    scene.pbStartScene([pk], 0)
    assert_equal [[PokeAccess::Info.summary_text(pk, nil, "04336"), false]], SpeakCapture.log
    assert_includes SpeakCapture.log[0][0], T.t(:sum_id, :id => "04336")
  end

  private

  # A Pokemon from trainer name with gen-6's otgender (nil: none kept), public ID 2270.
  def trainer(name, sex)
    pk = Poke.build(:name => "Shuckie")
    pk.define_singleton_method(:ot) { name }
    pk.define_singleton_method(:publicID) { 2270 }
    pk.define_singleton_method(:otgender) { sex } unless sex.nil?
    pk
  end

  # The trainer lines of pk, with the ID the page painted.
  def facts(pk, painted = nil)
    PokeAccess::Summary.trainer_facts(pk, painted)
  end

  # The ID painted_trainer_id reads from a page painted as [text, x, y] positions.
  def id_of(rows)
    PokeAccess::Summary.painted_trainer_id(rows.map { |r| [r[0], :positions, r[1], r[2]] })
  end
end
