# The screens Sevii opens from its maps (games/sevii/field_screens.rb), over stand-ins shaped as its scripts: the
# Fossil Maniac's drawer, @SelNo over @Items with its row and column, the Game Corner's prize wheel, the caves'
# braille inscriptions, Drake's book and a quest's banner. Their loops are left out: a test runs main for the opening
# and pbRefresh for each move.

# The drawer: main is its loop, pbRefresh what each arrow runs once the cursor moved.
class Drawer
  def initialize(items)
    @Items = items
    @SelNo = 0
    @SelCol = 0
    @SelRow = 0
  end
  def main; :looped; end
  def pbRefresh; :refreshed; end
end

# The prize wheel, its ten prizes in @prizes: items, Pokemon, or an amount of coins with @prizecoins.
class PrizeWheel
  def initialize(prizes, coins)
    @prizes = prizes
    @prizecoins = coins
  end
  def main; :looped; end
end

def pbBrailleMessage(_text); :closed; end
def pbDrakeBook; :closed; end

# The banner a quest's start or end slides in: the quest's name painted over its label, then the wait for a key, left
# out.
class QuestAnim
  def initialize(name, color, complete = false)
    pbDrawOutlineText(nil, 74, -142, 512, 384, name, color, nil)
    pbDrawOutlineText(nil, 94, -102, 512, 384, complete ? "QUEST COMPLETE" : "NEW QUEST", nil, nil)
  end
end

PBSpecies.const_set(:BIDOOF, 399) unless PBSpecies.const_defined?(:BIDOOF)

class SeviiFieldScreensTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "sevii", "field_screens.rb")

  test "the drawer says the item under the cursor and its place, then its keys, queued, as it opens" do
    open_drawer
    keys = t(:sv_drawer_keys, :take => t(:key_enter), :quit => t(:key_escape))
    assert_equal [[t(:sv_slot, :name => "Repel", :row => 1, :col => 1), false], [keys, false]], SpeakCapture.log
  end

  test "the drawer leaves its keys out while key hints are not said" do
    PokeAccess::Config.verbosity = :brief
    open_drawer
    assert_equal 1, SpeakCapture.log.length
  end

  test "the drawer says the slot the cursor moves to, cutting in, and an empty one as empty" do
    d = open_drawer
    move(d, 1, 0, 1)
    move(d, 7, 1, 2)
    assert_equal [[t(:sv_slot, :name => "Caramelo Raro", :row => 1, :col => 2), true],
                  [t(:sv_slot_empty, :row => 2, :col => 3), true]], SpeakCapture.log[2..-1]
  end

  test "after a No to taking its item, the drawer says the slot again, queued behind the answer" do
    d = open_drawer
    assert_equal :refreshed, d.pbRefresh
    assert_equal [t(:sv_slot, :name => "Repel", :row => 1, :col => 1), false], SpeakCapture.log.last
    assert_equal 3, SpeakCapture.log.length
  end

  test "the prize wheel says its prizes in order, items, Pokemon and coins, queued, as it opens" do
    self.class.bind
    assert_equal :looped, PrizeWheel.new(["50", :REPEL, "100", :BIDOOF], true).main
    list = [t(:sv_wheel_coins, :n => 50), "Repel", t(:sv_wheel_coins, :n => 100), "Especie399"].join(", ")
    keys = t(:sv_wheel_keys, :spin => t(:key_enter), :quit => t(:key_escape))
    assert_equal [["#{t(:sv_wheel_prizes, :list => list)}. #{keys}", false]], SpeakCapture.log
  end

  test "a wheel that pays money says its amounts as money" do
    self.class.bind
    PokeAccess::Config.verbosity = :brief
    PrizeWheel.new(["500"], false).main
    assert_equal [[t(:sv_wheel_prizes, :list => t(:tr_money, :n => 500)), false]], SpeakCapture.log
  end

  test "a braille inscription is said as text, queued, and kept in the message history" do
    self.class.bind
    assert_equal :closed, pbBrailleMessage("RELICANTH FIRST.")
    line = t(:sv_braille, :text => "RELICANTH FIRST.")
    assert_equal [[line, false]], SpeakCapture.log
    assert_equal [line], PokeAccess::History.lines_of(:dialogue).map { |m| m.text }
  end

  test "a new quest's banner says its name and label as painted, as dialogue, then the key that closes it" do
    self.class.bind
    QuestAnim.new("Find the Lost Ring", nil)
    assert_equal [["Find the Lost Ring. NEW QUEST", false], [t(:title_press, :key => t(:key_enter)), false]],
                 SpeakCapture.log
    assert_equal ["Find the Lost Ring. NEW QUEST"], PokeAccess::History.lines_of(:dialogue).map { |m| m.text }
  end

  test "a finished quest's banner says its painted label; its key is left out while key hints are not said" do
    self.class.bind
    PokeAccess::Config.verbosity = :brief
    QuestAnim.new("Find the Lost Ring", nil, true)
    assert_equal [["Find the Lost Ring. QUEST COMPLETE", false]], SpeakCapture.log
  end

  test "outline text painted outside a quest banner is left alone" do
    self.class.bind
    pbDrawOutlineText(nil, 0, 0, 512, 384, "Elsewhere", nil, nil)
    pbDrawOutlineText(nil, 0, 40, 512, 384, "Again", nil, nil)
    assert_nothing_spoken
  end

  test "Drake's book is described as it opens, cutting in, then the key that closes it" do
    self.class.bind
    assert_equal :closed, pbDrakeBook
    hint = t(:title_press, :key => t(:key_enter))
    assert_equal [["#{t(:sv_drake_book)} #{hint}", true]], SpeakCapture.log
  end

  test "Drake's book leaves its key out while key hints are not said" do
    self.class.bind
    PokeAccess::Config.verbosity = :brief
    pbDrakeBook
    assert_equal [[t(:sv_drake_book), true]], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  def open_drawer
    self.class.bind
    d = Drawer.new([:REPEL, :RARECANDY, :POTION, :REPEL, :RARECANDY, :POTION])
    assert_equal :looped, d.main
    d
  end

  def move(drawer, idx, row, col)
    { :@SelNo => idx, :@SelRow => row, :@SelCol => col }.each { |k, v| drawer.instance_variable_set(k, v) }
    drawer.pbRefresh
  end

  # Evaluates field_screens.rb once, the profile list put back as it was.
  def self.bind
    return if @bound
    @bound = true
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
