# Video Poker, all painted: the focused card (kept or drawn, and flashing as part of the combination found), the bet
# with the purse and the pay table on the info key, double or nothing's pick and reference card, and the message line
# with the winning combination, each read in the loop the game runs.

# A card as the plugin keeps it: value (1 the ace, 11 to 13 the faces, 99 the joker) and suit (1 hearts, 2 diamonds,
# 3 clubs, 4 spades).
VpSpecCard = Struct.new(:value, :suit)
VpSpecCursor = Struct.new(:index)
VpSpecCombination = Struct.new(:name, :description, :bonus)
VpSpecFound = Struct.new(:combination)
VpSpecWindow = Struct.new(:text)

# The screen: the wager, the combination found and its own test of a card.
class VpSpecScreen
  attr_accessor :wager, :combination_found
  def initialize(cards); @cards = cards; end
  def hand_card_in_combination?(i); @cards.include?(i); end
end

# The scene: the Hold/Draw label printed under each card and the purse as painted.
class VpSpecScene
  attr_accessor :player_coins
  def current_label_text(i); i == 0 ? "Hold" : "Draw"; end
end

# The plugin's own scene as the reader's hooks see it: each loop runs its frames, every frame one update_all after the
# frame's change to the scene.
class VpSpecLoopScene < VpSpecScene
  attr_accessor :frames
  def select_wager_loop; run_frames; end
  def cursor_loop; run_frames; end
  def double_or_nothing_cursor_select; run_frames; end
  def show_result(_earnings); nil; end
  def show_result_as_draw; nil; end
  def update_all; nil; end
  def run_frames; (@frames || []).each { |change| change.call(self); update_all }; end
end

# The plugin's own screen: settling the wager answers what the player chose, and the session at the machine runs
# the block it is handed.
class VpSpecLoopScreen < VpSpecScreen
  attr_accessor :settled
  def initialize(scene); super([]); @scene = scene; end
  def select_wager; @settled; end
  def main_loop; yield if block_given?; end
end

class VideoPokerCombinationTest < PokeAccessTest
  READ = PokeAccess::VideoPokerRead
  PLUGIN = File.join(Harness::ROOT, "plugins", "video_poker.rb")

  # Loads the plugin again with these classes standing in as VideoPoker::Scene and VideoPoker::Screen, so its hooks
  # bind to them, and answers the hooks that load reported missing; the name VideoPoker is put back as it was.
  # param file the name the source is evaluated under; a name of its own keeps the load out of the plugin's coverage
  def self.load_plugin_with(scene, screen, file = PLUGIN)
    verbose = $VERBOSE
    before = PokeAccess::Hooks.missing.dup
    saved = Object.const_defined?(:VideoPoker) ? Object.send(:remove_const, :VideoPoker) : nil
    game = Module.new
    game.const_set(:Scene, scene)
    game.const_set(:Screen, screen)
    Object.const_set(:VideoPoker, game)
    $VERBOSE = nil
    eval(Harness.source(PLUGIN), TOPLEVEL_BINDING, file)
    PokeAccess::Hooks.missing - before
  ensure
    $VERBOSE = verbose
    Object.send(:remove_const, :VideoPoker) if Object.const_defined?(:VideoPoker)
    Object.const_set(:VideoPoker, saved) if saved
  end
  private_class_method :load_plugin_with

  # Both loads run as this file loads, before any test: a class binds once, and the stand-ins' load comes last, as
  # the one the tests drive and coverage counts.
  MISSING_ON_BARE_GAME = load_plugin_with(Class.new, Class.new, "bare:#{PLUGIN}")
  load_plugin_with(VpSpecLoopScene, VpSpecLoopScreen)

  test "a card of the combination found says it flashes" do
    READ.card(hand_scene(0, true))
    assert_equal [["#{ace_hold}, #{t(:vp_in_combo)}", false]], SpeakCapture.log
  end

  test "a card outside the combination found is said plain" do
    READ.card(hand_scene(2, true))
    assert_equal [[t(:vp_card, :value => "5", :suit => t(:vp_clubs), :state => "Draw"), false]], SpeakCapture.log
  end

  test "with no combination highlighted no card is marked" do
    READ.card(hand_scene(0, false))
    assert_equal [[ace_hold, false]], SpeakCapture.log
  end

  test "a game that turns the flashing off marks no card, one that leaves it on or unset marks them" do
    { false => ace_hold, true => "#{ace_hold}, #{t(:vp_in_combo)}",
      :unset => "#{ace_hold}, #{t(:vp_in_combo)}" }.each do |flash, said|
      with_flash_cards(flash) do
        SpeakCapture.clear
        READ.card(hand_scene(0, true))
        assert_equal [[said, false]], SpeakCapture.log, "FLASH_CARDS #{flash.inspect}"
      end
    end
  end

  test "a card whose words stay the same is not said again as the combination found lights up" do
    cases = { "a card outside the combination" => [2, :unset], "any card with the flashing off" => [0, false] }
    cases.each do |what, (index, flash)|
      with_flash_cards(flash) do
        scene = hand_scene(index, false)
        READ.card(scene)
        SpeakCapture.clear
        scene.instance_variable_set(:@highlight_combination, true)
        READ.card(scene)
        assert_nothing_spoken what
      end
    end
  end

  test "a card the screen cannot test is not marked" do
    scene = hand_scene(0, true)
    scene.instance_variable_set(:@screen, Object.new)
    READ.card(scene)
    assert_equal [[ace_hold, false]], SpeakCapture.log
  end

  test "says each card the cursor moves to, interrupting, and a card again when it is kept or drawn" do
    scene = hand_scene(0, false)
    READ.card(scene)
    SpeakCapture.clear
    scene.instance_variable_get(:@cursor).index = 1
    READ.card(scene)
    READ.card(scene)
    def scene.current_label_text(_i); "Hold"; end
    READ.card(scene)
    assert_equal [[t(:vp_card, :value => t(:vp_ace), :suit => t(:vp_diamonds), :state => "Draw"), true],
                  [t(:vp_card, :value => t(:vp_ace), :suit => t(:vp_diamonds), :state => "Hold"), true]],
                 SpeakCapture.log
  end

  test "names the faces, the joker and a card of no known suit" do
    { [11, 4] => t(:vp_card, :value => t(:vp_jack), :suit => t(:vp_spades), :state => "Hold"),
      [12, 1] => t(:vp_card, :value => t(:vp_queen), :suit => t(:vp_hearts), :state => "Hold"),
      [13, 2] => t(:vp_card, :value => t(:vp_king), :suit => t(:vp_diamonds), :state => "Hold"),
      [99, nil] => t(:vp_joker, :state => "Hold"),
      [7, 9] => "7, Hold" }.each do |(value, suit), said|
      scene = hand_scene(0, false)
      scene.instance_variable_set(:@hand, [VpSpecCard.new(value, suit)])
      SpeakCapture.clear
      READ.card(scene)
      assert_equal [[said, false]], SpeakCapture.log, "value #{value}, suit #{suit.inspect}"
    end
  end

  test "a card whose label the scene cannot give is said without it" do
    scene = hand_scene(0, false)
    def scene.current_label_text(_i); raise "unpainted"; end
    READ.card(scene)
    assert_equal [[t(:vp_card_bare, :value => t(:vp_ace), :suit => t(:vp_hearts)), false]], SpeakCapture.log
  end

  test "says no card without a hand, a cursor or a card where it points" do
    { "no hand" => [:@hand, nil], "no cursor" => [:@cursor, nil],
      "a cursor past the hand" => [:@cursor, VpSpecCursor.new(5)],
      "a cursor that is no number" => [:@cursor, VpSpecCursor.new("1")] }.each do |what, (ivar, value)|
      scene = hand_scene(0, false)
      scene.instance_variable_set(ivar, value)
      READ.card(scene)
      assert_nothing_spoken what
    end
  end

  test "says the bet and the purse as painted, the first time queued, then each change interrupting" do
    scene = wager_scene(5, 95)
    READ.wager(scene)
    READ.wager(scene)
    PokeAccess.ivar(scene, :@screen).wager = 6
    scene.player_coins = 94
    READ.wager(scene)
    assert_equal [["#{t(:vp_wager, :n => 5)}. #{t(:vp_coins, :n => 95)}", false],
                  ["#{t(:vp_wager, :n => 6)}. #{t(:vp_coins, :n => 94)}", true]], SpeakCapture.log
  end

  test "says the bet alone where the scene paints no purse" do
    READ.wager(wager_scene(5, nil))
    assert_equal [[t(:vp_wager, :n => 5), false]], SpeakCapture.log
  end

  test "says no bet without a screen or a wager on it" do
    [VpSpecScene.new, wager_scene(nil, 95)].each { |scene| READ.wager(scene) }
    assert_nothing_spoken
  end

  test "puts the pay table at the bet on the info key: each combination, its pay and what makes it" do
    READ.wager(wager_scene(5, 95))
    assert_equal table_at_five, PokeAccess::Info.info_text
  end

  test "the pay table joins its rows without doubling a description's stop" do
    scene = wager_scene(1, 95)
    scene.instance_variable_set(:@combination_array, [VpSpecCombination.new("Full", "Un trío y una pareja.", 10),
                                                      VpSpecCombination.new("Color", "Cinco del mismo palo.", 5)])
    assert_equal "#{t(:vp_payout_row, :name => 'Full', :n => 10)}, Un trío y una pareja. " \
                 "#{t(:vp_payout_row, :name => 'Color', :n => 5)}, Cinco del mismo palo.", READ.payout_table(scene, 1)
  end

  test "pays a bet below one, or none, as a bet of one, and leaves nameless combinations out" do
    scene = wager_scene(0, 95)
    combos = PokeAccess.ivar(scene, :@combination_array) + [VpSpecCombination.new("", "Nada", 1)]
    scene.instance_variable_set(:@combination_array, combos)
    want = "#{t(:vp_payout_row, :name => 'Pareja', :n => 2)}, Dos cartas iguales. " \
           "#{t(:vp_payout_row, :name => 'Escalera', :n => 10)}"
    assert_equal [want, want], [READ.payout_table(scene, 0), READ.payout_table(scene, nil)]
  end

  test "a combination whose pay cannot be read pays nothing" do
    scene = VpSpecScene.new
    scene.instance_variable_set(:@combination_array, [Struct.new(:name, :description).new("Trío", "")])
    assert_equal t(:vp_payout_row, :name => "Trío", :n => 0), READ.payout_table(scene, 5)
  end

  test "has no pay table without combinations, or with none named" do
    { "no list" => nil, "an empty list" => [],
      "only nameless combinations" => [VpSpecCombination.new("", "", 2)] }.each do |what, list|
      scene = VpSpecScene.new
      scene.instance_variable_set(:@combination_array, list)
      assert_nil READ.payout_table(scene, 5), what
    end
  end

  test "double or nothing says the card picked of the face-down ones, the first time queued" do
    scene = pick_scene(1)
    READ.pick(scene)
    READ.pick(scene)
    PokeAccess.ivar(scene, :@cursor).index = 3
    READ.pick(scene)
    assert_equal [[t(:vp_pick, :n => 1, :tot => 4), false], [t(:vp_pick, :n => 3, :tot => 4), true]], SpeakCapture.log
  end

  test "double or nothing says no pick without a cursor" do
    scene = pick_scene(1)
    scene.instance_variable_set(:@cursor, nil)
    READ.pick(scene)
    assert_nothing_spoken
  end

  test "double or nothing without a hand counts no face-down cards in the pick" do
    scene = pick_scene(1)
    scene.instance_variable_set(:@hand, nil)
    READ.pick(scene)
    assert_equal [[t(:vp_pick, :n => 1, :tot => 0), false]], SpeakCapture.log
  end

  test "says the reference card bare and queued as double or nothing opens" do
    READ.reference(pick_scene(1))
    assert_equal [[t(:vp_reference, :card => t(:vp_card_bare, :value => "10", :suit => t(:vp_spades))), false]],
                 SpeakCapture.log
  end

  test "says no reference card without a hand" do
    [[], nil].each do |hand|
      scene = pick_scene(1)
      scene.instance_variable_set(:@hand, hand)
      READ.reference(scene)
    end
    assert_nothing_spoken
  end

  test "says the message line queued, once per change, with the winning combination while it is highlighted" do
    scene = message_scene("Elige las cartas")
    READ.message(scene)
    READ.message(scene)
    scene.instance_variable_set(:@highlight_combination, true)
    READ.message(scene)
    assert_equal [["Elige las cartas", false], ["Elige las cartas. Pareja", false]], SpeakCapture.log
  end

  test "joins the winning combination to a message line without doubling its stop" do
    scene = message_scene("¡Enhorabuena! Has ganado 10 fichas.")
    scene.instance_variable_set(:@highlight_combination, true)
    READ.message(scene)
    assert_equal [["¡Enhorabuena! Has ganado 10 fichas. Pareja", false]], SpeakCapture.log
  end

  test "says the round's result interrupting, and the frame's read does not repeat it" do
    scene = message_scene("Has perdido")
    READ.result(scene)
    READ.message(scene)
    assert_equal [["Has perdido", true]], SpeakCapture.log
  end

  test "says no message line for a window blank or missing, even with a combination highlighted" do
    blank = message_scene("   ")
    blank.instance_variable_set(:@highlight_combination, true)
    [blank, VpSpecScene.new].each { |scene| READ.message(scene) }
    assert_nothing_spoken
  end

  test "leaves out of the message line a combination without a name" do
    scene = message_scene("Fin")
    scene.instance_variable_set(:@highlight_combination, true)
    PokeAccess.ivar(scene, :@screen).combination_found = VpSpecFound.new(VpSpecCombination.new("", "", 0))
    READ.message(scene)
    assert_equal [["Fin", false]], SpeakCapture.log
  end

  test "each frame says the message line, then the focus of the loop held" do
    { :cards => [message_scene("Elige", hand_scene(0, false)), [["Elige", false], [ace_hold, false]]],
      :wager => [message_scene("Apuesta", wager_scene(5, nil)), [["Apuesta", false], [t(:vp_wager, :n => 5), false]]],
      :pick => [message_scene("Elige una", pick_scene(2)),
                [["Elige una", false], [t(:vp_pick, :n => 2, :tot => 4), false]]]
    }.each do |mode, (scene, said)|
      SpeakCapture.clear
      READ.hold(mode)
      READ.poll(scene)
      assert_equal said, SpeakCapture.log, mode.to_s
    end
  ensure
    READ.release
  end

  test "with the loop released, a frame says only the message line" do
    READ.hold(:cards)
    READ.release
    READ.poll(message_scene("Elige", hand_scene(0, false)))
    assert_equal [["Elige", false]], SpeakCapture.log
  end

  test "inside the wager loop each frame says the bet as it moves, and once the loop ends no frame says it" do
    scene = loop_scene { |s| s.instance_variable_set(:@screen, PokeAccess.ivar(wager_scene(5, nil), :@screen)) }
    scene.frames = [lambda { |_s| }, lambda { |s| PokeAccess.ivar(s, :@screen).wager = 6 }]
    scene.select_wager_loop
    PokeAccess.ivar(scene, :@screen).wager = 7
    scene.update_all
    assert_equal [[t(:vp_wager, :n => 5), false], [t(:vp_wager, :n => 6), true]], SpeakCapture.log
  end

  test "each cards loop reads its hand afresh, the same slot said again over a new hand" do
    scene = loop_scene { |s| s.instance_variable_set(:@hand, [VpSpecCard.new(1, 1)]) }
    scene.frames = [lambda { |_s| }]
    scene.cursor_loop
    scene.cursor_loop
    assert_equal [[ace_hold, false], [ace_hold, false]], SpeakCapture.log
  end

  test "double or nothing opens saying the reference card, then the card picked" do
    scene = loop_scene do |s|
      s.instance_variable_set(:@hand, [VpSpecCard.new(10, 4)] + Array.new(4) { VpSpecCard.new(2, 1) })
    end
    scene.frames = [lambda { |_s| }]
    scene.double_or_nothing_cursor_select
    assert_equal [[t(:vp_reference, :card => t(:vp_card_bare, :value => "10", :suit => t(:vp_spades))), false],
                  [t(:vp_pick, :n => 0, :tot => 4), false]], SpeakCapture.log
  end

  test "says the round's result as the scene shows it, a win or a draw, interrupting" do
    said = [:show_result, :show_result_as_draw].map do |shown|
      scene = message_scene("Empate", loop_scene)
      SpeakCapture.clear
      shown == :show_result ? scene.show_result(0) : scene.show_result_as_draw
      SpeakCapture.log.dup
    end
    assert_equal [[["Empate", true]], [["Empate", true]]], said
  end

  test "the wager settled puts the pay table on the info key until the player leaves the machine" do
    scene = wager_scene(5, 95)
    screen = VpSpecLoopScreen.new(scene)
    screen.wager = 5
    screen.settled = true
    during = nil
    screen.main_loop { screen.select_wager; during = PokeAccess::Info.info_text }
    assert_equal [table_at_five, nil], [during, PokeAccess::Info.info_text]
  end

  test "a wager not settled leaves the info key as it was" do
    screen = VpSpecLoopScreen.new(wager_scene(5, 95))
    screen.wager = 5
    PokeAccess::Info.set_info(:text, "Antes")
    screen.select_wager
    assert_equal "Antes", PokeAccess::Info.info_text
  end

  test "a Video Poker without a method the reader hooks reports no hook missing" do
    assert_equal [], MISSING_ON_BARE_GAME
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # The pay table of wager_scene's two combinations at a bet of five, as the info key holds it.
  def table_at_five
    "#{t(:vp_payout_row, :name => 'Pareja', :n => 10)}, Dos cartas iguales. " \
      "#{t(:vp_payout_row, :name => 'Escalera', :n => 50)}"
  end

  # The ace of hearts, kept: the hand's first card as the cards loop says it.
  def ace_hold
    t(:vp_card, :value => t(:vp_ace), :suit => t(:vp_hearts), :state => "Hold")
  end

  # The cards loop: an ace of hearts, an ace of diamonds and a five of clubs, the cursor on index, the first two the
  # combination found, highlighted or not.
  def hand_scene(index, highlight)
    s = VpSpecScene.new
    s.instance_variable_set(:@hand, [VpSpecCard.new(1, 1), VpSpecCard.new(1, 2), VpSpecCard.new(5, 3)])
    s.instance_variable_set(:@cursor, VpSpecCursor.new(index))
    s.instance_variable_set(:@highlight_combination, highlight)
    s.instance_variable_set(:@screen, VpSpecScreen.new([0, 1]))
    s
  end

  # The wager loop: the bet on the screen, the purse the scene paints (nil for none) and two combinations to win.
  def wager_scene(wager, coins)
    s = VpSpecScene.new
    screen = VpSpecScreen.new([])
    screen.wager = wager
    s.instance_variable_set(:@screen, screen)
    s.player_coins = coins
    s.instance_variable_set(:@combination_array, [VpSpecCombination.new("Pareja", "Dos cartas iguales", 2),
                                                  VpSpecCombination.new("Escalera", "", 10)])
    s
  end

  # Double or nothing: the reference card (a ten of spades) and four face-down cards, the cursor on index.
  def pick_scene(index)
    s = VpSpecScene.new
    s.instance_variable_set(:@hand, [VpSpecCard.new(10, 4)] + Array.new(4) { VpSpecCard.new(2, 1) })
    s.instance_variable_set(:@cursor, VpSpecCursor.new(index))
    s
  end

  # The scene (a new one, or the one given) with its message window showing text and a pair as the combination
  # found on its screen.
  def message_scene(text, s = VpSpecScene.new)
    screen = PokeAccess.ivar(s, :@screen) || VpSpecScreen.new([])
    screen.combination_found = VpSpecFound.new(VpSpecCombination.new("Pareja", "", 2))
    s.instance_variable_set(:@screen, screen)
    s.instance_variable_set(:@sprites, { "message_window" => VpSpecWindow.new(text) })
    s
  end

  # The plugin's own scene with the cursor on the first slot, as the block furnishes it.
  def loop_scene
    s = VpSpecLoopScene.new
    s.instance_variable_set(:@cursor, VpSpecCursor.new(0))
    yield s if block_given?
    s
  end

  # Runs the block with the game's VideoPoker::FLASH_CARDS set to value (:unset for none), the module as it was put
  # back afterwards.
  def with_flash_cards(value)
    made = !Object.const_defined?(:VideoPoker)
    Object.const_set(:VideoPoker, Module.new) if made
    had = VideoPoker.const_defined?(:FLASH_CARDS, false) ? [VideoPoker.const_get(:FLASH_CARDS)] : nil
    VideoPoker.send(:remove_const, :FLASH_CARDS) if had
    VideoPoker.const_set(:FLASH_CARDS, value) unless value == :unset
    yield
  ensure
    if made
      Object.send(:remove_const, :VideoPoker)
    else
      VideoPoker.send(:remove_const, :FLASH_CARDS) if VideoPoker.const_defined?(:FLASH_CARDS, false)
      VideoPoker.const_set(:FLASH_CARDS, had[0]) if had
    end
  end
end
