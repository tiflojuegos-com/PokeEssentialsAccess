# Dark Horizon's Colosseum Points move tutors (games/darkhorizon/cp_moves.rb): the stock Battle Point list selling
# [move, price] pairs says the move, its price and, from medium, its type, the info key the move; any other shop's
# rows stay the core's; the shop's CP window and its own prompts are read.

# The move shop's adapter as the game writes it: the name and description from the move, the price in CP.
class BattlePointShopAdapter_Moves
  def getDisplayName(entry); GameData::Move.get(entry[0]).name; end
  def getDisplayPrice(entry, _selling = false); "#{entry[1]} CP"; end
  def getDescription(entry); GameData::Move.get(entry[0]).description; end
end

# The stock list window the shop builds, its stock and adapter kept as the core's row reads them.
class Window_BattlePointShop < Window_DrawableCommand
  def initialize(stock, adapter); super([]); @stock = stock; @adapter = adapter; end
end

# The move shop's scene: its points window and its prompts on its own help window.
class BattlePointShop_Moves_Scene
  def pbStartScene(_idx_shop, _adapter)
    @sprites = { "battlepointwindow" => Window_AdvancedTextPokemon.new("CP:<r>5 CP") }
    :started
  end

  def pbDisplay(_msg, _brief = false); :shown; end
  def pbDisplayPaused(_msg); :paused; end
  def pbConfirm(_msg); true; end
  def pbEndScene; :ended; end
end

cp_moves = File.join(Harness::ROOT, "games", "darkhorizon", "cp_moves.rb")
eval(Harness.source(cp_moves), TOPLEVEL_BINDING, cp_moves)

class DarkhorizonCpMovesGdTest < PokeAccessTest
  # Another shop's adapter, whose rows the core says.
  class ItemAdapter
    def getDisplayName(_item); "Protein"; end
    def getDisplayPrice(_item, _selling = false); "12 BP"; end
  end

  test "a row says the move and its price, then its type, queued as the list's first read" do
    focus(Window_BattlePointShop.new([[:FAIRYWIND, 1], [:SPIKES, 2]], BattlePointShopAdapter_Moves.new), 1)
    assert_equal [["MoveSPIKES, 2 CP, TypeTYPE1", false]], SpeakCapture.log
  end

  test "at brief a row leaves the type out" do
    PokeAccess::Config.verbosity = :brief
    assert_equal "MoveFAIRYWIND, 1 CP",
                 PokeAccess::Shops.row(Window_BattlePointShop.new([[:FAIRYWIND, 1]], BattlePointShopAdapter_Moves.new), 0)
  end

  test "the info key says the focused move, and Ctrl with it the whole row" do
    PokeAccess::Shops.row(Window_BattlePointShop.new([[:FAIRYWIND, 1]], BattlePointShopAdapter_Moves.new), 0)
    assert_match(/MoveFAIRYWIND/, PokeAccess::Info.info_text)
    assert_equal "MoveFAIRYWIND, 1 CP, TypeTYPE1", PokeAccess::Info.row_text
  end

  test "the row past the stock is Cancel, as in every shop" do
    win = Window_BattlePointShop.new([[:FAIRYWIND, 1]], BattlePointShopAdapter_Moves.new)
    assert_equal PokeAccess::I18n.t(:pc_cancel), PokeAccess::Shops.row(win, 1)
  end

  test "another shop's row stays the core's" do
    assert_equal "Protein, 12 BP", PokeAccess::Shops.row(Window_BattlePointShop.new([:PROTEIN], ItemAdapter.new), 0)
  end

  test "the points window is read while the shop is open" do
    BattlePointShop_Moves_Scene.new.pbStartScene(0, BattlePointShopAdapter_Moves.new)
    SpeakCapture.clear
    PokeAccess::InfoWindow.tick
    assert_spoken(/5 CP/)
  end

  test "the shop's prompts are said as it shows them, and keep their returns" do
    scene = BattlePointShop_Moves_Scene.new
    got = [scene.pbDisplayPaused("You don't have enough CP."), scene.pbConfirm("Teach Spikes? That will be 2 CP."),
           scene.pbDisplay("All done! Thank you!")]
    assert_equal [:paused, true, :shown], got
    ["You don't have enough CP.", "Teach Spikes? That will be 2 CP.", "All done! Thank you!"].each do |line|
      assert_spoken(/\A#{Regexp.escape(line)}\z/)
    end
  end

  private

  # Puts a window's cursor on row i and runs its update, as the shop's list does each frame.
  def focus(win, i)
    win.index = i
    win.update
  end
end
