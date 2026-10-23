require "rbconfig"
require "json"

# Uranium's own screens say what they paint: berry shop, key bindings, gym counter, scoreboard, letter, Hall of Fame,
# punch bag, Pokedex, options, PokePod, rules, trainer card, summary marks and relearner, each test run as Uranium.

# Stand-ins shaped as Uranium's classes, defined only in Uranium's process and before its profile binds to them.
if defined?(URANIUM_SCREENS_PROCESS)
  # A window or sprite holding painted text.
  class UraWin
    attr_accessor :text, :visible, :x
    def initialize(t = ""); @text = t; @visible = true; @x = 0; end
  end

  DREAMMAPS = [70, 71]

  # The berry shop: rows of a stock with their quantities and prices in berries, the player's berries in a corner.
  class UraMartAdapter
    NAMES = { 30 => "Antidote" }
    def getDisplayName(i); NAMES[i]; end
  end
  class Window_PokemonBerryMart < Window_DrawableCommand
    def initialize(stock, adapter)
      super()
      @quantity = stock[1]; @prices = stock[2]; @pokemon = stock[3]; @stock = stock[0]; @adapter = adapter
    end
  end
  class PokemonBerryMartScene
    attr_accessor :berries
    def update; @sprites["itemwindow"].update; end
    def pbStartBuyScene(stock)
      @berries ||= [700, 701]
      @sprites = { "itemwindow" => Window_PokemonBerryMart.new(stock, UraMartAdapter.new), "helpwindow" => UraWin.new }
      pbRefresh
    end
    def pbRefresh; drawCurrentBerries; end
    def drawCurrentBerries
      pbDrawTextPositions(nil, (0...@berries.length).map { |i| ["x#{($PokemonBag.pbQuantity(@berries[i]) rescue 0)}", 50 + i * 86, 8] })
    end
    def pbDisplay(msg, brief = false); @sprites["helpwindow"].text = msg; pbRefresh; end
    def pbDisplayPaused(msg); @sprites["helpwindow"].text = msg; pbRefresh; end
    def pbConfirm(msg); @sprites["helpwindow"].text = msg; true; end
  end

  # The key binding screen and the wait for a new key.
  module KeyBindings
    def self.detectInput; [0, 0x5A]; end
  end
  class UraBindOption
    attr_reader :name, :required
    attr_accessor :keyboard
    def initialize(name, required, keyboard, text); @name = name; @required = required; @keyboard = keyboard; @text = text; end
    def text; @keyboard.empty? ? "None" : @text; end
  end
  class Window_ControlBinding < Window_DrawableCommand
    def initialize(options); super(); @options = options; end
    def update; super; end
  end
  class ControlBindingScene
    def pbStartScene(options)
      @sprites = { "title" => UraWin.new("CONTROLS"), "textbox" => UraWin.new("Press a new key."),
                   "option" => Window_ControlBinding.new(options) }
      @sprites["option"].active = false
    end
    def pbAdd; KeyBindings.detectInput; end
    def pbEndScene; @sprites = {}; end
  end

  # The eighth gym's tile counter, painted on its overlay; its update answers what it did.
  class UraOverlay
    def initialize; @gone = false; end
    def dispose; @gone = true; end
    def disposed?; @gone; end
  end
  class GymWindow
    def initialize(tiles)
      @tiles = tiles
      @currentTileCount = $game_variables[1]
      @questProgress = $game_variables[121]
      @overlay = UraOverlay.new
      paint
    end
    def dispose; @overlay.dispose; end
    def update
      return :gone if @overlay.disposed?
      if $game_variables[121] != @questProgress
        @overlay.dispose
        return :solved
      end
      return :unchanged if $game_variables[1] == @currentTileCount
      @currentTileCount = $game_variables[1]
      paint
      :painted
    end
    def paint
      pbDrawTextPositions(nil, [["White Tiles: " + ("%02d" % $game_variables[1]), 512, 0, 1],
                                ["Black Tiles: " + ("%02d" % (@tiles - $game_variables[1])), 512, 30, 1]])
    end
  end

  # The championship's scoreboard, the Nuzlocke game over and the post-game letter.
  class ScoreWindow
    def initialize(x, y, trainer1, trainer2, name1, name2)
      pbDrawTextPositions(nil, [[name1, 6, 2, 0], [name2, 112, 52, 0]])
    end
  end
  class Scene_Gameover; def main; :over; end; end
  def pbDisplayLetter(message, sender); :shown; end

  # The Black/White Hall of Fame: the entry's slides and closing card, and the PC viewer's records and cards.
  class HallOfFameScene
    attr_accessor :hallEntry, :hallIndex
    def moveSprite(i); i; end
    def createTrainerBattler
      pbDrawTextPositions(nil, [["League Champion! Congratulations!", 256, 32, 2], ["Vitor", 16, 320, 0],
                                ["ID No. 12345", 256, 320, 2], ["12:34", 442, 320, 2]])
    end
    def writeNormalDataPC
      pbDrawTextPositions(nil, [["HALL OF FAME No.", 16, 0, 0], [format("%03d", @hallIndex + 1), 192, 0, 0],
                                ["#{@hallIndex + 1}/2", 118, 344, 2]])
    end
    def writePokemonDataPC(pk, n = -1); n; end
    def writeTrainerData; nil; end
    def pbEndScene; nil; end
  end

  # The punch bag: an arrow sweeping a bar whose centre scores most, five stars lit by a hit.
  class UraArrow
    attr_accessor :x, :visible
    def initialize(x = 0, visible = false); @x = x; @visible = visible; end
  end
  class PunchBagScene
    BARLEFTSIZE = 128
    attr_accessor :steps, :last
    def pbStartScene(pkmn, rounds)
      @sprites = { "scorebox" => UraWin.new, "arrow" => UraArrow.new(72, true) }
      5.times { |i| @sprites["star#{i}"] = UraArrow.new }
      @arrowXMiddle = 200; @score = 0; @shoots = 0; @rounds = rounds
      pbDrawText
    end
    def pbDrawText; @sprites["scorebox"].text = "Score: #{@score} \nHits: #{@shoots}/#{@rounds}"; end
    def pbMain
      (@steps || []).each { |x| @sprites["arrow"].x = x; Input.update }
      @score
    end
    def computeScore
      @shoots += 1
      @score += @last
      pbDrawText
      5.times { |i| @sprites["star#{i}"].visible = i < @last }
    end
  end

  # The Black/White Pokedex: its species list outside the command windows, its entry and registration pages, and
  # its search, whose rows paint a label beside each value and whose values open in a sublist.
  Object.send(:remove_const, :Window_Pokedex)
  class SpriteWindow_SelectableDex < SpriteWindow_Base
    def update; @index; end
  end
  class Window_DrawableCommandDex < SpriteWindow_SelectableDex
    def update; super; end
  end
  class Window_Pokedex < Window_DrawableCommandDex
    attr_accessor :commands
    def initialize(commands); super(); @commands = commands; end
  end
  class Window_ComplexCommandPokemon < Window_DrawableCommand
    def initialize(commands); super(commands); end
    def indexToCommand(index)
      curindex = 0
      i = 0
      while i < @commands.length
        return [i / 2, -1] if index == curindex
        curindex += 1
        return [i / 2, index - curindex] if index - curindex < @commands[i + 1].length
        curindex += @commands[i + 1].length
        i += 2
      end
      [-1, -1]
    end
    def getText(array, index)
      cmd = indexToCommand(index)
      return "" if cmd[0] == -1
      return array[cmd[0] * 2] if cmd[1] < 0
      array[cmd[0] * 2 + 1][cmd[1]]
    end
  end
  class Window_CommandPokemon < Window_DrawableCommand; end
  class Window_CommandPokemonWhiteArrow < Window_CommandPokemon
    attr_accessor :lastsel
  end
  class PokemonPokedexScene
    attr_accessor :aux_moves, :search_done, :registration
    def pbDexSetup
      @sprites["pokedex"] = Window_Pokedex.new([[1, "Bulbasaur", 7, 69, 1, false], [4, "Charmander", 6, 85, 4, false]])
      @sprites["searchlist"] = Window_ComplexCommandPokemon.new(["Search", ["--", "-", "Fire", "-", "Number", "START"]])
      @sprites["auxlist"] = Window_CommandPokemonWhiteArrow.new([])
      @sprites["sresult"] = UraWin.new
    end
    def pbChangeToDexEntry(species)
      drawTextEx(nil, 40, 230, 428, 3, "A strange seed was planted on its back at birth.")
      pbDrawTextPositions(nil, [["INFO", 34, 8, 0], ["001 ", 272, 24, 0], [PBSpecies.getName(species), 394, 24, 2],
                                ["HT", 288, 150, 0], ["WT", 288, 182, 0], ["Seed Pokémon", 370, 58, 2],
                                ["0.7 m", 480, 150, 1], ["6.9 kg", 478, 182, 1]])
    end
    def pbStartDexEntryScene(species)
      if @registration
        pbDrawTextPositions(nil, @registration)
      else
        drawTextEx(nil, 40, 278, 428, 3, "It can go for days without eating a single morsel.")
        pbDrawTextPositions(nil, [["Pokédex registration completed.", 34, 8, 0], ["004 ", 272, 72, 0],
                                  [PBSpecies.getName(species), 394, 72, 2], ["HT", 288, 198, 0], ["WT", 288, 230, 0],
                                  ["Lizard Pokémon", 370, 106, 2], ["0.6 m", 480, 198, 1], ["8.5 kg", 478, 230, 1]])
      end
      :registered
    end
    def pbDexEntry(index); :entry; end
    def pbRefreshDexSearch(params); end
    def pbDexSearchCommands(commands, selitem, helptexts)
      aux = @sprites["auxlist"]
      aux.commands = commands
      aux.index = selitem
      aux.lastsel = selitem
      (@aux_moves || []).each { |i| aux.index = i; aux.update }
      aux.index
    end
    def pbDexSearch
      @searchResults = @search_done
      @sprites["sresult"].text = @search_done ? "RESULTS<r>12" : ""
      nil
    end
  end

  # The options scene, which keeps each row's help in its own list.
  class PokemonOptionScene
    def pbStartScene(inloadscreen = false)
      @HELPTEXT = ["You can set the game's music volume.", "Set how often the game will autosave in minutes."]
      @sprites = { "option" => UraWin.new }
      @sprites["option"].instance_variable_set(:@index, 0)
      def (@sprites["option"]).index; @index; end
    end
    def pbPick(i); @sprites["option"].instance_variable_set(:@index, i); pbUpdate; end
  end

  # The PokePod, describing the focused option in a box beside its pictures, as its loop moves.
  class Scene_Pokegear
    attr_accessor :picks
    def main
      @info = UraWin.new
      (@picks || [0]).each { |i| @index = i; update }
      :closed
    end
    def update; update_info; end
    def update_info
      @info.text = ["A Radio\r\nUsed to listen to Music.", "Closes the PokéPod and returns to the game."][@index.to_i]
    end
  end

  # The custom-rules checklist, whose exit row's help depends on the scene's mode.
  class CheckboxOption
    attr_reader :name, :helptext
    def initialize(name, helptext); @name = name; @helptext = helptext; end
    def enabled?; true; end
    def unlocked?; true; end
  end
  class Window_PokemonNuzOption < Window_DrawableCommand
    def initialize(options, exitmessage); super(); @options = options; @exitmessage = exitmessage; @optvalues = [false]; end
  end
  class PokemonRulesetScene
    def initialize(mode = 0); @mode = mode; end
    def pbStartScene
      @sprites = { "title" => UraWin.new("Custom Game Settings"),
                   "option" => Window_PokemonNuzOption.new([CheckboxOption.new("Nuzlocke", "Dead is dead.")],
                                                          @mode != 0 ? "Continue" : "Start Game") }
    end
  end

  # The older move relearner: a message window with its question, the move's detail painted by pbRefreshInfo.
  class MoveRelearnerScene
    attr_accessor :picks
    def pbStartScene(pokemon, moves)
      @pokemon = pokemon
      @moves = moves + [0]
      @sprites = { "list" => Window_DrawableCommand.new(moves.map { |m| "Move#{m}" } + ["CANCEL"]),
                   "msgwindow" => UraWin.new("Teach which move to #{pokemon.name}?") }
      pbRefreshInfo(@moves[0])
    end
    def pbRefreshInfo(move); move; end
    def pbUpdate; nil; end
    def pbConfirm(msg); @sprites["msgwindow"].text = msg; pbUpdate; false; end
    def pbChooseMove
      @sprites["msgwindow"].text = "Teach which move to #{@pokemon.name}?"
      pbUpdate
      (@picks || []).each { |i| @sprites["list"].index = i; pbRefreshInfo(@moves[i]); pbUpdate }
      @moves[@sprites["list"].index]
    end
  end
end

class UraniumScreensTest < PokeAccessTest
  # The line Uranium's process prints its tests' outcomes on.
  MARK = "URANIUM_SCREENS_OUTCOMES"

  # The hooks and overrides of these screens that must bind; the optional ones never count as missing.
  HOOKED = %w[PokemonBerryMartScene#drawCurrentBerries PokemonBerryMartScene#pbDisplay PokemonBerryMartScene#pbDisplayPaused
              PokemonBerryMartScene#pbConfirm Window_ControlBinding#update ControlBindingScene#pbStartScene
              ControlBindingScene#pbEndScene GymWindow#initialize GymWindow#update ScoreWindow#initialize
              Scene_Gameover#main Window_DrawableCommandDex#update PokemonPokedexScene#pbChangeToDexEntry
              PokemonPokedexScene#pbStartDexEntryScene PokemonPokedexScene#pbDexEntry PokemonPokedexScene#pbDexSearch
              PokemonPokedexScene#pbDexSearchCommands Window_ComplexCommandPokemon#update Scene_Pokegear#update
              Scene_Pokegear#main PokemonRulesetScene#pbStartScene PokemonTrainerCardScene#pbDrawTrainerCardFront
              PokemonSummaryScene#drawPageTwo MoveRelearnerScene#pbStartScene PokeAccess::DexEntry#gen6_info
              PokeAccess::DexSearch#list PokeAccess::OptionHelp#read PokeAccess::Summary#header_icons
              PokeAccess::Party#status_slot PokeAccess::Summary#painted_memo PokeAccess::SummaryGen6#stats_extras]

  # The berry shop's stock: ids, quantities, prices as count and berry pairs, and which ids are Pokemon.
  STOCK = [[30, 77], [6, 1], [[2, 700], [1, 700, 2, 701]], [false, true]]

  # The berries the player holds, by item id.
  BAG = { 700 => 5, 701 => 3 }

  # The relearner's two moves as the game's move data has them: name, type name, category key and power.
  LEARN_MOVES = { 11 => ["Mov11", "Tipo0", :cat_status, 51], 22 => ["Mov22", "Tipo2", :cat_special, 62] }

  # Uranium's profile overrides core readers for good, which would reach every other test here: in this process a
  # test passes as its twin did in a process loaded as Uranium (run_as_uranium), and there it runs its body.
  def self.test(description, &body)
    return super if defined?(URANIUM_SCREENS_PROCESS)
    super(description) { assert_passed_as_uranium }
  end

  test "loads whole over Uranium's classes" do
    assert_equal [], Harness.errors
  end

  test "binds every hook and override of these screens" do
    assert_equal [], PokeAccess::Hooks.missing & HOOKED
  end

  test "wraps the letter and the wait for a new key" do
    assert_equal [], PokeAccess::Hooks.fn_absent & ["pbDisplayLetter", "KeyBindings.detectInput"]
  end

  test "the berry shop opens on the berries the player holds, queued" do
    with_mart do
      assert_equal [[held(5, 3), false]], SpeakCapture.log
    end
  end

  test "the berry shop says a berry the bag cannot count as none" do
    with_mart(nil) do
      assert_equal [[held(0, 0), false]], SpeakCapture.log
    end
  end

  test "the berry shop says no berries where it paints none" do
    with_mart(BAG, []) do
      assert_nothing_spoken
    end
  end

  test "the berry shop says the berries again only once their counts change" do
    with_mart do |mart, _win|
      SpeakCapture.clear
      mart.pbRefresh
      assert_nothing_spoken "the same counts"
      $PokemonBag = bag(700 => 3, 701 => 3)
      mart.pbRefresh
      assert_equal [[held(3, 3), false]], SpeakCapture.log
    end
  end

  test "a shop row says its quantity and item, then the berries it costs, the first one queued" do
    with_mart do |_mart, win|
      SpeakCapture.clear
      focus(win, 0)
      assert_equal [[antidote_row, false]], SpeakCapture.log
    end
  end

  test "a shop row keeps itself whole for the focused row's repeat" do
    with_mart do |_mart, win|
      focus(win, 0)
      assert_equal antidote_row, PokeAccess::Info.row_text
    end
  end

  test "a Pokemon row says its quantity and species, then each berry it costs, interrupting" do
    with_mart do |_mart, win|
      focus(win, 0)
      SpeakCapture.clear
      focus(win, 1)
      price = t(:ura_bmart_price, :list => "#{count(1, item(700))}, #{count(2, item(701))}")
      assert_equal [["#{count(1, PBSpecies.getName(77))}, #{price}", true]], SpeakCapture.log
    end
  end

  test "a Pokemon row keeps the species' Pokedex entry for the info key" do
    with_mart do |_mart, win|
      focus(win, 1)
      assert_equal "#{PBSpecies.getName(77)}. #{pbGetMessage(MessageTypes::Entries, 77)}", PokeAccess::Info.info_text
    end
  end

  test "a shop row with no price in berries says its quantity and item alone" do
    with_mart(BAG, [700, 701], [[30], [6], [nil], [false]]) do |_mart, win|
      focus(win, 0)
      assert_equal count(6, "Antidote"), SpeakCapture.last
    end
  end

  test "the shop's last row is the cancel command" do
    with_mart do |_mart, win|
      focus(win, 2)
      assert_equal t(:pc_cancel), SpeakCapture.last
    end
  end

  test "the shop's messages are said as its help window shows them, queued" do
    with_mart do |mart, _win|
      { :pbDisplay => ["You don't have enough berries.", "You don't have enough berries."],
        :pbDisplayPaused => ["Here you are!\r\nThank you!", "Here you are! Thank you!"],
        :pbConfirm => ["Certainly.  You want 6 Antidote(s)?", "Certainly. You want 6 Antidote(s)?"] }.each do |meth, (shown, said)|
        SpeakCapture.clear
        mart.send(meth, shown)
        assert_equal [[said, false]], SpeakCapture.log, "#{meth}"
      end
    end
  end

  test "a purchase's message is said before the berries its wait repaints, both queued" do
    with_mart do |mart, _win|
      $PokemonBag = bag(700 => 3, 701 => 3)
      SpeakCapture.clear
      mart.pbDisplayPaused("Here you are!\r\nThank you!")
      assert_equal [["Here you are! Thank you!", false], [held(3, 3), false]], SpeakCapture.log
    end
  end

  test "the binding screen opens on its title, queued" do
    with_bindings(bind_options) do
      assert_equal [["CONTROLS", false]], SpeakCapture.log
    end
  end

  test "a binding row says the action and its keys, None where it has none, the first one queued" do
    with_bindings(bind_options) do |_scene, list|
      SpeakCapture.clear
      focus(list, 0)
      focus(list, 1)
      assert_equal [["Action: C, Enter, Space", false], ["Run: None", true]], SpeakCapture.log
    end
  end

  test "an unbound action the screen requires is marked as needing a key" do
    with_bindings(bind_options) do |_scene, list|
      focus(list, 2)
      assert_equal "Cancel: None, #{t(:ura_ctrl_required)}", SpeakCapture.last
    end
  end

  test "the binding rows end with Restore Defaults and Save" do
    with_bindings(bind_options) do |_scene, list|
      assert_equal ["Restore Defaults", "Save"], [3, 4].map { |i| focus(list, i); SpeakCapture.last }
    end
  end

  test "a binding row whose keys change under the cursor is said again, interrupting" do
    opts = bind_options
    with_bindings(opts) do |_scene, list|
      focus(list, 0)
      SpeakCapture.clear
      opts[0].keyboard = []
      list.update
      assert_equal [["Action: None, #{t(:ura_ctrl_required)}", true]], SpeakCapture.log
    end
  end

  test "the binding list says nothing while it does not have the focus or a row" do
    with_bindings(bind_options) do |_scene, list|
      SpeakCapture.clear
      list.active = false
      focus(list, 1)
      list.active = true
      focus(list, -1)
      assert_nothing_spoken
    end
  end

  test "the binding screen says its prompt while a new key is awaited" do
    with_bindings(bind_options) do |scene, _list|
      SpeakCapture.clear
      scene.pbAdd
      assert_equal [["Press a new key.", true]], SpeakCapture.log
    end
  end

  test "the wait for a key says nothing once the binding screen is gone" do
    scene = nil
    with_bindings(bind_options) { |s, _l| scene = s }
    SpeakCapture.clear
    scene.pbAdd
    assert_nothing_spoken
  end

  test "the gym counter says both counts and the goal on entering a room, queued" do
    $game_variables[1] = 13
    with_gym(20) do
      assert_equal [["White Tiles: 13. Black Tiles: 7. #{t(:ura_gym8_goal, :n => 10)}", false]], SpeakCapture.log
    end
  end

  test "the gym counter says its counts without their padding zeros" do
    { 0 => "White Tiles: 0. Black Tiles: 20", 7 => "White Tiles: 7. Black Tiles: 13",
      10 => "White Tiles: 10. Black Tiles: 10" }.each do |white, said|
      $game_variables[1] = white
      SpeakCapture.clear
      with_gym(20) { assert_equal "#{said}. #{t(:ura_gym8_goal, :n => 10)}", SpeakCapture.last, "#{white} white" }
    end
  end

  test "the gym counter says each change of the counts, interrupting, without the goal" do
    $game_variables[1] = 13
    with_gym(20) do |gym|
      $game_variables[1] = 12
      SpeakCapture.clear
      gym.update
      assert_equal [["White Tiles: 12. Black Tiles: 8", true]], SpeakCapture.log
    end
  end

  test "the gym counter says nothing on an update that changes nothing" do
    $game_variables[1] = 13
    with_gym(20) do |gym|
      SpeakCapture.clear
      gym.update
      assert_nothing_spoken
    end
  end

  test "the gym counter hands back what the game's own methods answer" do
    $game_variables[1] = 13
    with_gym(20) do |gym|
      answers = [gym.update]
      $game_variables[1] = 12
      answers.push(gym.update)
      $game_variables[121] = 5
      answers.push(gym.update)
      assert_equal [:unchanged, :painted, :solved], answers
    end
  end

  test "the info key says the gym's counts and goal while the counter shows" do
    $game_variables[1] = 13
    with_gym(20) do |gym|
      $game_variables[1] = 12
      gym.update
      gym.update
      PokeAccess::Locator.refresh_info
      assert_equal "White Tiles: 12. Black Tiles: 8. #{t(:ura_gym8_goal, :n => 10)}", PokeAccess::Info.info_text
    end
  end

  test "the info key lets the gym counter go once its room is solved" do
    with_gym(20) do |gym|
      $game_variables[121] = 5
      gym.update
      PokeAccess::Locator.refresh_info
      assert_equal PokeAccess::Info.trainer_info, PokeAccess::Info.info_text
    end
  end

  test "the info key lets the gym counter go once the map is left" do
    with_gym(20) { |gym| gym.dispose }
    PokeAccess::Locator.refresh_info
    assert_equal PokeAccess::Info.trainer_info, PokeAccess::Info.info_text
  end

  test "letting the gym counter go leaves another screen's info line alone" do
    with_gym(20) do
      PokeAccess::Info.set_info(:text, "Bag")
    end
    assert_equal "Bag", PokeAccess::Info.info_text
  end

  test "a scoreboard says one name against the other, queued" do
    ScoreWindow.new(3, 4, 0, 0, "Vitor", "Kellyn")
    assert_equal [[t(:ura_score_vs, :a => "Vitor", :b => "Kellyn"), false]], SpeakCapture.log
  end

  test "the stadium's second scoreboard with the same names is not said again" do
    ScoreWindow.new(3, 4, 0, 0, "Lucas", "Dawn")
    SpeakCapture.clear
    ScoreWindow.new(3, 4, 0, 0, "Lucas", "Dawn")
    assert_nothing_spoken
  end

  test "the same scoreboard on another map is said again" do
    ScoreWindow.new(3, 4, 0, 0, "Brendan", "May")
    $game_map.map_id = 2
    SpeakCapture.clear
    ScoreWindow.new(3, 4, 0, 0, "Brendan", "May")
    assert_equal [[t(:ura_score_vs, :a => "Brendan", :b => "May"), false]], SpeakCapture.log
  end

  test "a scoreboard that paints one name says nothing" do
    ScoreWindow.new(3, 4, 0, 0, "Hilbert", "")
    assert_nothing_spoken
  end

  test "the Nuzlocke game over says its name and the key that goes on, queued" do
    Scene_Gameover.new.main
    assert_equal [["#{t(:ura_gameover)}. #{t(:title_press, :key => t(:key_enter))}", false]], SpeakCapture.log
  end

  test "without key hints the game over says its name alone" do
    PokeAccess::Config.verbosity = :brief
    Scene_Gameover.new.main
    assert_equal [[t(:ura_gameover), false]], SpeakCapture.log
  end

  test "a letter is said with the player's name in place and then its sender, interrupting" do
    pbDisplayLetter("Honored \\PN,\nThere is a stirring in the wind.", "Hinata & Kaito")
    letter = "Honored #{$Trainer.name}, There is a stirring in the wind. #{t(:mail_from, :name => 'Hinata & Kaito')}"
    assert_equal [[letter, true]], SpeakCapture.log
  end

  test "a letter is kept for the repeat key" do
    pbDisplayLetter("Dear \\PN,\nThe tower awaits.", "Professor Bamboo")
    assert_equal "Dear #{$Trainer.name}, The tower awaits. #{t(:mail_from, :name => 'Professor Bamboo')}",
                 PokeAccess.last_dialogue
  end

  test "a letter with no sender is said alone" do
    pbDisplayLetter("The wind has changed.", " ")
    assert_equal [["The wind has changed.", true]], SpeakCapture.log
  end

  test "an empty letter says nothing" do
    pbDisplayLetter("", "")
    assert_nothing_spoken
  end

  test "the hall of fame says each entrant once as it slides in, queued" do
    hof = hall_of_fame
    [0, 0, 1].each { |i| hof.moveSprite(i) }
    assert_equal [[t(:pc_slot, :name => "Orchynx", :level => 50), false], [t(:pc_slot, :name => "Nupin", :level => 48), false]],
                 SpeakCapture.log
  end

  test "the hall of fame's trainer slide says nothing of its own" do
    hall_of_fame.moveSprite(-1)
    assert_nothing_spoken
  end

  test "the hall of fame's closing card is said once as the trainer's data shows, with the key that ends it" do
    hof = hall_of_fame
    hof.createTrainerBattler
    hof.writeTrainerData
    hof.writeTrainerData
    card = "League Champion! Congratulations!, Vitor, ID No. 12345, 12:34. #{t(:hofbw_card_key)}"
    assert_equal [[card, false]], SpeakCapture.log
  end

  test "without key hints the closing card is said without its key" do
    PokeAccess::Config.verbosity = :brief
    hof = hall_of_fame
    hof.createTrainerBattler
    hof.writeTrainerData
    assert_equal [["League Champion! Congratulations!, Vitor, ID No. 12345, 12:34", false]], SpeakCapture.log
  end

  test "the PC viewer's first record says its number, place and team with the keys, queued" do
    hall_of_fame(0).writeNormalDataPC
    record = "HALL OF FAME No. 001. 1/2. #{t(:hofbw_team, :list => 'Orchynx, Nupin')}. #{t(:hofbw_pc_keys)}"
    assert_equal [[record, false]], SpeakCapture.log
  end

  test "the PC viewer's next record is said interrupting, without the keys" do
    pc = hall_of_fame(0)
    pc.writeNormalDataPC
    pc.hallIndex = 1
    pc.hallEntry = [pc.hallEntry[1]]
    SpeakCapture.clear
    pc.writeNormalDataPC
    assert_equal [["HALL OF FAME No. 002. 2/2. #{t(:hofbw_team, :list => 'Nupin')}", true]], SpeakCapture.log
  end

  test "the PC viewer says the card of the entrant it shows, interrupting" do
    pk = Poke.build(:name => "Orchynx", :species => 1, :level => 50, :gender => 0)
    hall_of_fame(0).writePokemonDataPC(pk)
    card = ["#{PBSpecies.getName(1)} \u2642", t(:hofbw_level, :n => 50), t(:hof_nickname, :name => "Orchynx")].join(", ")
    assert_equal [[card, true]], SpeakCapture.log
  end

  test "the punch bag opens on its score and how the tick guides the hit, queued" do
    open_punch_bag
    hint = t(:pbag_hint, :key => t(:key_enter))
    assert_equal [["Score: 0. Hits: 0/10. #{hint}", false]], SpeakCapture.log
  end

  test "without key hints the punch bag opens on its score alone" do
    PokeAccess::Config.verbosity = :brief
    open_punch_bag
    assert_equal [["Score: 0. Hits: 0/10", false]], SpeakCapture.log
  end

  test "the punch bag ticks once per arrow step, its pitch highest at the bar's centre" do
    bag = open_punch_bag
    bag.steps = [72, 136, 200, 200, 264]
    assert_equal [80, 115, 150, 115], ticks { bag.pbMain }
  end

  test "the punch bag ticks only while its game runs" do
    bag = open_punch_bag
    bag.steps = [136]
    assert_equal [], ticks { Input.update }, "before the game"
    bag.pbMain
    arrow(bag).x = 200
    assert_equal [], ticks { Input.update }, "after it"
  end

  test "the punch bag does not tick while its arrow is hidden" do
    bag = open_punch_bag
    arrow(bag).visible = false
    bag.steps = [136, 200]
    assert_equal [], ticks { bag.pbMain }
  end

  test "a scored hit says its stars, then the score, interrupting" do
    bag = open_punch_bag
    bag.last = 4
    SpeakCapture.clear
    bag.computeScore
    assert_equal [["#{t(:pbag_stars, :n => 4)}. Score: 4. Hits: 1/10", true]], SpeakCapture.log
  end

  test "the Pokedex info page says the number beside the name, then each value by its label, its caption left out" do
    with_dex do |dex|
      dex.pbChangeToDexEntry(1)
      entry = ["001 #{PBSpecies.getName(1)}", t(:dex_caught), "Seed Pokémon", t(:pdx_type, :t => dex_types), "HT 0.7 m",
               "WT 6.9 kg", "A strange seed was planted on its back at birth."].join(", ")
      assert_equal [[entry, true]], SpeakCapture.log
    end
  end

  test "the Pokedex registration page says the new entry and the key that goes on, interrupting" do
    with_dex do |dex|
      dex.pbStartDexEntryScene(4)
      entry = ["004 #{PBSpecies.getName(4)}", t(:dex_caught), "Lizard Pokémon", t(:pdx_type, :t => dex_types), "HT 0.6 m",
               "WT 8.5 kg", "It can go for days without eating a single morsel."].join(", ")
      assert_equal [["#{entry} #{t(:title_press, :key => t(:key_enter))}", true]], SpeakCapture.log
    end
  end

  test "without key hints the registration page says the entry alone" do
    PokeAccess::Config.verbosity = :brief
    with_dex do |dex|
      dex.pbStartDexEntryScene(4)
      assert_equal [["004 #{PBSpecies.getName(4)}, #{t(:dex_caught)}", true]], SpeakCapture.log
    end
  end

  test "a registration page that paints only its caption says nothing" do
    with_dex do |dex|
      dex.registration = [["Pokédex registration completed.", 34, 8, 0]]
      dex.pbStartDexEntryScene(4)
      assert_nothing_spoken
    end
  end

  test "the registration page hands back what the scene answers" do
    with_dex do |dex|
      said = dex.pbStartDexEntryScene(4)
      dex.registration = [["Pokédex registration completed.", 34, 8, 0]]
      assert_equal [:registered, :registered], [said, dex.pbStartDexEntryScene(4)]
    end
  end

  test "an entry page's rows painted without a place follow its lines" do
    pairs = [["INFO", :positions, 34, 8], ["WT", :positions, 288, 182], ["6.9 kg", :positions, 478, 182], ["Loose", :dtex, nil, nil]]
    assert_equal [["WT 6.9 kg", :positions, 288, 182], ["Loose", :dtex, nil, nil]], PokeAccess::UraniumDex.entry_pairs(pairs)
  end

  test "the species list says each species moved to, the first one queued" do
    with_dex do |dex|
      list = dex_list(dex)
      list.update
      list.index = 1
      list.update
      list.update
      assert_equal [[dex_row(1, "Bulbasaur"), false], [dex_row(4, "Charmander"), true]], SpeakCapture.log
    end
  end

  test "the species list says nothing while it does not have the focus or a row" do
    with_dex do |dex|
      list = dex_list(dex)
      list.active = false
      list.update
      list.active = true
      list.index = -1
      list.update
      assert_nothing_spoken
    end
  end

  test "back from an entry the species list says its focus again, queued" do
    with_dex do |dex|
      list = dex_list(dex)
      list.update
      SpeakCapture.clear
      dex.pbDexEntry(0)
      list.update
      assert_equal [[dex_row(1, "Bulbasaur"), false]], SpeakCapture.log
    end
  end

  test "the search rows say their label and value, an empty filter as such, START alone" do
    with_dex do |dex|
      search = dex.instance_variable_get(:@sprites)["searchlist"]
      unset = t(:dxs_unset)
      [1, 2, 3, 5, 6].each { |i| focus(search, i) }
      assert_equal [["NAME: #{unset}", false], ["COLOR: #{unset}", true], ["TYPE 1: Fire", true], ["ORDER: Number", true],
                    ["START", true]], SpeakCapture.log
    end
  end

  test "a search row whose value changes under the cursor is said again" do
    with_dex do |dex|
      search = dex.instance_variable_get(:@sprites)["searchlist"]
      focus(search, 3)
      SpeakCapture.clear
      search.commands[1][2] = "Water"
      search.update
      assert_equal [["TYPE 1: Water", true]], SpeakCapture.log
    end
  end

  test "the search list says nothing while it does not have the focus or a row" do
    with_dex do |dex|
      search = dex.instance_variable_get(:@sprites)["searchlist"]
      search.active = false
      focus(search, 3)
      search.active = true
      focus(search, -1)
      assert_nothing_spoken
    end
  end

  test "the stock search's read of each repaint stays quiet" do
    with_dex do |dex|
      dex.pbRefreshDexSearch([0, -1, 0, -1, -1, 0, -1])
      assert_nothing_spoken
    end
  end

  test "a value list opens on its title and the value in use, then says its rows" do
    with_dex do |dex|
      dex.aux_moves = [1, 0]
      dex.pbDexSearchCommands(["-", "Normal", "Fire"], 2, "TYPE 1")
      assert_equal [["TYPE 1: Fire", false], ["Normal", false], [t(:dxs_unset), true]], SpeakCapture.log
    end
  end

  test "a value list opening on an empty filter says it as such" do
    with_dex do |dex|
      dex.pbDexSearchCommands(["-", "Normal"], 0, "TYPE 2")
      assert_equal [["TYPE 2: #{t(:dxs_unset)}", false]], SpeakCapture.log
    end
  end

  test "a value list marks the value in use" do
    with_dex do |dex|
      dex.aux_moves = [2]
      dex.pbDexSearchCommands(["-", "Normal", "Fire"], 2, "TYPE 1")
      assert_equal "Fire, #{t(:ura_dex_applied)}", SpeakCapture.last
    end
  end

  test "each value list says its first row again, even the row the last one ended on" do
    with_dex do |dex|
      dex.aux_moves = [1]
      dex.pbDexSearchCommands(["-", "Normal", "Fire"], 2, "TYPE 1")
      SpeakCapture.clear
      dex.pbDexSearchCommands(["-", "Normal", "Fire"], 2, "TYPE 1")
      assert_equal [["TYPE 1: Fire", false], ["Normal", false]], SpeakCapture.log
    end
  end

  test "after a search the results count is said, then the list's focus, queued" do
    with_dex do |dex|
      list = dex_list(dex)
      list.update
      dex.search_done = true
      SpeakCapture.clear
      dex.pbDexSearch
      list.update
      assert_equal [["RESULTS 12", false], [dex_row(1, "Bulbasaur"), false]], SpeakCapture.log
    end
  end

  test "after a search with no results on show only the list's focus is said" do
    with_dex do |dex|
      list = dex_list(dex)
      list.update
      SpeakCapture.clear
      dex.pbDexSearch
      list.update
      assert_equal [[dex_row(1, "Bulbasaur"), false]], SpeakCapture.log
    end
  end

  test "the options say each row's help from the scene's own list, once per row, queued" do
    opt = PokemonOptionScene.new
    opt.pbStartScene
    opt.pbUpdate
    opt.pbUpdate
    opt.pbPick(1)
    assert_equal [["You can set the game's music volume.", false], ["Set how often the game will autosave in minutes.", false]],
                 SpeakCapture.log
  end

  test "the options keep the focused row's help for the info key" do
    opt = PokemonOptionScene.new
    opt.pbStartScene
    opt.pbPick(1)
    assert_equal "Set how often the game will autosave in minutes.", PokeAccess::Info.info_text
  end

  test "below full verbosity the options keep a row's help for the info key without saying it" do
    PokeAccess::Config.verbosity = :medium
    opt = PokemonOptionScene.new
    opt.pbStartScene
    opt.pbUpdate
    assert_equal [[], "You can set the game's music volume."], [SpeakCapture.log, PokeAccess::Info.info_text]
  end

  test "an options row past the scene's help list says nothing" do
    opt = PokemonOptionScene.new
    opt.pbStartScene
    opt.pbPick(2)
    assert_nothing_spoken
  end

  test "the PokePod says each option's description once per change, its lines as sentences, queued" do
    pod = Scene_Pokegear.new
    pod.picks = [0, 0, 1]
    pod.main
    assert_equal [["A Radio. Used to listen to Music.", false], ["Closes the PokéPod and returns to the game.", false]],
                 SpeakCapture.log
  end

  test "the PokePod keeps the focused description for the info key" do
    pod = Scene_Pokegear.new
    pod.instance_variable_set(:@info, UraWin.new("A Radio\r\nUsed to listen to Music."))
    PokeAccess::UraniumPod.info(pod)
    assert_equal "A Radio. Used to listen to Music.", PokeAccess::Info.info_text
  end

  test "the PokePod says nothing before its box exists" do
    PokeAccess::UraniumPod.info(Scene_Pokegear.new)
    assert_equal [[], nil], [SpeakCapture.log, PokeAccess::Info.info_text]
  end

  test "the PokePod lets its description go from the info key on closing" do
    Scene_Pokegear.new.main
    assert_nil PokeAccess::Info.info_text
  end

  test "below full verbosity the PokePod keeps its description for the info key without saying it" do
    PokeAccess::Config.verbosity = :medium
    pod = Scene_Pokegear.new
    pod.instance_variable_set(:@info, UraWin.new("A Radio\r\nUsed to listen to Music."))
    PokeAccess::UraniumPod.info(pod)
    assert_equal [[], "A Radio. Used to listen to Music."], [SpeakCapture.log, PokeAccess::Info.info_text]
  end

  test "the rules checklist's exit row says its command with the help the scene writes for its mode" do
    { 1 => "Continue. Permanently disable the options you unchecked.", 0 => "Start Game. Begin your game." }.each do |mode, said|
      rules = PokemonRulesetScene.new(mode)
      rules.pbStartScene
      win = rules.instance_variable_get(:@sprites)["option"]
      win.index = 1
      assert_equal said, PokeAccess::Menus.focused_text(win), "mode #{mode}"
    end
  end

  test "the trainer card says the rules its icon shows ahead of the card, and the card alone without them" do
    card = "Nombre Rojo N° ID 01234. Dinero $3000. #{t(:tr_badges, :n => 1)}"
    { [true, true] => "#{t(:ura_nuzlocke)}, #{t(:ura_randomizer)}. #{card}",
      [true, false] => "#{t(:ura_nuzlocke)}. #{card}",
      [false, true] => "#{t(:ura_randomizer)}. #{card}",
      [false, false] => card }.each do |(nuzlocke, randomizer), said|
      assert_equal [[said, false]], card_read(nuzlocke, randomizer), "nuzlocke #{nuzlocke}, randomizer #{randomizer}"
    end
  end

  test "under the Nuzlocke rule a fainted Pokemon is marked dead in place of fainted" do
    fallen = Poke.build(:name => "Nupin", :hp => 0)
    with_rules(true) do
      assert_equal t(:ura_dead), PokeAccess::Summary.header_icons(fallen), "on the summary"
      assert_equal t(:ura_dead), PokeAccess::Party.status_slot(fallen), "on the party panel"
    end
  end

  test "under the Nuzlocke rule a fainted Pokemon keeps its other marks" do
    fallen = Poke.build(:name => "Nupin", :hp => 0, :shiny => true)
    with_rules(true) do
      assert_equal "#{t(:ura_dead)}, #{t(:pk_shiny)}", PokeAccess::Summary.header_icons(fallen)
    end
  end

  test "without the Nuzlocke rule a fainted Pokemon stays fainted" do
    fallen = Poke.build(:name => "Nupin", :hp => 0)
    { false => "the rule off", nil => "a save with no such rule" }.each do |rule, why|
      with_rules(rule) do
        assert_equal [t(:pk_fainted), t(:pk_fainted)],
                     [PokeAccess::Summary.header_icons(fallen), PokeAccess::Party.status_slot(fallen)], why
      end
    end
  end

  test "under the Nuzlocke rule a Pokemon with HP left is not dead" do
    standing = Poke.build(:name => "Nupin", :hp => 1)
    unread = Poke.build(:name => "Orchynx")
    def unread.hp; raise "no HP"; end
    with_rules(true) do
      assert_nil PokeAccess::Party.status_slot(standing), "one HP left"
      assert_nil PokeAccess::Party.status_slot(unread), "an HP the game cannot tell"
    end
  end

  test "a corrupted Nuclear Pokemon carries the RAD mark, last" do
    rad = nuclear("Orchynx", true, false)
    fallen = nuclear("Nupin", true, false, 0)
    with_rules(true) do
      assert_equal t(:ura_rad), PokeAccess::Summary.header_icons(rad)
      assert_equal "#{t(:ura_dead)}, #{t(:ura_rad)}", PokeAccess::Summary.header_icons(fallen)
    end
  end

  test "a cured Nuclear Pokemon or another one carries no RAD mark" do
    { "cured" => nuclear("Geigeroach", true, true), "not Nuclear" => nuclear("Orchynx", false, false),
      "with no such marks" => Poke.build(:name => "Pika") }.each do |what, pk|
      assert_equal "", PokeAccess::Summary.header_icons(pk), what
    end
  end

  test "the memo page adds the date and the place it draws, a dream map marked as such" do
    page = memo_page(memo_mon(70, ""))
    place = t(:ura_memo_place, :place => "#{pbGetMapNameFromId(70)}, #{t(:ura_memo_dream)}")
    assert_equal "#{t(:sm_memo)}. Timid nature. Met at Lv. 5. #{t(:ura_memo_date, :date => '25/9/2026')}. #{place}", page
  end

  test "the memo page names the place the Pokemon's own text gives, a map outside the dreams unmarked" do
    { [5, ""] => pbGetMapNameFromId(5), [70, "Faraway place"] => "Faraway place, #{t(:ura_memo_dream)}",
      [5, "A trade"] => "A trade" }.each do |(map, text), place|
      assert_equal "#{t(:sm_memo)}. Timid nature. Met at Lv. 5. #{t(:ura_memo_date, :date => '25/9/2026')}. " \
                   "#{t(:ura_memo_place, :place => place)}", memo_page(memo_mon(map, text)), "map #{map}, text #{text.inspect}"
    end
  end

  test "the memo page of a Pokemon with no date or place is the page as painted" do
    assert_equal "#{t(:sm_memo)}. Timid nature. Met at Lv. 5.", memo_page(Poke.build(:name => "Orchynx"))
  end

  test "the memo page's date and place go to that page only" do
    memo_page(memo_mon(70, ""))
    assert_equal "#{t(:sm_memo)}. Another memo.", PokeAccess::Summary.painted_memo(["Another memo."])
  end

  test "a memo page that paints nothing is composed as the stock page, without the date and place" do
    pk = memo_mon(70, "")
    PokemonSummaryScene.new(pk).drawPageTwo(pk)
    assert_equal [[stock_memo, false]], SpeakCapture.log
  end

  test "the stats page says each stat's IV and EV as it writes them, speed last" do
    pk = Poke.build(:iv => [31, 30, 29, 28, 27, 26], :ev => [10, 20, 30, 40, 50, 60])
    ivev = t(:sm_ivev, :hpi => 31, :hpe => 10, :ai => 30, :ae => 20, :di => 29, :de => 30, :sai => 27, :sae => 50,
                       :sdi => 26, :sde => 60, :si => 28, :se => 40)
    assert_equal [ivev], PokeAccess::SummaryGen6.stats_extras(pk)
    PokemonSummaryScene.new(pk).drawPageThree(pk)
    assert_spoken_once(/#{Regexp.escape(ivev)}/)
  end

  test "the stats page adds nothing for a Pokemon whose IVs cannot be read" do
    pk = Poke.build(:iv => nil)
    assert_equal [], PokeAccess::SummaryGen6.stats_extras(pk)
  end

  test "the relearner opens on its question and the first move, queued" do
    relearner
    assert_equal [["Teach which move to Pika? #{learn_detail(11)}", false]], SpeakCapture.log
  end

  test "the relearner says each move moved to in its first choice loop, interrupting" do
    mr = relearner
    mr.picks = [1, 2]
    SpeakCapture.clear
    mr.pbChooseMove
    assert_equal [[learn_detail(22), true], ["CANCEL", true]], SpeakCapture.log
  end

  test "back from a declined question the relearner says it and the focused move again, queued" do
    mr = relearner
    mr.picks = [1]
    mr.pbChooseMove
    mr.picks = []
    SpeakCapture.clear
    mr.pbConfirm("Teach Mov22?")
    mr.pbChooseMove
    assert_equal [["Teach Mov22?", false], ["Teach which move to Pika? #{learn_detail(22)}", false]], SpeakCapture.log
  end

  # The tests' outcomes in Uranium's process, run once for this one: { test name => [code, message] }.
  def self.outcomes
    @outcomes ||= run_as_uranium
  end

  # What Uranium's process printed, for a test it left without an outcome.
  def self.uranium_output; @output.to_s; end

  # Runs every test in a gen-6 process that loads the mod as Uranium over the stand-ins, under this run's seed; the
  # outcomes it prints, or none when it printed none.
  def self.run_as_uranium
    support = File.join(Harness::ROOT, "test", "support")
    script = ["URANIUM_SCREENS_PROCESS = true",
              "if ENV['PA_COVERAGE'] then require 'coverage'; Coverage.setup(:lines => true, :branches => true, :eval => true); Coverage.resume; end",
              "require #{File.join(support, 'harness').inspect}",
              "%w[speak_capture reset poke_builder world_builder tile_world hpa_helpers route_helpers guide_helpers " \
              "sound_helpers replay game_functions arity_net].each { |f| require File.join(#{support.inspect}, f) }",
              "require 'minitest'",
              "require #{File.join(support, 'test_case').inspect}",
              "require #{File.expand_path(__FILE__).inspect}",
              "UraniumScreensTest.send(:run_here)"].join("\n")
    env = { "PA_ENGINE" => "gen6", "PA_URANIUM_SEED" => Minitest.seed.to_s }
    @output = IO.popen([env, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }.to_s.force_encoding("UTF-8")
    line = @output.scrub[/^#{MARK} (.*)$/, 1]
    line ? JSON.parse(line) : {}
  end

  # Uranium's process: loads the mod as Uranium, runs each test in the parent's order, failing one that let raw codes
  # reach speak or handed a one-parameter block several values, and prints the outcomes as one line.
  def self.run_here
    Harness.load_all("uranium")
    SpeakCapture.install
    SpeakCapture.clear_all
    Minitest.seed = ENV["PA_URANIUM_SEED"].to_i
    found = {}
    runnable_methods.each do |name|
      raw = SpeakCapture.raw_offenders.length
      arity = ArityNet.offenders
      result = new(name).run
      nets = SpeakCapture.raw_offenders[raw..-1].map { |_t, text| "raw control codes reached speak: #{text.inspect}" } +
             (ArityNet.offenders - arity).map { |o| "a one-parameter block was handed several values: #{o}" }
      code = result.result_code
      message = result.failures.map { |f| "#{f.location}: #{f.message}" }.join("\n")
      code, message = "F", nets.join("\n") if code == "." && !nets.empty?
      found[name] = [code, message.scrub]
    end
    write_coverage if ENV["PA_COVERAGE"]
    puts "\n#{MARK} #{JSON.generate(found)}"
  end

  # Writes this process's coverage of the mod beside the run's own, shaped as test/test_helper.rb writes it.
  def self.write_coverage
    root = Harness::ROOT.tr("\\", "/") + "/"
    out = {}
    Coverage.result.each do |path, cov|
      rel = path.tr("\\", "/").sub(root, "")
      next unless rel =~ %r{\A(core|games|plugins|loader)/}
      branches = {}
      (cov[:branches] || {}).each { |cond, targets| targets.each { |tg, n| branches["#{cond.inspect}|#{tg.inspect}"] = n } }
      out[rel] = { "lines" => cov[:lines], "branches" => branches }
    end
    File.write("#{ENV['PA_COVERAGE']}_uranium_screens.json", JSON.generate(out))
  end

  private_class_method :outcomes, :uranium_output, :run_as_uranium, :run_here, :write_coverage

  private

  # Passes as this test passed in Uranium's process, its failure or skip told here.
  def assert_passed_as_uranium
    code, message = self.class.send(:outcomes)[name]
    out = self.class.send(:uranium_output)
    flunk "Uranium's process gave no outcome for #{name}:\n#{out[-2000..-1] || out}" unless code
    skip message if code == "S"
    assert code == ".", message
  end

  # A spoken text of the mod's, in the language the tests pin.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # "n name", as the shop counts items and berries.
  def count(n, name)
    t(:ura_bmart_count, :n => n, :name => name)
  end

  # An item's name, as the game has it.
  def item(id)
    PBItems.getName(id)
  end

  # Moves a list's cursor to row i, as the game does: the index, then the window's update.
  def focus(win, i)
    win.index = i
    win.update
  end

  # A bag answering the given count per item id.
  def bag(counts)
    b = Object.new
    b.define_singleton_method(:pbQuantity) { |id| counts.fetch(id, 0) }
    b
  end

  # Runs the block over the berry shop opened on stock and the berries it paints, the player's bag holding counts
  # (nil: a bag that cannot count); yields the scene and its item window, and puts the bag back after.
  def with_mart(counts = BAG, berries = [700, 701], stock = STOCK)
    was = $PokemonBag
    $PokemonBag = counts ? bag(counts) : nil
    mart = PokemonBerryMartScene.new
    mart.berries = berries
    mart.pbStartBuyScene(stock)
    yield mart, mart.instance_variable_get(:@sprites)["itemwindow"]
  ensure
    $PokemonBag = was
  end

  # The shop's line for the player's two berries.
  def held(first, second)
    t(:ura_bmart_have, :list => "#{count(first, item(700))}, #{count(second, item(701))}")
  end

  # The stock's first row: six Antidotes for two of the first berry.
  def antidote_row
    "#{count(6, 'Antidote')}, #{t(:ura_bmart_price, :list => count(2, item(700)))}"
  end

  # Three actions: one bound and required, one unbound, one unbound and required.
  def bind_options
    [UraBindOption.new("Action", true, [0x43], "C, Enter, Space"), UraBindOption.new("Run", false, [], ""),
     UraBindOption.new("Cancel", true, [], "")]
  end

  # Runs the block over the binding screen opened on opts and its list (focused), closing the screen after.
  def with_bindings(opts)
    scene = ControlBindingScene.new
    scene.pbStartScene(opts)
    list = scene.instance_variable_get(:@sprites)["option"]
    list.active = true
    yield scene, list
  ensure
    scene.pbEndScene if scene
  end

  # Runs the block over the eighth gym's counter for a room of tiles, its overlay disposed after.
  def with_gym(tiles)
    gym = GymWindow.new(tiles)
    yield gym
  ensure
    gym.dispose if gym
  end

  # A Black/White Hall of Fame scene over two entrants, at a PC record when index is given.
  def hall_of_fame(index = nil)
    hof = HallOfFameScene.new
    hof.hallEntry = [Poke.build(:name => "Orchynx", :level => 50), Poke.build(:name => "Nupin", :level => 48)]
    hof.hallIndex = index
    hof
  end

  # The punch bag opened for ten hits.
  def open_punch_bag
    bag = PunchBagScene.new
    bag.pbStartScene(Poke.build(:name => "Orchynx"), 10)
    bag
  end

  # The punch bag's arrow sprite.
  def arrow(bag)
    bag.instance_variable_get(:@sprites)["arrow"]
  end

  # The pitches of the flat channel's sounds the block plays, the channel put back after.
  def ticks
    played = []
    original = Audio.method(:se_play)
    Audio.define_singleton_method(:se_play) { |*a| played.push(a[2]) }
    yield
    played
  ensure
    Audio.define_singleton_method(:se_play, original)
  end

  # Runs the block over a Pokedex scene set up, with every species seen and caught, the player put back after.
  def with_dex
    [:seen?, :owned?].each { |m| $Trainer.define_singleton_method(m) { |_sp| true } }
    dex = PokemonPokedexScene.new
    dex.pbDexSetup
    SpeakCapture.clear
    yield dex
  ensure
    [:seen?, :owned?].each { |m| $Trainer.singleton_class.send(:remove_method, m) if $Trainer.singleton_methods.include?(m) }
  end

  # The scene's species list, focused.
  def dex_list(dex)
    list = dex.instance_variable_get(:@sprites)["pokedex"]
    list.active = true
    list
  end

  # A caught species' list row: its number, its name and caught.
  def dex_row(num, name)
    "#{num}, #{name}, #{t(:dex_caught)}"
  end

  # The type names an entry page shows for species 1 and 4, which the game's dex data gives types 1 and 2.
  def dex_types
    "#{PBTypes.getName(1)} #{PBTypes.getName(2)}"
  end

  # Runs the block with the save's Nuzlocke and Randomizer rules as given; nil leaves the save without that setting.
  def with_rules(nuzlocke, randomizer = nil)
    g = $PokemonGlobal
    g.define_singleton_method(:nuzlocke) { nuzlocke } unless nuzlocke.nil?
    g.define_singleton_method(:randomizer) { randomizer } unless randomizer.nil?
    yield
  ensure
    [:nuzlocke, :randomizer].each { |m| g.singleton_class.send(:remove_method, m) if g.singleton_methods.include?(m) }
  end

  # What the trainer card with one badge says as it opens under the given rules, as [text, interrupt] pairs.
  def card_read(nuzlocke, randomizer)
    SpeakCapture.clear
    with_rules(nuzlocke, randomizer) { PokemonTrainerCardScene.new(1).pbStartScene }
    SpeakCapture.log
  end

  # A Pokemon that is Nuclear or not, cured or not, with hp left.
  def nuclear(name, nuclear, cured, hp = 40)
    pk = Poke.build(:name => name, :hp => hp)
    pk.define_singleton_method(:isNuclear?) { nuclear }
    pk.define_singleton_method(:nuclearFree) { cured }
    pk
  end

  # A Pokemon received on 25/9/2026 on map, its own place text as given.
  def memo_mon(map, text)
    pk = Poke.build(:name => "Orchynx")
    pk.define_singleton_method(:timeReceived) { Time.local(2026, 9, 25) }
    pk.define_singleton_method(:obtainText) { text }
    pk.define_singleton_method(:obtainMap) { map }
    pk
  end

  # What the memo page says as it draws pk with its painted memo.
  def memo_page(pk)
    scene = PokemonSummaryScene.new(pk)
    scene.instance_variable_set(:@memo_paint, "Timid nature.\nMet at Lv. 5.")
    SpeakCapture.clear
    scene.drawPageTwo(pk)
    SpeakCapture.last
  end

  # The stock memo page of a default-built Pokemon: its nature, then the characteristic of its HP IV of 31.
  def stock_memo
    "#{t(:sm_memo)}. #{t(:sm_nature, :n => PBNatures.getName(0))}. #{t(:sm_char_1)}."
  end

  # The relearner opened on Pika with moves 11 and 22.
  def relearner
    mr = MoveRelearnerScene.new
    mr.pbStartScene(Poke.build(:name => "Pika"), [11, 22])
    mr
  end

  # The relearner's detail of one of LEARN_MOVES at full verbosity: its name, type, category and power, then the
  # accuracy and PP the game's move data gives every move.
  def learn_detail(id)
    name, type, category, power = LEARN_MOVES.fetch(id)
    [name, t(:mv_type, :t => type), t(category), t(:mv_power, :p => power), t(:mv_acc, :a => 100),
     t(:mv_pp, :pp => 15, :tot => 15)].join(". ")
  end
end
