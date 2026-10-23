# The marks a gen-6 databox draws beside a battler's name (battleBoxOwned, shiny, the Mega and Primal boxes), read from
# the images its refresh paints: on the HP key's line from the battle marks reading's medium level, always on the info
# key's, and said once, queued, as a foe comes in.
class DataboxMarksTest < PokeAccessTest
  T = PokeAccess::I18n
  Battle = PokeAccess::Battle

  # A gen-6 battler as its box and the readers see it: a level-12 male Pidgey at full hp, with no status and no battle
  # types of its own, so its Pokemon's (0 and 2) are the ones shown.
  class Battler
    attr_accessor :name, :level, :hp, :totalhp, :gender, :displayGender, :status, :index, :pokemon
    def initialize(index)
      @index = index; @pokemon = Struct.new(:type1, :type2).new(0, 2)
      @name = "Pidgey"; @level = 12; @hp = 30; @totalhp = 30
      @gender = 0; @displayGender = 0; @status = 0
    end
    def pbTypes(_withtype = false); []; end
  end

  test "keeps what the box's refresh answers" do
    assert_equal :refreshed, PokemonDataBox.new(Battler.new(1)).refresh
  end

  test "adds nothing to either line for a box that draws no mark" do
    foe = in_battle(Battler.new(1))
    PokemonDataBox.new(foe).refresh
    assert_equal [plain_state, plain_info], [Battle.battler_state(foe, true), Battle.foe_info]
  end

  test "adds a caught foe's mark after its state, on the HP key's line and the info key's" do
    foe = in_battle(Battler.new(1))
    drawn(foe, :owned => true)
    assert_equal ["#{plain_state}, #{caught_word}", "#{plain_info}, #{caught_word}"],
                 [Battle.battler_state(foe, true), Battle.foe_info]
  end

  test "puts the marks straight after the level on the info key's line for a foe that shows no types" do
    foe = in_battle(Battler.new(1))
    foe.pokemon = Object.new
    drawn(foe, :owned => true)
    assert_equal "#{T.t(:bt_foe, :name => "Pidgey ♂", :level => 12)}, #{caught_word}", Battle.foe_info
  end

  test "names the marks in the order drawn, each once" do
    foe = Battler.new(1)
    drawn(foe, :owned => true, :shiny => true,
               :extra => %w[battleMegaEvoBox battleBoxOwned2 battlePrimalGroudonBox battleBoxGender])
    marks = [caught_word, T.t(:pk_shiny), T.t(:bt_mark_mega), T.t(:bt_mark_primal)]
    assert_equal "#{plain_state}, #{marks.join(', ')}", Battle.battler_state(foe, true)
  end

  test "puts the marks after the status and before the stat changes" do
    foe = Battler.new(1)
    foe.status = 1
    foe.instance_variable_set(:@stages, [0, 1, 0, 0, 0, 0, 0])
    drawn(foe, :owned => true)
    assert_equal "#{plain_state}, #{T.t(:st_sleep)}, #{caught_word}#{T.t(:bt_changes, :list => 'Estadistica1 +1')}",
                 Battle.battler_state(foe, true)
  end

  test "says a foe's marks once as it comes in, queued" do
    foe = Battler.new(1)
    box = drawn(foe, :owned => true, :shiny => true)
    box.refresh
    assert_equal [[T.t(:bt_marks_entry, :name => "Pidgey", :marks => "#{caught_word}, #{T.t(:pk_shiny)}"), false]],
                 SpeakCapture.log
  end

  test "leaves a mark drawn after the foe came in to the battle's own message" do
    foe = Battler.new(1)
    box = drawn(foe)
    box.owned = true
    box.refresh
    assert_nothing_spoken
    assert_equal "#{plain_state}, #{caught_word}", Battle.battler_state(foe, true), "while the HP key has it"
  end

  test "says nothing as the player's own Pokemon comes in with marks" do
    [0, 2].each do |index|
      mine = Battler.new(index)
      drawn(mine, :shiny => true)
      assert_equal "#{plain_state}, #{T.t(:pk_shiny)}", Battle.battler_state(mine, true), "slot #{index}'s HP key"
    end
    assert_nothing_spoken
  end

  test "says the marks of a new Pokemon sent into the same slot" do
    foe = Battler.new(3)
    box = drawn(foe, :owned => true)
    SpeakCapture.clear
    foe.pokemon = Struct.new(:type1, :type2).new(0, 2)
    box.refresh
    assert_equal [[T.t(:bt_marks_entry, :name => "Pidgey", :marks => caught_word), false]], SpeakCapture.log
  end

  test "has the marks on the HP key's line from medium" do
    foe = in_battle(Battler.new(1))
    drawn(foe, :owned => true)
    marked = "#{plain_state}, #{caught_word}"
    said = vb_levels do
      SpeakCapture.clear
      Battle.announce_hp(true)
      SpeakCapture.log.dup
    end
    assert_equal [[[plain_state, true]], [[marked, true]], [[marked, true]]], said
  end

  test "keeps the marks on the info key's line at brief" do
    foe = in_battle(Battler.new(1))
    drawn(foe, :owned => true)
    PokeAccess::Config.verbosity = :brief
    assert_equal "#{plain_info}, #{caught_word}", Battle.foe_info
  end

  test "says a foe's marks as it comes in from medium" do
    said = vb_levels do
      SpeakCapture.clear
      drawn(Battler.new(1), :owned => true)
      SpeakCapture.lines
    end
    entry = T.t(:bt_marks_entry, :name => "Pidgey", :marks => caught_word)
    assert_equal [[], [entry], [entry]], said
  end

  test "stops saying a mark the box stops drawing" do
    foe = Battler.new(1)
    box = drawn(foe, :owned => true)
    box.owned = false
    box.refresh
    assert_equal plain_state, Battle.battler_state(foe, true)
  end

  test "leaves a box with no battler alone" do
    box = PokemonDataBox.new(nil)
    box.owned = true
    assert_equal :refreshed, box.refresh
    assert_nothing_spoken
  end

  private

  # The HP key's line for the battler with nothing added: name and sign, level and hp as a percentage.
  def plain_state
    T.t(:bt_state, :name => "Pidgey ♂", :level => 12, :hp => T.t(:bt_hp_pct, :n => 100))
  end

  # The info key's line for the battler as a foe, with nothing added: name and sign, level and types.
  def plain_info
    "#{T.t(:bt_foe, :name => "Pidgey ♂", :level => 12)}, #{T.t(:bt_type, :t => "Tipo0 Tipo2")}"
  end

  # The word for the caught mark.
  def caught_word
    T.t(:dex_caught)
  end

  # The battler as the foe in the battle the hp and info keys read, facing the player's own Pikachu.
  def in_battle(foe)
    mine = Battler.new(0)
    mine.name = "Pikachu"
    battle = Object.new
    battle.define_singleton_method(:battlers) { [mine, foe] }
    Battle.set_battle(battle)
    foe
  end

  # The battler's box with the given seams (:owned, :shiny, :extra), refreshed once.
  def drawn(battler, seams = {})
    box = PokemonDataBox.new(battler)
    seams.each { |seam, value| box.send("#{seam}=", value) }
    box.refresh
    box
  end
end
