require "rbconfig"
require "tmpdir"

# Uranium's own screens and overlays, loaded with its profile and plugins in a process of their own over classes
# shaped as Uranium's: the berry shop, the key bindings, the eighth gym's counter, the scoreboard, the game over, the
# letter, the punch bag, the Black/White Hall of Fame, Pokedex and summary, the options' help, the PokePod, the rules
# checklist's exit row, the trainer card's rules and the older move relearner.
module UraniumScreensSpec
  # The Uranium-shaped classes, declared before the toolkit loads so its hooks find them.
  WORLD = <<-'RUBY'
    class UraWin
      attr_accessor :text, :visible, :x
      def initialize(t = ""); @text = t; @visible = true; @x = 0; end
    end
    $ura_se = []
    module Audio; def self.se_play(*a); $ura_se.push(a); end; end
    DREAMMAPS = [70, 71]

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
      def update; @sprites["itemwindow"].update; end
      def pbStartBuyScene(stock)
        @berries = [700, 701]
        @sprites = { "itemwindow" => Window_PokemonBerryMart.new(stock, UraMartAdapter.new), "helpwindow" => UraWin.new }
        pbRefresh
      end
      def pbRefresh; drawCurrentBerries; end
      def drawCurrentBerries
        pbDrawTextPositions(nil, (0...@berries.length).map { |i| ["x#{$PokemonBag.pbQuantity(@berries[i])}", 50 + i * 86, 8] })
      end
      def pbDisplay(msg, brief = false); @sprites["helpwindow"].text = msg; pbRefresh; end
      def pbDisplayPaused(msg); @sprites["helpwindow"].text = msg; pbRefresh; end
      def pbConfirm(msg); @sprites["helpwindow"].text = msg; true; end
    end

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
        pbDrawTextPositions(nil, [["White Tiles: " + ("%02d" % $game_variables[1]), 512, 0, 1],
                                  ["Black Tiles: " + ("%02d" % (@tiles - $game_variables[1])), 512, 30, 1]])
      end
      def dispose; @overlay.dispose; end
      def update
        return if @overlay.disposed?
        if $game_variables[121] != @questProgress
          @overlay.dispose
          return
        end
        return if $game_variables[1] == @currentTileCount
        @currentTileCount = $game_variables[1]
        pbDrawTextPositions(nil, [["White Tiles: " + ("%02d" % $game_variables[1]), 512, 0, 1],
                                  ["Black Tiles: " + ("%02d" % (@tiles - $game_variables[1])), 512, 30, 1]])
      end
    end
    class ScoreWindow
      def initialize(x, y, trainer1, trainer2, name1, name2)
        pbDrawTextPositions(nil, [[name1, 6, 2, 0], [name2, 112, 52, 0]])
      end
    end
    class Scene_Gameover; def main; :over; end; end
    def pbDisplayLetter(message, sender); :shown; end

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
      attr_accessor :aux_moves, :search_done
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
        drawTextEx(nil, 40, 278, 428, 3, "It can go for days without eating a single morsel.")
        pbDrawTextPositions(nil, [["Pokédex registration completed.", 34, 8, 0], ["004 ", 272, 72, 0],
                                  [PBSpecies.getName(species), 394, 72, 2], ["HT", 288, 198, 0], ["WT", 288, 230, 0],
                                  ["Lizard Pokémon", 370, 106, 2], ["0.6 m", 480, 198, 1], ["8.5 kg", 478, 230, 1]])
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

    class PokemonOptionScene
      def pbStartScene(inloadscreen = false)
        @HELPTEXT = ["You can set the game's music volume.", "Set how often the game will autosave in minutes."]
        @sprites = { "option" => UraWin.new }
        @sprites["option"].instance_variable_set(:@index, 0)
        def (@sprites["option"]).index; @index; end
      end
      def pbPick(i); @sprites["option"].instance_variable_set(:@index, i); pbUpdate; end
    end

    class Scene_Pokegear
      def main; @info = UraWin.new; update; :closed; end
      def pick(i); @index = i; update; end
      def update; update_info; end
      def update_info
        @info.text = ["A Radio\r\nUsed to listen to Music.", "Closes the PokéPod and returns to the game."][@index.to_i]
      end
    end

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
  RUBY

  # The checks, run after the load; each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    T = PokeAccess::I18n
    check "loads whole", ERRS.empty?, ERRS.first(3)
    mine = %w[PokemonBerryMartScene#drawCurrentBerries PokemonBerryMartScene#pbDisplay PokemonBerryMartScene#pbDisplayPaused
              PokemonBerryMartScene#pbConfirm Window_ControlBinding#update ControlBindingScene#pbStartScene
              ControlBindingScene#pbEndScene GymWindow#initialize GymWindow#update GymWindow#dispose ScoreWindow#initialize
              Scene_Gameover#main HallOfFameScene#createTrainerBattler HallOfFameScene#writeNormalDataPC
              PunchBagScene#pbStartScene PunchBagScene#pbMain PunchBagScene#computeScore
              PokemonPokedexScene#pbStartDexEntryScene PokemonPokedexScene#pbDexEntry PokemonPokedexScene#pbDexSearch
              PokemonPokedexScene#pbDexSearchCommands Window_ComplexCommandPokemon#update Scene_Pokegear#update
              Scene_Pokegear#main PokemonRulesetScene#pbStartScene PokemonTrainerCardScene#pbDrawTrainerCardFront
              PokemonSummaryScene#drawPageTwo MoveRelearnerScene#pbChooseMove MoveRelearnerScene#pbUpdate]
    check "every new hook binds", (PokeAccess::Hooks.missing & mine).empty?, PokeAccess::Hooks.missing & mine
    check "the letter and the key wait are wrapped",
          (PokeAccess::Hooks.fn_absent & ["pbDisplayLetter", "KeyBindings.detectInput"]).empty?, PokeAccess::Hooks.fn_absent

    bag_counts = { 700 => 5, 701 => 3 }
    $PokemonBag = Object.new
    def $PokemonBag.pbQuantity(i); $ura_bag[i].to_i; end
    $ura_bag = bag_counts
    stock = [[30, 77], [6, 1], [[2, 700], [1, 700, 1, 701]], [false, true]]
    acai = PBItems.getName(700)
    bacu = PBItems.getName(701)
    mart = PokemonBerryMartScene.new
    SpeakCapture.clear
    mart.pbStartBuyScene(stock)
    have = T.t(:ura_bmart_have, :list => [T.t(:ura_bmart_count, :n => 5, :name => acai),
                                          T.t(:ura_bmart_count, :n => 3, :name => bacu)].join(", "))
    check "the shop opens on the berries the player holds, queued", SpeakCapture.log == [[have, false]], SpeakCapture.log
    win = mart.instance_variable_get(:@sprites)["itemwindow"]
    SpeakCapture.clear
    rows = [0, 1].map { |i| win.index = i; mart.update; SpeakCapture.lines.last }
    antidote = [T.t(:ura_bmart_count, :n => 6, :name => "Antidote"),
                T.t(:ura_bmart_price, :list => T.t(:ura_bmart_count, :n => 2, :name => acai))].join(", ")
    firoke = [T.t(:ura_bmart_count, :n => 1, :name => PBSpecies.getName(77)),
              T.t(:ura_bmart_price, :list => [T.t(:ura_bmart_count, :n => 1, :name => acai),
                                               T.t(:ura_bmart_count, :n => 1, :name => bacu)].join(", "))].join(", ")
    check "each row: the quantity and the item or Pokemon, then its price in berries", rows == [antidote, firoke], rows
    win.index = 1
    mart.update
    check "a Pokemon row keeps its Pokedex entry for the info key",
          PokeAccess::Info.info_text == "#{PBSpecies.getName(77)}. msg77", PokeAccess::Info.info_text
    win.index = 2
    mart.update
    check "the last row is the cancel command", SpeakCapture.lines.last == T.t(:pc_cancel), SpeakCapture.lines
    SpeakCapture.clear
    mart.pbDisplayPaused("You don't have enough berries.")
    mart.pbConfirm("Certainly.  You want 6 Antidote(s)?")
    $ura_bag = { 700 => 3, 701 => 3 }
    mart.pbDisplayPaused("Here you are!\r\nThank you!")
    paid = T.t(:ura_bmart_have, :list => [T.t(:ura_bmart_count, :n => 3, :name => acai),
                                          T.t(:ura_bmart_count, :n => 3, :name => bacu)].join(", "))
    check "the shop's messages, and the berries again once they change", SpeakCapture.lines ==
          ["You don't have enough berries.", "Certainly. You want 6 Antidote(s)?", "Here you are! Thank you!", paid],
          SpeakCapture.lines

    opts = [UraBindOption.new("Action", true, [0x43], "C, Enter, Space"), UraBindOption.new("Run", false, [], ""),
            UraBindOption.new("Cancel", true, [], "")]
    cb = ControlBindingScene.new
    SpeakCapture.clear
    cb.pbStartScene(opts)
    list = cb.instance_variable_get(:@sprites)["option"]
    list.active = true
    rows = (0..4).map { |i| list.index = i; list.update; SpeakCapture.lines.last }
    req = T.t(:ura_ctrl_required)
    check "the binding screen: its title, then each action with its keys and the two commands",
          SpeakCapture.log.first == ["CONTROLS", false] &&
          rows == ["Action: C, Enter, Space", "Run: None", "Cancel: None, #{req}", "Restore Defaults", "Save"], [SpeakCapture.log, rows]
    list.index = 0
    list.update
    SpeakCapture.clear
    opts[0].keyboard = []
    list.update
    check "a row whose keys change under the cursor is said again", SpeakCapture.lines == ["Action: None, #{req}"],
          SpeakCapture.lines
    SpeakCapture.clear
    cb.pbAdd
    cb.pbEndScene
    cb.pbAdd
    check "the prompt while a key is awaited, and nothing once the screen is gone",
          SpeakCapture.log == [["Press a new key.", true]], SpeakCapture.log

    $game_variables[1] = 13
    SpeakCapture.clear
    gym = GymWindow.new(20)
    gym.update
    goal = T.t(:ura_gym8_goal, :n => 10)
    check "the gym counter on entering a room: both counts, unpadded, and the goal, queued",
          SpeakCapture.log == [["White Tiles: 13. Black Tiles: 7. #{goal}", false]], SpeakCapture.log
    $game_variables[1] = 12
    SpeakCapture.clear
    gym.update
    check "each change of the counts, interrupting", SpeakCapture.log == [["White Tiles: 12. Black Tiles: 8", true]] &&
          PokeAccess::Info.info_text == "White Tiles: 12. Black Tiles: 8. #{goal}", [SpeakCapture.log, PokeAccess::Info.info_text]
    $game_variables[121] = 5
    gym.update
    solved = PokeAccess::Info.info_text
    GymWindow.new(20).dispose
    left = PokeAccess::Info.info_text
    gym3 = GymWindow.new(20)
    PokeAccess::Info.set_info(:text, "Bag")
    gym3.dispose
    check "the counter leaves the info key with its overlay (a room solved, the map left), never another screen's line",
          [solved, left, PokeAccess::Info.info_text] == [nil, nil, "Bag"], [solved, left, PokeAccess::Info.info_text]

    SpeakCapture.clear
    ScoreWindow.new(3, 4, 0, 0, "Vitor", "Kellyn")
    check "the scoreboard, one name against the other", SpeakCapture.log == [[T.t(:ura_score_vs, :a => "Vitor", :b => "Kellyn"), false]],
          SpeakCapture.log
    SpeakCapture.clear
    ScoreWindow.new(3, 4, 0, 0, "Vitor", "Kellyn")
    check "and the stadium's second board with the same names is not said again", SpeakCapture.log.empty?, SpeakCapture.log
    SpeakCapture.clear
    Scene_Gameover.new.main
    check "the Nuzlocke game over and the key that goes on", SpeakCapture.log == [[PokeAccess::TitleScreen.prompt(:ura_gameover), false]],
          SpeakCapture.log
    SpeakCapture.clear
    pbDisplayLetter("Honored \\PN,\nThere is a stirring in the wind.", "Hinata & Kaito")
    letter = "Honored #{$Trainer.name}, There is a stirring in the wind. #{T.t(:mail_from, :name => 'Hinata & Kaito')}"
    check "the letter and its sender, kept for the repeat key",
          SpeakCapture.log == [[letter, true]] && PokeAccess.last_dialogue == letter, [SpeakCapture.log, PokeAccess.last_dialogue]

    ura_mons = [Poke.build(:name => "Orchynx", :level => 50), Poke.build(:name => "Nupin", :level => 48)]
    hof = HallOfFameScene.new
    hof.hallEntry = ura_mons
    SpeakCapture.clear
    hof.moveSprite(0)
    hof.moveSprite(0)
    hof.createTrainerBattler
    hof.moveSprite(-1)
    hof.moveSprite(-1)
    hof.writeTrainerData
    hof.writeTrainerData
    card = PokeAccess::Verbosity.with_hint("League Champion! Congratulations!, Vitor, ID No. 12345, 12:34",
                                           PokeAccess::KeyHints.localize(T.t(:hofbw_card_key)))
    check "the hall of fame: each entrant once, then the trainer's card with its key, queued",
          SpeakCapture.log == [[PokeAccess::HallOfFameBWGen6.member_line(ura_mons[0]), false], [card, false]], SpeakCapture.log
    pc = HallOfFameScene.new
    pc.hallEntry = ura_mons
    pc.hallIndex = 0
    SpeakCapture.clear
    pc.writeNormalDataPC
    pc.hallIndex = 1
    pc.hallEntry = [ura_mons[1]]
    pc.writeNormalDataPC
    check "the PC records: number, place and team, the first queued", SpeakCapture.log ==
          [[PokeAccess::Verbosity.with_hint("HALL OF FAME No. 001. 1/2. #{T.t(:hofbw_team, :list => 'Orchynx, Nupin')}",
                                            PokeAccess::KeyHints.localize(T.t(:hofbw_pc_keys))), false],
           ["HALL OF FAME No. 002. 2/2. #{T.t(:hofbw_team, :list => 'Nupin')}", true]], SpeakCapture.log

    bagscene = PunchBagScene.new
    SpeakCapture.clear
    bagscene.pbStartScene(ura_mons[0], 10)
    hint = T.t(:pbag_hint, :key => PokeAccess::KeyHints.key(:c, T.t(:key_enter)))
    check "the punch bag opens on its score and, with hints, how the tick guides the hit",
          SpeakCapture.log == [["Score: 0. Hits: 0/10. #{hint}", false]], SpeakCapture.log
    $ura_se = []
    Input.update
    bagscene.steps = [72, 136, 200, 200, 264]
    bagscene.pbMain
    pitches = $ura_se.map { |a| a[2] }
    check "a tick per arrow step inside the game only, peaking at the centre",
          pitches.length == 4 && pitches[2] == 150 && pitches[0] == 80 && pitches[1] == pitches[3] && pitches[1] > 80 && pitches[1] < 150,
          $ura_se
    bagscene.last = 4
    SpeakCapture.clear
    bagscene.computeScore
    check "a scored hit: its stars, then the score", SpeakCapture.log ==
          [["#{T.t(:pbag_stars, :n => 4)}. Score: 4. Hits: 1/10", true]], SpeakCapture.log

    $Trainer.instance_variable_set(:@owned, { 1 => true, 4 => true })
    def $Trainer.owned; @owned; end
    def $Trainer.seen?(sp); true; end
    def $Trainer.owned?(sp); true; end
    dex = PokemonPokedexScene.new
    dex.pbDexSetup
    SpeakCapture.clear
    dex.pbChangeToDexEntry(1)
    entry = SpeakCapture.lines.last.to_s
    check "the info page opens on the number and the name, its caption left out, each value by its label",
          entry.index("001 #{PBSpecies.getName(1)}") == 0 && !entry.index("INFO") && entry.index("HT 0.7 m"), entry
    SpeakCapture.clear
    dex.pbStartDexEntryScene(4)
    reg = SpeakCapture.log.last || []
    check "the registration page after a capture: the new entry and the key that goes on",
          reg[1] == true && reg[0].to_s.index("004 #{PBSpecies.getName(4)}") == 0 && reg[0].to_s.index("Lizard Pokémon") &&
          reg[0].to_s.index("single morsel. #{PokeAccess::TitleScreen.hint}") && !reg[0].to_s.index("registration"),
          SpeakCapture.log
    list = dex.instance_variable_get(:@sprites)["pokedex"]
    list.active = true
    list.update
    SpeakCapture.clear
    dex.pbDexEntry(0)
    list.update
    check "back from an entry, the focused species again, queued", SpeakCapture.log.length == 1 &&
          SpeakCapture.log[0][1] == false && SpeakCapture.log[0][0].index("1, Bulbasaur") == 0, SpeakCapture.log

    search = dex.instance_variable_get(:@sprites)["searchlist"]
    search.active = true
    SpeakCapture.clear
    rows = [1, 2, 3, 5, 6].map do |i|
      search.index = i
      search.update
      dex.pbRefreshDexSearch([0, -1, 0, -1, -1, 0, -1])
      SpeakCapture.lines.last
    end
    unset = T.t(:dxs_unset)
    check "the search rows by label and value, an empty filter as such, START alone",
          rows == ["NAME: #{unset}", "COLOR: #{unset}", "TYPE 1: Fire", "ORDER: Number", "START"] &&
          SpeakCapture.log[0][1] == false, [rows, SpeakCapture.log]
    dex.aux_moves = [1, 0]
    SpeakCapture.clear
    dex.pbDexSearchCommands(["-", "Normal", "Fire"], 2, "TYPE 1")
    check "a value list: its title and the value in use, then its rows, that value marked", SpeakCapture.log ==
          [["TYPE 1: Fire", false], ["Normal", false], [unset, true]], SpeakCapture.log
    SpeakCapture.clear
    dex.aux_moves = [2]
    dex.pbDexSearchCommands(["-", "Normal", "Fire"], 2, "TYPE 1")
    check "and the row in use says so", SpeakCapture.lines == ["TYPE 1: Fire", "Fire, #{T.t(:ura_dex_applied)}"], SpeakCapture.lines
    dex.search_done = true
    SpeakCapture.clear
    dex.pbDexSearch
    list.update
    check "after a search, the results count and the list's focus, queued", SpeakCapture.log.length == 2 &&
          SpeakCapture.log[0] == ["RESULTS 12", false] && SpeakCapture.log[1][1] == false, SpeakCapture.log

    opt = PokemonOptionScene.new
    opt.pbStartScene
    SpeakCapture.clear
    opt.pbUpdate
    opt.pbUpdate
    opt.pbPick(1)
    check "each option's help from the scene's own list, once per row, and on the info key",
          SpeakCapture.lines == ["You can set the game's music volume.", "Set how often the game will autosave in minutes."] &&
          PokeAccess::Info.info_text == "Set how often the game will autosave in minutes.", [SpeakCapture.lines, PokeAccess::Info.info_text]
    pod = Scene_Pokegear.new
    SpeakCapture.clear
    pod.main
    pod.pick(0)
    pod.pick(1)
    check "the PokePod's description of each option, and the info key let go on closing",
          SpeakCapture.lines == ["A Radio. Used to listen to Music.", "Closes the PokéPod and returns to the game."] &&
          PokeAccess::Info.info_text == "Closes the PokéPod and returns to the game.", [SpeakCapture.lines, PokeAccess::Info.info_text]
    rules = PokemonRulesetScene.new(1)
    rules.pbStartScene
    nuz = rules.instance_variable_get(:@sprites)["option"]
    nuz.index = 1
    fresh = PokemonRulesetScene.new(0)
    fresh.pbStartScene
    start = fresh.instance_variable_get(:@sprites)["option"]
    start.index = 1
    check "the rules' exit row with the help the scene writes by its mode",
          [PokeAccess::Menus.focused_text(nuz), PokeAccess::Menus.focused_text(start)] ==
          ["Continue. Permanently disable the options you unchecked.", "Start Game. Begin your game."],
          [PokeAccess::Menus.focused_text(nuz), PokeAccess::Menus.focused_text(start)]

    def $PokemonGlobal.nuzlocke; $ura_nuz; end
    def $PokemonGlobal.randomizer; $ura_rand; end
    $ura_nuz = true
    $ura_rand = true
    SpeakCapture.clear
    PokemonTrainerCardScene.new(1).pbStartScene
    tc = SpeakCapture.lines.first.to_s
    check "the trainer card says the rules its icon shows", tc.index("#{T.t(:ura_nuzlocke)}, #{T.t(:ura_randomizer)}") == 0, tc
    $ura_rand = false

    fallen = Poke.build(:name => "Nupin", :hp => 0)
    def fallen.isNuclear?; false; end
    rad = Poke.build(:name => "Orchynx")
    def rad.isNuclear?; true; end
    def rad.nuclearFree; false; end
    cured = Poke.build(:name => "Geigeroach")
    def cured.isNuclear?; true; end
    def cured.nuclearFree; true; end
    marks = [PokeAccess::Summary.header_icons(fallen), PokeAccess::Party.status_slot(fallen)]
    $ura_nuz = false
    marks += [PokeAccess::Summary.header_icons(fallen), PokeAccess::Party.status_slot(fallen)]
    check "under the Nuzlocke rule a fainted Pokemon is dead, in the party and the summary",
          marks.map { |m| m.to_s.split(", ").last } == [T.t(:ura_dead), T.t(:ura_dead), T.t(:pk_fainted), T.t(:pk_fainted)], marks
    check "a corrupted Nuclear Pokemon carries the RAD mark, a cured one not",
          PokeAccess::Summary.header_icons(rad).to_s.split(", ").last == T.t(:ura_rad) &&
          !PokeAccess::Summary.header_icons(cured).to_s.index(T.t(:ura_rad)), [PokeAccess::Summary.header_icons(rad)]
    memo_pk = Poke.build(:name => "Orchynx")
    def memo_pk.timeReceived; Time.local(2026, 9, 25); end
    def memo_pk.obtainText; ""; end
    def memo_pk.obtainMap; 70; end
    sum = PokemonSummaryScene.new(memo_pk)
    sum.instance_variable_set(:@memo_paint, "Timid nature.\nMet at Lv. 5.")
    SpeakCapture.clear
    sum.drawPageTwo(memo_pk)
    memo = SpeakCapture.lines.last.to_s
    check "the memo page adds the date and the place it draws, a Dream World map marked",
          memo.index("Met at Lv. 5.") && memo.index("#{T.t(:ura_memo_date, :date => '25/9/2026')}. " \
          "#{T.t(:ura_memo_place, :place => "#{pbGetMapNameFromId(70)}, #{T.t(:ura_memo_dream)}")}"), memo
    stats_pk = Poke.build(:iv => [31, 30, 29, 28, 27, 26], :ev => [252, 4, 0, 0, 0, 252])
    SpeakCapture.clear
    PokemonSummaryScene.new(stats_pk).drawPageThree(stats_pk)
    ivev = T.t(:sm_ivev, :hpi => 31, :hpe => 252, :ai => 30, :ae => 4, :di => 29, :de => 0, :sai => 27, :sae => 0,
               :sdi => 26, :sde => 252, :si => 28, :se => 0)
    check "the stats page says each stat's IV and EV as it draws them", SpeakCapture.lines.last.to_s.index(ivev), SpeakCapture.lines

    learner = Poke.build(:name => "Pika")
    mr = MoveRelearnerScene.new
    SpeakCapture.clear
    mr.pbStartScene(learner, [11, 22])
    mr.picks = [1]
    mr.pbChooseMove
    check "the relearner opens on its question and first move, and its first choice loop adds only the moves moved to",
          SpeakCapture.lines.length == 2 && SpeakCapture.lines[0].index("Teach which move to Pika? Mov11") == 0 &&
          SpeakCapture.lines[1].index("Mov22") == 0, SpeakCapture.lines
    SpeakCapture.clear
    mr.picks = []
    mr.pbConfirm("Teach Mov22?")
    mr.pbChooseMove
    check "back from a declined confirmation, the question and the focused move again, queued",
          SpeakCapture.log.length == 2 && SpeakCapture.log[0] == ["Teach Mov22?", false] && SpeakCapture.log[1][1] == false &&
          SpeakCapture.log[1][0].index("Teach which move to Pika? Mov22") == 0, SpeakCapture.log
  RUBY

  # Runs the world, the load and the checks in a gen-6 process: [[label, ok, detail], ...], or the raw output. The
  # script goes through a file, being longer than a Windows command line takes.
  def self.run
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
             "ERRS = Harness.load_all('uranium')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "require #{File.join(support, 'poke_builder').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHECKS}"
    path = File.join(Dir.tmpdir, "pa_uranium_screens_#{Process.pid}.rb")
    File.open(path, "wb") { |f| f.write(script) }
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, path], :err => [:child, :out]) { |io| io.read }
    rows = out.to_s.scan(/^CHECK (.*?)\|([01])\|(.*)$/)
    rows.empty? ? out.to_s : rows
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end

Suite.define("uranium screens: the berry shop, bindings, field overlays, BW screens and relearner say what they paint") do
  rows = UraniumScreensSpec.run
  if rows.is_a?(String)
    truthy "the uranium screens process ran its checks: #{rows[0, 600]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 37
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end
