# The Pokemon Ashen Frost profile loaded whole, over doubles with the shape of its scripts: the pause box its loop sets every
# frame, the case file and its evidence, the documents and pictures, Blackjack, Tutor.net, the remembered moves, the new-game
# options, the region map's sheets, the bag's sorting, the protagonist's switch, the Well Temple's rocks and the flying game, and the plugin readers
# it brings along (Ocarina, Racecourse, Poke Poker). In a process of its own, since its overrides would reach every other test here.
class AshenFrostProfileGdTest < ProfileProcessTest
  # The tiles of the flying game's box the waves cross (x) and never cross (.), rows 3 to 9 by columns 10 to 13: the same on the three
  # maps, as the routes of their control events walk them.
  FLY_BOX_CROSSED = %w[xxxx xxxx xxxx xxxx xxxx .x.x xxxx]

  WORLD = <<-'RUBY'
    $VERBOSE = nil
    require File.join(Harness::ROOT, "test", "support", "world_builder")

    # The game's own buttons, and what is pressed this pulse.
    module Input
      D = 50
      F = 52
    end
    $pressed = nil
    def Input.trigger?(button); $pressed == button; end

    Text = Struct.new(:text)
    Shown = Struct.new(:visible)

    # 001_UI_PauseMenu.rb: its loop sets the box every frame.
    class PokemonPauseMenu_Scene
      def pbStartScene; :started; end
      def pbShowInfo(_text); :box; end
    end

    # 3 - CaseUI.rb's list of cases.
    class CaseUI_Menu_Scene
      attr_reader :sprites

      def initialize(header = "Main Cases")
        list = Window_CommandPokemon.new(["Case One: Safety First", "Case Two: Man's Greatest Vice", "Exit"])
        list.index = 0
        list.active = true
        @sprites = { "header" => Text.new(header), "casewindow" => list }
      end

      def pbUpdate; @sprites["casewindow"].update; end
      def pbStartScene; 3.times { pbUpdate }; end
      def pbScene; pbUpdate; 1; end
      def pbEndScene; :ended; end

      def switch_menu
        @sprites["casewindow"].commands = ["The River's Base", "Exit"]
        @sprites["casewindow"].index = 0
        @sprites["header"].text = "Side Cases"
      end

      def get_case_names(int); { 2 => "Case Two: Man's Greatest Vice", 1 => "Case One: Safety First" }[int]; end
    end

    # 3 - CaseUI.rb's evidence: only the piece under the cursor is painted, the found count in its window. Marin's SpriteHash
    # holds the sprites, not a Hash.
    class SpriteTable
      def initialize(table); @table = table; end
      def [](key); @table[key]; end
    end
    class CaseUI_Evidence
      PIECES = { :CLUEPOST => ["Postcard Clue", "Case Fourteen's Hall", "Reading Luciano's Papers.", "A postcard.", false],
                 :TESTJADE => ["Jade's Testimony", "Priya's Condo", "Talking to Jade.", "She was with Sammy.", true],
                 :CLUESAFE => ["Safe Clue", "Hotel", "Inspecting the Hotel Safe.", "An indestructible safe.", false] }
      attr_accessor :index, :top_index
      def initialize(pieces, picking = false)
        @evidence = pieces
        @picking = picking
        @index = 0
        @top_index = 0
        @sprites = SpriteTable.new("found" => Text.new("Found: #{pieces.length}/5"), "examine" => Shown.new(false))
      end

      def draw_list
        name = @evidence[@top_index + @index]
        return unless name
        row = PIECES[name]
        drawTextEx(nil, 24, 228, 354, 0, row[3])
        pbDrawTextPositions(nil, [[row[0], 164, 26], ["Obtained: #{row[1]}", 24, 100], ["For: #{row[2]}", 24, 160]])
        @sprites["examine"].visible = !row[4]
      end

      def examine_evidence; :closed; end
      def dispose; :disposed; end
    end

    # The documents' scenes (EventScene), and the function that opens them.
    %w[Case14Images Case16Images SongRed SongOrange SongYellow SongGreen SongBlue Pianoconfig_A Pianoconfig_B Pianoconfig_C
       Pianoconfig_D Pianoconfig_8 PlateFlame].each do |name|
      Object.const_set(name, Class.new { def pbOnScreenEnd(_scene, *_args); :next; end })
    end
    class Case13Images
      def set_up_screen(_number); :shown; end
      def pbOnScreenEnd(_scene, *_args); :next; end
    end
    def pbEventScreen(cls); cls; end

    # Blackjack minigame/*: the dealer and the player, as setStruct leaves them.
    module BlackJack
      class Play
        attr_reader :player
        def initialize
          @player = { :dealer => { :player => false, :card => [], :status => [] },
                      :player => { :player => true, :card => [], :status => [] } }
        end

        def deal(name, card, status)
          @player[name][:card].push(card)
          @player[name][:status].push(status)
        end

        def drawCard(*arr); arr; end
        def drawTxtSum; pbDrawTextPositions(nil, [["Card Sum: #{$sum}", 256, 276]]); end
        def drawTxtBet; pbDrawTextPositions(nil, [["Bet: 5", 256, 252]]); end
        def clearCard; :cleared; end
        def endScene; :ended; end
      end
    end

    # The move object Tutor.net's rows are read through.
    class Pokemon
      class Move
        def initialize(id); @id = id; end
        def type; :NORMAL; end
        def name; @id.to_s; end
      end
    end

    # Tutor.net.rb: the list window, the panels with their @comp icons, and the scene's loop.
    class TutorPanel; def initialize(comp); @comp = comp; end; end
    TutorList = Struct.new(:index)
    Kid = Struct.new(:name)
    class PokemonTutorNet_Scene
      def initialize(rows, party, comps)
        @move_list = rows
        @party = party
        @last_mon_index = 1
        @sprites = { "commands" => TutorList.new(0) }
        comps.each_with_index { |c, i| @sprites["pokemon#{i}"] = TutorPanel.new(c) }
      end

      def pbScene; yield_loop; end
      def yield_loop; update_indicators; end
      def update_indicators(_move_list = nil); :updated; end
      def pbChangeSelection(_key, currentsel); currentsel; end
      def pbChoosePokemon; -1; end
      def pbEndScene; :ended; end
      def pbSetCommands(_commands, _index); :set; end
    end

    # 001_MichaelUtilities.rb's check of a typed code, which opens the entry screen.
    def passCheck(_code, _helptext, _min, _max, _flag = false); false; end

    # 013_Move_Remember.rb, the stock relearner's shape.
    class MoveRemember_Scene
      Cmd = Struct.new(:index)
      def initialize(moves); @moves = moves; @sprites = { "commands" => Cmd.new(0) }; end
      def pbStartScene; pbDrawMoveList; end
      def pbDrawMoveList; :drawn; end
      def pbDisplay(_msg, _brief = false); :shown; end
      def pbConfirm(_msg); true; end
      def pbEndScene; :ended; end
    end

    # 009_IntroOptions.rb.
    class PokemonIntroOption_Scene
      Opt = Struct.new(:index) { def [](_i); 0; end }
      attr_reader :sprites
      def initialize
        @sprites = { "title" => Text.new("Options"), "textbox" => Text.new("First help"), "option" => Opt.new(0) }
      end

      def pbStartScene(_in_load_screen = false); :started; end
      def pbUpdate; :updated; end
      def pbChangeSelection; :changed; end
      def pbEndScene; :ended; end
    end

    # 009_UI_RegionMap.rb's additions to the stock scene.
    class MapBottom; def initialize(name); @mapname = name; end; end
    class PokemonRegionMap_Scene
      def initialize(sprites); @sprites = sprites; end
      def pbStartScene(_as_editor = false, _fly_map = false); :started; end
      def swap_maps(_map_index, _starting_region, _player_x, _player_y); :swapped; end
      def pbGetMapLocation(_x, _y); ""; end
      def pbEndScene; :ended; end
    end

    # 011_Messages.rb's bank window.
    BankWindow = Struct.new(:text)
    def pbDisplayBankWindow(_msgwindow, _goldwindow); BankWindow.new("Bank:\n<ar>$500</ar>"); end

    # mkxp-z's window of bindings.
    module System; def self.show_settings; :open; end; end

    # 007_UI_Bag.rb's screen.
    class PokemonBag_Scene; def pbStartScene(_bag, _choosing = false); :started; end; end

    # 007_UI_Bag.rb's sorting.
    class PokemonBag; def sort_pocket_alphabetically; :sorted; end; end

    # Multiple Protagonists.
    $hero = Struct.new(:name, :character_ID, :level_cap).new("Sylvester", 1, 15)
    def pbSwitchCharacter(id, _name = nil, _outfit = 0)
      return if id == $hero.character_ID
      $hero.character_ID = id
      $hero.name = "Mordecai"
    end

    # Ocarina.rb: the loop of the melody, driven by the play.
    class Flute
      attr_accessor :body
      def pbUpdate(_n, _i); @body.call; end
    end

    # 009_Minigame_Race_Course.rb: the loop is driven by the play, and each step is its ivars.
    CANDIDAT = %w[RAPIDASH STANTLER NOSEPASS GASTRODON]
    COIN_RACEGAME = { "Coin1" => 1, "Coin2" => 12, "Coin3" => 5 }
    class RaceGame
      attr_accessor :body
      def pbStart; @body.call(self); end
      def pbEndScene; :ended; end
      def set(hash); hash.each { |k, v| instance_variable_set("@#{k}", v) }; end
    end

    # 003_Game_Picture.rb's fade (command 232).
    class Game_Picture
      def move(_duration, _origin, _x, _y, _zoom_x, _zoom_y, _opacity, _blend_type); self; end
    end

    # 011_Minigame_Poker.rb.
    class Pokepoker
      def set(hash); hash.each { |k, v| instance_variable_set("@#{k}", v) }; end
      attr_accessor :raise_loop

      def betscene
        updateselect
        raise_loop.call(self) if raise_loop
        :raised
      end

      def updatepot; :painted; end
      def drawcards; :dealt; end
      def fsubround; :moved; end
      def osubround; :moved; end
      def roundwinner; :won; end
      def updateselect; :selected; end
      def updatebet; :bet; end
      def updatechips(_player); :painted; end
      def pbpokepokerstart; :played; end
      def pokerdispose; :disposed; end
    end
  RUBY

  PLAY = <<-'RUBY'
    Harness.source(File.join(Harness::ROOT, "plugins", "manifest.rb"))
    def $player.level_cap; 15; end rescue nil
    $PokemonGlobal = Object.new unless $PokemonGlobal
    def $PokemonGlobal.case_num; 4; end
    def $PokemonGlobal.side_case; @side ||= []; end

    probe(:profile_name) { PokeAccess::Game.profile_name }
    probe(:plain) { PokeAccess::World::Probe.plain? }
    probe(:letters) { PokeAccess::KeyHints.table }
    probe(:weather) { [:FreezingRain, :FrozenStorm, :HolyInferno, :SolarWinds].map { |w| PokeAccess::Battle.weather_name(w) } }
    probe(:trainer_parts) { [PokeAccess::Info::TRAINER_PARTS[:case_file].call($player), PokeAccess::Info::TRAINER_PARTS[:level_cap].call($player)] }
    probe(:trainer_order) { PokeAccess::Config.trainer_parts }
    probe(:remap) { [PokeAccess::Remap.extra_buttons[:ashen_move_info], PokeAccess::Remap.extra_buttons[:ashen_skip]] }

    pause = PokemonPauseMenu_Scene.new
    box = "<ac>Aurora Downs</ac> Money: <r>$1,200<br> Level Cap: <r>15<br>"
    probe(:pause_frames) { said { pause.pbStartScene; 5.times { pause.pbShowInfo(box) } } }
    probe(:pause_again) { said { pause.pbStartScene; 2.times { pause.pbShowInfo(box) } } }
    probe(:pause_change) { said { pause.pbShowInfo(box.sub("1,200", "900")) } }

    PIECES = [:CLUEPOST, :TESTJADE, :CLUESAFE]
    probe(:ev_first) { said { CaseUI_Evidence.new(PIECES).draw_list } }
    probe(:ev_present) { said { CaseUI_Evidence.new(PIECES, true).draw_list } }
    probe(:ev_empty) { said { CaseUI_Evidence.new([]).draw_list } }
    ev = CaseUI_Evidence.new(PIECES)
    probe(:ev_moves) do
      ev.draw_list
      said { ev.index = 1; ev.draw_list }
    end
    probe(:ev_info) { [PokeAccess::Info.info_text, PokeAccess::Info.row_text] }
    probe(:ev_next_is_a_clue) { said { ev.index = 2; ev.draw_list } }
    probe(:ev_examine) { said { ev.examine_evidence } }
    probe(:ev_examine_info) { PokeAccess::Info.info_text }
    probe(:ev_closed) { ev.dispose; PokeAccess::Info.info_text.to_s }
    clue = CaseUI_Evidence.new([:CLUEPOST])
    probe(:ev_clue_examine) { clue.draw_list; said { clue.examine_evidence } }
    probe(:ev_clue_row_back) { PokeAccess::Info.info_text }

    probe(:case_opening) do
      scene = CaseUI_Menu_Scene.new
      said { scene.pbStartScene; scene.pbScene; scene.pbUpdate }
    end
    probe(:case_back) do
      scene = CaseUI_Menu_Scene.new
      scene.pbStartScene
      scene.pbScene
      said { scene.pbScene; scene.pbUpdate }
    end
    probe(:case_tab) do
      scene = CaseUI_Menu_Scene.new
      scene.pbStartScene
      said { scene.switch_menu; scene.pbUpdate; scene.pbUpdate }
    end
    probe(:case_tab_from_a_row) do
      scene = CaseUI_Menu_Scene.new
      scene.pbStartScene
      scene.sprites["casewindow"].index = 1
      scene.pbUpdate
      said { scene.switch_menu; scene.pbUpdate; scene.pbUpdate }
    end
    probe(:case_hint) do
      $PokemonGlobal.side_case.push(50)
      scene = CaseUI_Menu_Scene.new
      [said { scene.pbScene }, said { scene.pbScene }]
    end

    probe(:doc_newspaper) { said { pbEventScreen(Case14Images) } }
    probe(:doc_newspaper_info) { PokeAccess::Info.info_text }
    probe(:doc_closed) { Case14Images.new.pbOnScreenEnd(nil); PokeAccess::Info.info_text.to_s }
    probe(:doc_letter) { said { pbEventScreen(Case16Images) } }
    probe(:doc_sheets) { %w[SongRed SongBlue Pianoconfig_8].map { |n| said { pbEventScreen(Object.const_get(n)) } } }
    probe(:doc_pages) { [1, 2, 3].map { |n| said { Case13Images.new.set_up_screen(n) } } }
    probe(:doc_plate_alone) { said { pbEventScreen(PlateFlame) } }
    probe(:doc_plate_message) { said { PokeAccess.say_dialogue("The power of defeated giants infuses this Plate.") } }

    shows = lambda { |name| said { Game_Picture.new.show(name, 0, 0, 0, 100, 100, 255, 0) } }
    # An event's picture loaded out of sight and its fade (commands 231 and 232).
    unseen = lambda { |picture, name| picture.show(name, 0, 0, 0, 100, 100, 0, 0) }
    fade = lambda { |picture, opacity| picture.move(6, 0, 0, 0, 100, 100, opacity, 0) }
    probe(:pic_titles) { ["Case Two", "Case Two (1)", "Case Two (2)", "Case One (1)", "Case 3.5 (1)", "Case Five (1)", "Case Six (1)"].map { |n| shows.call(n) } }
    probe(:pic_counts) { ["Arturo's_Lives_2", "Flying_Health_3", "Flying_Health_Tropius_1", "HP_Player_4", "HP_Girl_0"].map { |n| shows.call(n) } }
    probe(:pic_words) { ["Flying_Cleared", "Transition_Copper_Text", "Crossword_2", "Picture_Research"].map { |n| shows.call(n) } }
    probe(:pic_dead) { ["Newspaper_1", "Newspaper_4", "Rosewell_3", "Black", "introbg", "Gradient Swipe"].map { |n| shows.call(n) } }
    probe(:pic_flying) { said { %w[Flying_Border Flying_Health_5 Flying_Start].each { |n| Game_Picture.new.show(n, 0, 0, 0, 100, 100, 255, 0) } } }
    probe(:pic_flying_end) { said { %w[Flying_Health_0 Flying_Failed].each { |n| Game_Picture.new.show(n, 0, 0, 0, 100, 100, 255, 0) } } }
    probe(:pic_unseen) do
      Game_Picture.new.erase
      picture = Game_Picture.new
      loaded = said { unseen.call(picture, "Rockruff_1") }
      still_out = said { fade.call(picture, 0) }
      up = said { fade.call(picture, 255) }
      again = said { fade.call(picture, 0); fade.call(picture, 255) }
      [loaded, still_out, up, again]
    end
    probe(:pic_never_seen) do
      Game_Picture.new.erase
      picture = Game_Picture.new
      said do
        unseen.call(picture, "Sylvesters Crazy Relative")
        fade.call(picture, 0)
        picture.erase
        fade.call(picture, 255)
      end
    end
    probe(:pic_unseen_apart) do
      Game_Picture.new.erase
      first = Game_Picture.new
      second = Game_Picture.new
      said do
        unseen.call(first, "Rockruff_1")
        unseen.call(second, "Memory_Spa")
        fade.call(second, 255)
        fade.call(first, 255)
      end
    end
    probe(:pic_unseen_replaced) do
      Game_Picture.new.erase
      picture = Game_Picture.new
      said do
        unseen.call(picture, "Rockruff_1")
        picture.show("Memory_Spa", 0, 0, 0, 100, 100, 255, 0)
        fade.call(picture, 255)
      end
    end
    probe(:pic_faded_says_again) do
      Game_Picture.new.erase
      picture = Game_Picture.new
      first = said { unseen.call(picture, "TV_Sparky"); fade.call(picture, 255) }
      faded = said { fade.call(picture, 0) }
      other_event = Game_Picture.new
      second = said { unseen.call(other_event, "TV_Sparky"); fade.call(other_event, 255) }
      [first, faded, second]
    end
    probe(:pic_blink) do
      Game_Picture.new.erase
      picture = Game_Picture.new
      said do
        picture.show("Flying_Start", 0, 0, 0, 100, 100, 255, 0)
        2.times { fade.call(picture, 0); fade.call(picture, 255) }
      end
    end
    probe(:pic_unseen_title) do
      picture = Game_Picture.new
      [said { unseen.call(picture, "Case One (1)") }, said { fade.call(picture, 255) }]
    end
    probe(:fly_free) do
      pictures = Array.new(51) { Game_Picture.new }
      pictures[1].show("Flying_Border", 0, 0, 0, 100, 100, 255, 0)
      pictures[3].show("Flying_Start", 0, 0, 0, 100, 100, 255, 0)
      $game_screen = Struct.new(:pictures).new(pictures)
      out = [PokeAccess::PictureCues.menu_showing?, PokeAccess::Control.free?, PokeAccess::Control.keys?, PokeAccess::PictureCues::TEXTS.keys]
      $game_screen = nil
      out
    end
    probe(:pic_series) do
      erase = Game_Picture.new
      erase.erase
      series = %w[Lon_Interview_1 Lon_Interview_2 Lon_Interview_1 Static_A Static_B]
      said { series.each { |n| Game_Picture.new.show(n, 0, 0, 0, 100, 100, 255, 0) } }
    end
    probe(:pic_series_again) do
      Game_Picture.new.erase
      [shows.call("Lon_Interview_1"), shows.call("Lon_Interview_2")]
    end
    probe(:pic_erased_says_again) do
      Game_Picture.new.erase
      first = shows.call("Serenity Letter")
      again = shows.call("Serenity Letter")
      Game_Picture.new.erase
      [first, again, shows.call("Serenity Letter")]
    end
    probe(:pic_painted_inside) { Game_Picture.new.erase; [shows.call("Young Mordecai_Blurry"), shows.call("Culprit_3"), shows.call("TV_Sparky")] }
    probe(:pic_brief) do
      Game_Picture.new.erase
      PokeAccess::Config.verbosity = :brief
      out = [shows.call("Memory_Spa"), shows.call("Escape_1"), shows.call("Flying_Start")]
      PokeAccess::Config.verbosity = nil
      out
    end
    probe(:pic_table_words) do
      tables = PokeAccess::AshenPictures::SHOWN.values + PokeAccess::AshenPictures::DESCRIBED.values +
               PokeAccess::AshenDocuments::CLUE_VIEWS.values + PokeAccess::AshenDocuments::CLUE_NOTES.values
      tables.map { |entry| PokeAccess::AshenPictures.words(entry) }
    end
    probe(:clue_views) { PokeAccess::AshenDocuments::CLUE_VIEWS.values }
    probe(:clue_words) { %w[CLUELIST CLUEPOST SERENITYLETTER GRADPHOTO].map { |n| PokeAccess::AshenDocuments.clue(n) } }
    entry = lambda { |help, max| said { passCheck("Answer", help, 0, max, false) } }
    probe(:xw) { [["Actress", 5], ["City Supervillain", 5], ["Tech Company", 8], ["Winter Sport", 7], ["Password:", 3]].map { |h, m| entry.call(h, m) } }
    map_key = lambda { PokeAccess::Locator.refresh_info; PokeAccess::Info.info_text.to_s }
    probe(:xw_info) do
      picture = Game_Picture.new
      unseen.call(picture, "Crossword_1")
      unasked = map_key.call
      fade.call(picture, 255)
      asked = map_key.call
      passed = passCheck("Silva", "City Supervillain", 0, 5, false)
      closed = map_key.call
      done = Game_Picture.new
      done.show("Crossword_6", 0, 0, 0, 100, 100, 255, 0)
      finished = map_key.call
      Game_Picture.new.show("Crossword_0", 0, 0, 0, 100, 100, 255, 0)
      PokeAccess::Caches.reset_all
      [unasked, asked, passed, closed, finished, map_key.call]
    end
    probe(:pic_hart) { %w[Hart_1 Hart_2 Hart_3 Hart_1].map { |n| shows.call(n) } }
    probe(:bank_window) { said { pbDisplayBankWindow(nil, nil) } }
    probe(:controls_window) { said { System.show_settings } }
    probe(:bag_hint) { said { PokemonBag_Scene.new.pbStartScene(nil) } }
    probe(:atm_message) { PokeAccess.clean('\\G\\DP\\se[GUI sel buzzer]\\xn[ATM]Insufficient funds.') }

    probe(:bj_info) do
      play = BlackJack::Play.new
      $sum = 8
      play.drawTxtBet
      play.deal(:player, 12, true)
      play.drawCard(:player, 0)
      play.drawTxtSum
      play.deal(:dealer, 2, true)
      play.drawCard(:dealer, 0)
      play.deal(:dealer, 51, false)
      play.drawCard(:dealer, 1)
      shown = PokeAccess::Info.info_text
      play.endScene
      [shown, PokeAccess::Info.info_text.to_s]
    end
    probe(:bj_info_painted) do
      play = BlackJack::Play.new
      $sum = 11
      play.drawTxtSum
      sum = PokeAccess::Info.info_text
      play.drawTxtBet
      [sum, PokeAccess::Info.info_text]
    end
    probe(:bj_hand) do
      play = BlackJack::Play.new
      $sum = 8
      play.drawTxtSum
      play.deal(:player, 12, true)
      a = said { play.drawCard(:player, 0) }
      $sum = 19
      play.drawTxtSum
      play.deal(:player, 41, false)
      b = said { play.drawCard(:player, 1) }
      again = said { play.drawCard(:player, 1) }
      play.deal(:dealer, 2, true)
      c = said { play.drawCard(:dealer, 0) }
      play.deal(:dealer, 51, false)
      hidden = said { play.drawCard(:dealer, 1) }
      play.player[:dealer][:status][1] = true
      opened = said { play.drawCard(:dealer, 1) }
      bet = said { play.drawTxtBet }
      play.clearCard
      fresh = said { play.drawCard(:player, 0) }
      [a, b, again, c, hidden, opened, bet, fresh]
    end

    party = [Kid.new("Truffles"), Kid.new("Nie"), Kid.new("Egg")]
    tutor = lambda { |row, comps| PokemonTutorNet_Scene.new([[row, "Name"]], party, comps) }
    probe(:tutor_type) do
      scene = tutor.call([:POUND, 1500, "$"], [1, 3, 0])
      def scene.yield_loop; update_indicators; end
      line = said { scene.pbScene }
      [line, GameData::Type.get(Pokemon::Move.new(:POUND).type).name]
    end
    probe(:tutor_info) { PokeAccess::Info.info_text }
    probe(:tutor_end_clears) do
      tutor.call([:POUND, 0, "$"], [1, 0, 0]).pbEndScene
      PokeAccess::Info.info_text
    end
    probe(:tutor_filter_list) do
      scene = tutor.call([:POUND, 0, "$"], [1, 0, 0])
      list = scene.instance_variable_get(:@sprites)["commands"]
      before = PokeAccess.dedicated?(list)
      scene.pbSetCommands([], 0)
      [before, PokeAccess.dedicated?(list)]
    end
    probe(:tutor_back_on_list) do
      scene = tutor.call([:POUND, 0, "$"], [1, 0, 0])
      scene.pbScene
      list = scene.instance_variable_get(:@sprites)["commands"]
      PokeAccess::Cursor.changed?(list, :cmd_focus, :read)
      scene.pbScene
      PokeAccess::Cursor.current(list, :cmd_focus)
    end
    probe(:tutor_money) { said { tutor.call([:POUND, 1500, "$"], [1, 3, 0]).pbScene } }
    probe(:tutor_free_nobody) { said { tutor.call([:POUND, 0, "$"], [2, 2, 0]).pbScene } }
    probe(:tutor_coins) { said { tutor.call([:POUND, 100, "c"], [0, 0, 0]).pbScene } }
    probe(:tutor_item) { said { tutor.call([:POUND, 3, :HEARTSCALE], [0, 0, 0]).pbScene } }
    probe(:tutor_once) do
      scene = tutor.call([:POUND, 0, "$"], [1, 0, 0])
      def scene.yield_loop; update_indicators; update_indicators; end
      said { scene.pbScene }
    end
    probe(:tutor_filter_repaint) do
      scene = tutor.call([:POUND, 0, "$"], [1, 0, 0])
      def scene.yield_loop; update_indicators([:a_list]); end
      said { scene.pbScene }
    end
    probe(:tutor_outside_loop) { said { tutor.call([:POUND, 0, "$"], [1, 0, 0]).update_indicators } }
    probe(:tutor_grid) do
      scene = tutor.call([:POUND, 0, "$"], [1, 3, 0])
      [said { scene.pbChoosePokemon }, said { scene.pbChangeSelection(0, 0) }, said { scene.pbChangeSelection(0, 2) }]
    end

    probe(:tutor_cancel) do
      scene = tutor.call([:POUND, 0, "$"], [1, 0, 0])
      def scene.yield_loop; update_indicators; pbChoosePokemon; update_indicators; end
      list = scene.instance_variable_get(:@sprites)["commands"]
      PokeAccess::Cursor.store(list, :cmd_focus, [0, nil, nil])
      [said { scene.pbScene }.map { |l| l[0] }, PokeAccess::Cursor.current(list, :cmd_focus)]
    end
    probe(:tutor_chosen) do
      scene = tutor.call([:POUND, 0, "$"], [1, 0, 0])
      def scene.pbChoosePokemon; 1; end
      def scene.yield_loop; update_indicators; pbChoosePokemon; update_indicators; end
      said { scene.pbScene }.length
    end
    probe(:tutor_empty) { said { PokemonTutorNet_Scene.new([], party, [0, 0, 0]).pbScene } }
    probe(:aux2) { said { PokeAccess.say_dialogue("By pressing the AUX2 button (default: F), you can filter the move list.") } }

    probe(:remember) do
      scene = MoveRemember_Scene.new([:POUND, :TACKLE])
      first = said { scene.pbStartScene }
      scene.instance_variable_get(:@sprites)["commands"].index = 1
      moved = said { scene.pbDrawMoveList }
      [first, moved, said { scene.pbConfirm("Teach Tackle?") }, PokeAccess.dedicated?(scene.instance_variable_get(:@sprites)["commands"])]
    end
    probe(:remember_closed) { MoveRemember_Scene.new([:POUND]).pbEndScene; PokeAccess::Info.info_text.to_s }

    probe(:intro_options) do
      scene = PokemonIntroOption_Scene.new
      title = said { scene.pbStartScene; scene.pbUpdate; scene.pbUpdate }
      scene.pbChangeSelection
      scene.sprites["option"].index = 1
      scene.sprites["textbox"].text = "Choose the difficulty you'd like to play on."
      scene.pbChangeSelection
      [title, PokeAccess::Info.info_text]
    end

    probe(:sheet_swap) do
      scene = PokemonRegionMap_Scene.new("mapbottom" => MapBottom.new("Riverview <c2=65467BFF>Island</c2>"))
      [said { scene.swap_maps(1, 0, 0, 0) }, PokeAccess::Cursor.current(scene, :region_map)]
    end
    probe(:sheet_hint) do
      with = PokemonRegionMap_Scene.new("switcher" => Object.new, "mapbottom" => MapBottom.new("Riverview"))
      without = PokemonRegionMap_Scene.new("mapbottom" => MapBottom.new("Riverview"))
      [said { with.pbStartScene }.map { |l| l[0] }, said { without.pbStartScene }.map { |l| l[0] }]
    end
    probe(:bag_sorted) { said { PokemonBag.new.sort_pocket_alphabetically } }
    probe(:switched) do
      was = $player
      $player = $hero
      same = said { pbSwitchCharacter(1) }
      other = said { pbSwitchCharacter(2) }
      $player = was
      [same, other]
    end

    probe(:ocarina) do
      out = []
      opening = nil
      flute = Flute.new
      flute.body = lambda do
        opening = SpeakCapture.log.dup
        [Input::UP, nil, Input::RIGHT].each do |b|
          $pressed = b
          out.push(said { PokeAccess::Frame.run_pollers })
        end
        $pressed = nil
        :done
      end
      flute.pbUpdate(0, 368)
      $pressed = Input::UP
      after = said { PokeAccess::Frame.run_pollers }
      $pressed = nil
      [out, after, opening]
    end

    probe(:racecourse) do
      lines = []
      race = RaceGame.new
      steps = [{ :process => 0, :select => true, :sprites => { "Play" => Object.new } }, { :select => false }, { :process => 1, :selecttwo => 0 }, { :selecttwo => 3 },
               { :process => 2, :selectcoin => 1 }, { :process => 3, :choose => 2 }, { :process => 4 }, { :process => 5 },
               { :process => 6, :win => 2 }, { :process => 7, :continue => true }, { :continue => false }, { :continue => false }]
      race.body = lambda do |scene|
        steps.each do |step|
          scene.set(step)
          lines.push(said { PokeAccess::Frame.run_pollers })
        end
        :left
      end
      was = $player
      coins = Object.new
      def coins.coins; 77; end
      $player = coins
      race.pbStart
      $player = was
      lines
    end
    probe(:racecourse_box) do
      lines = []
      info = []
      race = RaceGame.new
      steps = [{ :process => 2, :selectcoin => 0, :check => true }, { :check => false }, { :selectcoin => 1 }, { :check => true }]
      race.body = lambda do |scene|
        steps.each do |step|
          scene.set(step)
          lines.push(said { PokeAccess::Frame.run_pollers })
          info.push(map_key.call)
        end
        :left
      end
      was = $player
      coins = Object.new
      def coins.coins; 77; end
      $player = coins
      race.pbStart
      $player = was
      race.pbEndScene
      [lines, info, PokeAccess::Info.info_text.to_s]
    end
    probe(:racecourse_no_coins) do
      lines = []
      race = RaceGame.new
      race.body = lambda do |scene|
        scene.set(:process => 2, :selectcoin => 2, :check => false)
        lines.push(said { PokeAccess::Frame.run_pollers })
        :left
      end
      was = [$player, $Trainer, $PokemonGlobal]
      $player = Object.new
      $Trainer = nil
      $PokemonGlobal = nil
      race.pbStart
      $player, $Trainer, $PokemonGlobal = was
      lines
    end
    probe(:racecourse_no_menu) do
      lines = []
      race = RaceGame.new
      race.body = lambda do |scene|
        scene.set(:process => 0, :select => true, :sprites => {})
        lines.push(said { PokeAccess::Frame.run_pollers })
        :left
      end
      race.pbStart
      lines
    end
    probe(:racecourse_tie) do
      lines = []
      race = RaceGame.new
      race.body = lambda do |scene|
        scene.set(:process => 6, :win => nil)
        lines.push(said { PokeAccess::Frame.run_pollers })
        scene.set(:process => 0, :select => true)
        :left
      end
      race.pbStart
      lines
    end

    CARD = lambda { |value, suit| [value, "painted only", value, suit] }
    poker = Pokepoker.new
    seats = [[490, 1, 1, "Sylvester"], [480, 1, 1, "Nie"], [500, 0, 1, "Cord"], [500, 1, 1, "Jade"]]
    poker.set(:players => seats, :player1card1 => CARD.call(2, "Spades"), :player1card2 => CARD.call(14, "Hearts"),
              :player2card1 => CARD.call(10, "Clubs"), :player2card2 => CARD.call(11, "Clubs"),
              :player4card1 => CARD.call(13, "Clubs"), :player4card2 => CARD.call(4, "Clubs"),
              :comcard1 => CARD.call(5, "Diamonds"), :comcard2 => CARD.call(6, "Clubs"), :comcard3 => CARD.call(12, "Hearts"),
              :comcard4 => CARD.call(8, "Clubs"), :comcard5 => CARD.call(9, "Clubs"),
              :comcards => 0, :pot => 30, :previousbet => 20, :player1bet => 10, :playing => 0, :select => 5, :raisevalue => 50)
    probe(:poker_dealt) { said { poker.drawcards } }
    probe(:poker_dealt_info) { map_key.call }
    probe(:poker_turn) do
      line = said { poker.fsubround; PokeAccess.say_dialogue("What will you do?") }
      [line, PokeAccess::Info.info_text]
    end
    probe(:poker_blind) do
      table = Pokepoker.new
      table.set(:players => seats, :comcards => 0, :pot => 15, :previousbet => 0, :player1bet => 0, :playing => 0, :blindvalue => 10)
      [said { table.fsubround; PokeAccess.say_dialogue("Call, raise or fold?") }, PokeAccess::Info.info_text]
    end
    probe(:poker_dealt_out) do
      table = Pokepoker.new
      out = [[0, 0, 0, "Sylvester"], [480, 1, 1, "Nie"], [500, 1, 1, "Cord"], [500, 1, 1, "Jade"]]
      table.set(:players => out, :player1card1 => CARD.call(2, "Spades"), :player1card2 => CARD.call(3, "Spades"), :comcards => 0, :pot => 0)
      said { table.drawcards }
    end
    probe(:poker_wraps_to_the_player) do
      table = Pokepoker.new
      round = [[490, 1, 1, "Sylvester"], [480, 1, 1, "Nie"], [500, 1, 1, "Cord"], [500, 0, 1, "Jade"]]
      table.set(:players => round, :comcards => 0, :pot => 15, :previousbet => 10, :player1bet => 10, :playing => 3)
      said { table.fsubround; PokeAccess.say_dialogue("Back to the player.") }
    end
    probe(:poker_not_your_turn) do
      poker.set(:playing => 1, :pot => 40)
      lines = said { poker.fsubround; PokeAccess.say_dialogue("Nie calls.") }
      [lines, PokeAccess::Info.info_text]
    end
    probe(:poker_second_hand) do
      table = Pokepoker.new
      table.set(:players => seats, :player1card1 => CARD.call(3, "Spades"), :player1card2 => CARD.call(4, "Hearts"),
                :comcard1 => CARD.call(7, "Diamonds"), :comcard2 => CARD.call(7, "Clubs"), :comcard3 => CARD.call(7, "Hearts"),
                :comcard4 => CARD.call(7, "Spades"), :comcard5 => CARD.call(10, "Hearts"),
                :comcards => 3, :pot => 0, :previousbet => 0, :player1bet => 0, :playing => 0)
      table.drawcards
      blind_message = map_key.call
      table.set(:comcards => 0)
      table.updatechips(0)
      blind_posted = map_key.call
      table.set(:comcards => 1)
      table.updatechips(0)
      flop = map_key.call
      table.pokerdispose
      [blind_message, blind_posted, flop]
    end
    probe(:poker_hand_over) do
      table = Pokepoker.new
      table.set(:players => seats, :player1card1 => CARD.call(3, "Spades"), :player1card2 => CARD.call(4, "Hearts"),
                :comcard1 => CARD.call(7, "Diamonds"), :comcard2 => CARD.call(7, "Clubs"), :comcard3 => CARD.call(7, "Hearts"),
                :comcard4 => CARD.call(7, "Spades"), :comcard5 => CARD.call(10, "Hearts"),
                :comcards => 3, :pot => 60, :previousbet => 0, :player1bet => 0, :playing => 0)
      table.updatechips(0)
      winner = map_key.call
      table.updatepot
      still_on = map_key.call
      table.set(:pot => 0)
      table.updatepot
      put_away = map_key.call
      table.drawcards
      dealt = map_key.call
      table.pokerdispose
      [winner, still_on, put_away, dealt]
    end
    probe(:poker_first_deal) do
      table = Pokepoker.new
      table.set(:players => seats, :player1card1 => CARD.call(3, "Spades"), :player1card2 => CARD.call(4, "Hearts"), :pot => 0,
                :previousbet => 0, :player1bet => 0, :playing => 0, :blindvalue => 10)
      table.drawcards
      info = map_key.call
      table.pokerdispose
      info
    end
    probe(:poker_folded) do
      table = Pokepoker.new
      folded = [[490, 0, 1, "Sylvester"], [480, 1, 1, "Nie"], [500, 1, 1, "Cord"], [500, 1, 1, "Jade"]]
      table.set(:players => folded, :player1card1 => CARD.call(3, "Spades"), :player1card2 => CARD.call(4, "Hearts"),
                :comcards => 0, :pot => 30, :previousbet => 20, :player1bet => 10, :playing => 1)
      table.updatechips(0)
      info = map_key.call
      table.pokerdispose
      info
    end
    probe(:poker_last_bet) do
      table = Pokepoker.new
      table.set(:players => seats, :comcards => 0, :pot => 30, :previousbet => 0, :player1bet => 0, :playing => 0)
      table.updatechips(0)
      table.set(:pot => 70)
      table.updatepot
      info = map_key.call
      table.pokerdispose
      info
    end
    probe(:poker_shown_kept) do
      table = Pokepoker.new
      table.set(:players => seats, :player2card1 => CARD.call(10, "Clubs"), :player2card2 => CARD.call(11, "Clubs"),
                :player4card1 => CARD.call(13, "Clubs"), :player4card2 => CARD.call(4, "Clubs"),
                :comcards => 0, :pot => 30, :previousbet => 0, :player1bet => 0, :playing => 0)
      table.roundwinner
      shown = map_key.call
      table.set(:pot => 0)
      table.updatepot
      put_away = map_key.call
      table.pokerdispose
      [shown, put_away]
    end
    probe(:poker_menu_key) do
      table = Pokepoker.new
      table.set(:players => seats, :comcards => 0, :pot => 30, :previousbet => 0, :player1bet => 0, :playing => 0, :blindvalue => 10,
                :select => 1, :raisevalue => 0)
      keys = []
      table.raise_loop = lambda do |scene|
        keys.push(map_key.call)
        scene.set(:select => 5)
        scene.updateselect
        keys.push(map_key.call)
        scene.set(:select => 3)
        scene.updateselect
        scene.set(:raisevalue => 50)
        scene.updatebet
        keys.push(map_key.call)
      end
      table.betscene
      keys.push(map_key.call)
      table.pokerdispose
      keys
    end
    probe(:poker_raise_opens) do
      table = Pokepoker.new
      table.set(:players => seats, :comcards => 0, :pot => 30, :select => 1)
      table.raise_loop = lambda { |scene| scene.set(:select => 2); scene.updateselect; scene.set(:select => 1) }
      opening = said { table.betscene }
      table.raise_loop = nil
      PokeAccess::Config.verbosity = :brief
      brief = said { table.betscene }
      PokeAccess::Config.verbosity = nil
      table.pokerdispose
      [opening, brief]
    end
    probe(:poker_chips_painted) do
      seats[1][0] = 470
      poker.updatechips(1)
      info = PokeAccess::Info.info_text
      seats[1][0] = 480
      poker.set(:pot => 30)
      info
    end
    probe(:poker_out_of_chips) do
      seats[2][2] = 0
      poker.updatechips(2)
      info = PokeAccess::Info.info_text
      seats[2][2] = 1
      info
    end
    probe(:poker_skips_who_folded) do
      poker.set(:playing => 2, :comcards => 1)
      said { poker.osubround; PokeAccess.say_dialogue("Jade checks.") }
    end
    probe(:poker_no_repeat) do
      poker.set(:playing => 1)
      said { poker.osubround; PokeAccess.say_dialogue("Nie calls.") }
    end
    probe(:poker_river) do
      poker.set(:playing => 0, :comcards => 3, :previousbet => 0, :player1bet => 0)
      said { poker.osubround; PokeAccess.say_dialogue("What will you do?") }
    end
    probe(:poker_showdown) { said { poker.roundwinner } }
    probe(:poker_menu) { [said { poker.updateselect }, said { poker.set(:select => 2); poker.updateselect }, said { poker.updatebet }] }
    probe(:poker_closed) { poker.pokerdispose; map_key.call }

    probe(:prices) { [PokeAccess::Data.item_name(:GOLDBOTTLECAP), PokeAccess::Data.item_name(:HEARTSCALE)] }

    # The Well Temple: EV61's self switches, the pits as Map686 and its tileset read (rows 59 to 77, # closed, r the paved floor), the
    # rocks' events where the map starts them, and the spikes (EV62, EV63).
    $game_self_switches = {}
    TEMPLE_ROWS = [
      "###########...#############...####",
      "########.........#######.........#",
      "########..#rr##..#######..rrr#r..#",
      "########..rrr##..#######..#r#rr..#",
      "########..rrrrr..#######..#rrr#..#",
      "########..###rr..#######..#rrrr..#",
      "########.........+#####+.........#",
      "########..rrrrr...#####...r#r#r..#",
      "########..#r##r...#####...rrrrr..#",
      "########..#r#rr...........r#r#r..#",
      "########..rrrrr...........rr#rr..#",
      "########........#########........#",
      "########..#r#r#.#########.rrrrr..#",
      "########..rr#r#.#########.rr#r#..#",
      "########..rrrrr.#########.#r#rr..#",
      "########..r#rr#.#########.rr#rr..#",
      "########........#########........#",
      "#########.......#########.......##",
      "############.###############.#####"
    ]
    TEMPLE_STARTS = { 49 => [13, 64], 50 => [11, 62], 51 => [14, 68], 52 => [11, 68], 53 => [11, 73], 54 => [11, 71],
                      55 => [28, 63], 56 => [29, 63], 57 => [26, 67], 58 => [28, 66], 59 => [30, 74], 60 => [29, 73] }
    class Game_Map
      attr_writer :map_id
      attr_accessor :temple_walls

      def temple_tile(x, y)
        row = y >= 59 ? TEMPLE_ROWS[y - 59] : nil
        row && x >= 0 ? row[x, 1].to_s : ""
      end

      def temple_open?(x, y)
        tile = temple_tile(x, y)
        !tile.empty? && tile != "#"
      end

      def terrain_tag(x, y); Struct.new(:id).new(temple_tile(x, y) == "r" ? :RoughFloor : :None); end

      alias_method :open_passable?, :passable?

      def passable?(x, y, dir)
        return open_passable?(x, y, dir) unless temple_walls
        nx = x + (dir == 6 ? 1 : (dir == 4 ? -1 : 0))
        ny = y + (dir == 2 ? 1 : (dir == 8 ? -1 : 0))
        temple_open?(nx, ny) && !blocking_event_at?(nx, ny)
      end
    end
    def temple_rock(id, x, y, map = $game_map)
      page = TestPage.new(:sprite => "Object_Boulder_Grey", :list => [TestCmd.new(355, ["pbPushThisSokoban"])], :trigger => 1)
      ev = TestGameEvent.new(:id => id, :name => "move bolder #{id - 48}", :x => x, :y => y, :pages => [page])
      ev.blocking = true
      def ev.passableStrict?(x, y, d)
        nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0))
        ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
        through || ($game_map.temple_open?(nx, ny) && !$game_map.blocking_event_at?(nx, ny))
      end
      map.events[id] = ev
    end
    def on_temple(map_id = 686, at = [12, 77])
      was = [$game_map.map_id, $game_player.x, $game_player.y]
      $game_map.map_id = map_id
      $game_player.x, $game_player.y = at
      $game_map.events.clear
      $game_self_switches = {}
      PokeAccess::World::Mechanics.forget
      TEMPLE_STARTS.each { |id, tile| temple_rock(id, tile[0], tile[1]) }
      World.next_frame
      yield
    ensure
      $game_map.events.clear
      $game_map.map_id, $game_player.x, $game_player.y = was
      World.next_frame
      PokeAccess::World::Mechanics.forget
    end
    # The block on the pits' real walls, with the spikes closed and the map's real size.
    def in_temple_walls(assist)
      size = [$game_map.width, $game_map.height]
      kept = PokeAccess::Config.puzzle_assist
      PokeAccess::Config.puzzle_assist = assist
      on_temple do
        $game_map.width = 70
        $game_map.height = 81
        $game_map.temple_walls = true
        [[62, 20, 68], [63, 20, 69]].each do |id, x, y|
          spike = TestGameEvent.new(:id => id, :name => "Spikes 1", :x => x, :y => y)
          spike.blocking = true
          $game_map.events[id] = spike
        end
        World.next_frame
        PokeAccess::Pathfinder.invalidate_cache(true)
        yield
      end
    ensure
      $game_map.temple_walls = false
      $game_map.width, $game_map.height = size
      PokeAccess::Config.puzzle_assist = kept
      PokeAccess::Pathfinder.invalidate_cache(true)
    end
    TEMPLE_WAYS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    def temple_rock_at(x, y)
      TEMPLE_STARTS.keys.map { |id| $game_map.events[id] }.find { |ev| ev.x == x && ev.y == y }
    end
    # One route of the planner played as the game plays it: its steps on foot, then its push, which leaves the player in place.
    # Answers nil, or what the game would not have done.
    def temple_follow(plan)
      plan.route.to_a.each do |way|
        x = $game_player.x + TEMPLE_WAYS[way][0]
        y = $game_player.y + TEMPLE_WAYS[way][1]
        return [:walked_into, x, y] unless $game_map.temple_open?(x, y) && !temple_rock_at(x, y)
        $game_player.x = x
        $game_player.y = y
      end
      gate = plan.gate
      return [:no_push] unless gate && gate[:ev]
      dx = gate[:x] - $game_player.x
      dy = gate[:y] - $game_player.y
      return [:push_from_afar, $game_player.x, $game_player.y, gate[:x], gate[:y]] unless dx.abs + dy.abs == 1
      x = gate[:x] + dx
      y = gate[:y] + dy
      return [:pushed_off_floor, x, y] unless $game_map.temple_tile(x, y) == "r" && !temple_rock_at(x, y)
      gate[:ev].x = x
      gate[:ev].y = y
      nil
    end
    # Plays each rock in its turn with the planner the guide uses: a row per rock, its id, how it ended and the pushes it took.
    def temple_play(rocks, door)
      $game_player.x, $game_player.y = door
      rocks.map do |rock|
        ev = $game_map.events[rock[0]]
        box = [rock[2], rock[3], rock[2], rock[3]]
        pushes = 0
        ended = nil
        until ended
          World.next_frame
          PokeAccess::Pathfinder.invalidate_cache(true)
          plan = PokeAccess::Routes::Planner.carried(ev, box)
          if plan.kind == :walk
            ended = :placed
          elsif plan.kind != :assisted
            ended = plan.kind
          else
            ended = temple_follow(plan)
            pushes += 1
            ended = :too_long if pushes > 60
          end
        end
        [rock[0], ended, pushes]
      end
    end
    def place_rocks(*ids)
      ids.each do |id|
        rock = (PokeAccess::AshenWellTemple::WINGS[0] + PokeAccess::AshenWellTemple::WINGS[1]).find { |r| r[0] == id }
        $game_map.events[id].x = rock[2]
        $game_map.events[id].y = rock[3]
      end
    end
    def temple_targets
      PokeAccess::Puzzles.category_targets.map { |t| [t.respond_to?(:key) ? t.key : t.id, t.x, t.y] }
    end
    probe(:temple_names) do
      on_temple do
        loc = PokeAccess::Locator
        other = TestGameEvent.new(:id => 200, :name => "Bandit", :x => 1, :y => 1)
        [loc.ruled_name($game_map.events[49]), loc.ruled_name($game_map.events[60]), loc.ruled_name(other)]
      end
    end
    probe(:temple_names_elsewhere) { on_temple(685) { PokeAccess::Locator.ruled_name($game_map.events[49]) } }
    probe(:temple_marks) do
      PokeAccess::AshenWellTemple::WINGS.flatten(1).map { |rock| [rock[0], [rock[2], rock[3]], rock[1]] }.sort_by { |row| row[0] }
    end
    probe(:temple_category) do
      on_temple do
        other = TestGameEvent.new(:id => 200, :name => "Bandit", :x => 1, :y => 1)
        other.character_name = "Character_Bandit"
        [PokeAccess::Locator.event_category($game_map.events[49]), PokeAccess::Locator.event_category(other)]
      end
    end
    probe(:temple_assist) do
      PokeAccess::Config.puzzle_assist = true
      out = on_temple do
        PokeAccess::Puzzles.tick
        [PokeAccess::Puzzles.info_line, temple_targets]
      end
      PokeAccess::Config.puzzle_assist = false
      out
    end
    probe(:temple_rule) do
      on_temple do
        fx = PokeAccess::Routes::Effects
        move, how, _pull, _dirs, ready = fx.push_facet(PokeAccess::World::Events.records.find { |r| r.ev.id == 49 })
        [move, how, ready.call(13, 63), ready.call(15, 63)]
      end
    end
    probe(:temple_arrival) { on_temple { said { PokeAccess::Puzzles.tick } } }
    probe(:temple_far_from_pits) do
      [[23, 12], [51, 78]].map do |at|
        on_temple(686, at) { [said { PokeAccess::Puzzles.tick }, PokeAccess::Puzzles.info_line, temple_targets] }
      end
    end
    probe(:temple_info_line) { on_temple { PokeAccess::Puzzles.tick; PokeAccess::Puzzles.info_line } }
    probe(:temple_right_door) do
      on_temple(686, [28, 77]) do
        cut_off = [said { PokeAccess::Puzzles.tick }, PokeAccess::Puzzles.info_line, temple_targets]
        $game_self_switches[[686, 61, "A"]] = true
        PokeAccess::World::Mechanics.forget
        opened = [said { PokeAccess::Puzzles.tick }, PokeAccess::Puzzles.info_line, temple_targets]
        [cut_off, opened]
      end
    end
    probe(:temple_done) do
      on_temple do
        $game_self_switches[[686, 61, "A"]] = true
        $game_self_switches[[686, 61, "B"]] = true
        [said { PokeAccess::Puzzles.tick }, PokeAccess::Puzzles.info_line]
      end
    end
    # Whether a way exists is what these ask, so the searches run past the state cap of a route asked in play (Pushes::NODES).
    def temple_uncapped
      pushes = PokeAccess::Routes::Pushes
      kept = pushes::NODES
      pushes.send(:remove_const, :NODES)
      pushes.const_set(:NODES, 20_000)
      PokeAccess::Config.route_limit = :none
      yield
    ensure
      PokeAccess::Config.route_limit = :effort
      pushes.send(:remove_const, :NODES)
      pushes.const_set(:NODES, kept)
    end
    probe(:temple_turns) do
      wings = PokeAccess::AshenWellTemple::WINGS
      temple_uncapped do
        in_temple_walls(false) do
          [temple_play(wings[0], [12, 77]), temple_play(wings[1], [28, 77]),
           (wings[0] + wings[1]).all? { |rock| PokeAccess::AshenWellTemple.placed?(rock) }]
        end
      end
    end
    probe(:temple_turns_assisted) do
      temple_uncapped { in_temple_walls(true) { temple_play(PokeAccess::AshenWellTemple::WINGS[1], [28, 77]) } }
    end
    probe(:temple_grey_first) do
      grey_first = PokeAccess::AshenWellTemple::WINGS[1].sort_by { |rock| rock[0] }
      temple_uncapped { in_temple_walls(false) { temple_play(grey_first, [28, 77]) } }
    end

    # The flying game: its control event sends the obstacles, each changing its graphic as its route starts.
    class TestGameEvent; attr_accessor :move_route_forcing; end
    def on_flight(map_id = 551)
      was = [$game_map.map_id, $game_player.x, $game_player.y]
      $game_map.map_id = map_id
      $game_player.x = 13
      $game_player.y = 6
      $game_map.events.clear
      PokeAccess::World::Mechanics.forget
      page = TestPage.new(:trigger => 2, :through => true)
      [[2, 23, 3], [3, 23, 6], [4, 23, 9]].each do |id, x, y|
        $game_map.events[id] = TestGameEvent.new(:id => id, :name => "A", :x => x, :y => y, :pages => [page])
        $game_map.events[id].move_route_forcing = true
      end
      World.next_frame
      yield
    ensure
      $game_map.events.clear
      $game_map.map_id, $game_player.x, $game_player.y = was
      World.next_frame
      PokeAccess::World::Mechanics.forget
    end
    probe(:fly_no_graphic_yet) do
      on_flight { $game_map.events.values.map { |ev| PokeAccess::Sound::Scene.family_of(ev) } }
    end
    probe(:fly_sonar) do
      on_flight do
        PokeAccess::World::Events.sync
        $game_map.events.values.each { |ev| ev.character_name = "Flying_Game_Bird_A" }
        World.next_frame
        PokeAccess::World::Events.sync
        families = $game_map.events.values.map { |ev| PokeAccess::Sound::Scene.family_of(ev) }
        PokeAccess::Sound::Scene.scan($game_player.x, $game_player.y)
        heard = PokeAccess::Sound::Scene.emitters[:trap]
        still = PokeAccess::Sound::Scene.moved?($game_player.x, $game_player.y)
        $game_map.events[3].x = 22
        moved = PokeAccess::Sound::Scene.moved?($game_player.x, $game_player.y)
        [families, heard, still, moved, PokeAccess::Sound::Scene.occlusion_mode, PokeAccess::Sound::Mixer.ping_seconds(:trap)]
      end
    end
    probe(:fly_only_coming) do
      page = TestPage.new(:trigger => 2, :through => true)
      wave = { 2 => [19, 6, true], 3 => [12, 6, true], 4 => [11, 3, true], 5 => [13, 9, true], 6 => [24, 6, false], 7 => [15, 6, false],
               8 => [1, 9, false], 9 => [22, 3, true] }
      on_flight do
        $game_map.events.clear
        wave.each do |id, (x, y, running)|
          ev = TestGameEvent.new(:id => id, :name => "A", :x => x, :y => y, :pages => [page])
          ev.character_name = "Flying_Game_Bird_A"
          ev.move_route_forcing = running
          $game_map.events[id] = ev
        end
        World.next_frame
        PokeAccess::World::Events.sync
        scene = PokeAccess::Sound::Scene
        scene.scan($game_player.x, $game_player.y)
        coming = scene.emitters[:trap]
        $game_player.x = 10
        scene.scan($game_player.x, $game_player.y)
        further_back = scene.emitters[:trap]
        $game_map.events.values.each { |ev| ev.move_route_forcing = false }
        scene.scan($game_player.x, $game_player.y)
        [coming, further_back, scene.emitters[:trap]]
      end
    end
    probe(:fly_turning_back) do
      page = TestPage.new(:trigger => 2, :through => true)
      step = Struct.new(:code)
      route = Struct.new(:list)
      on_flight do
        $game_map.events.clear
        behind = $game_player.x - 1
        [[2, 2, [[8, 2], 0]], [3, 4, [[8, 2], 1]], [4, 6, [[13, 2], 0]], [5, 8, [[2, 2], 0]]].each do |id, y, (codes, at)|
          ev = TestGameEvent.new(:id => id, :name => "A", :x => behind, :y => y, :pages => [page])
          ev.character_name = "Flying_Game_Bird_A"
          ev.move_route_forcing = true
          ev.instance_variable_set(:@move_route, route.new(codes.map { |c| step.new(c) }))
          ev.instance_variable_set(:@move_route_index, at)
          $game_map.events[id] = ev
        end
        World.next_frame
        PokeAccess::World::Events.sync
        scene = PokeAccess::Sound::Scene
        scene.scan($game_player.x, $game_player.y)
        [scene.emitters[:trap], behind]
      end
    end
    probe(:fly_near_quiet) do
      page = TestPage.new(:trigger => 2, :through => true)
      on_flight do
        $game_map.events.clear
        ev = TestGameEvent.new(:id => 2, :name => "A", :x => $game_player.x + 1, :y => $game_player.y, :pages => [page])
        ev.character_name = "Flying_Game_Bird_A"
        ev.move_route_forcing = true
        $game_map.events[2] = ev
        World.next_frame
        PokeAccess::World::Events.sync
        said { PokeAccess::Puzzles.tick; PokeAccess::Puzzles.tick }
      end
    end
    probe(:fly_safe_tile) { PokeAccess::AshenFlying::SAFE_TILE }
    probe(:fly_elsewhere) do
      [PokeAccess::Sound::Scene.occlusion_mode, PokeAccess::Sound::Mixer.ping_seconds(:trap) > PokeAccess::AshenFlying::PING_SECONDS]
    end
    probe(:fly_other_sounds) { on_flight { PokeAccess::Sound::Mixer.ping_seconds(:hazard) > PokeAccess::AshenFlying::PING_SECONDS } }
    probe(:fly_all_maps) { [551, 654, 703, 552].map { |m| on_flight(m) { PokeAccess::Sound::Scene.occlusion_mode } } }
    probe(:fly_key) do
      pictures = Array.new(51) { Game_Picture.new }
      pictures[2].show("Flying_Health_3", 0, 0, 0, 100, 100, 255, 0)
      $game_screen = Struct.new(:pictures).new(pictures)
      out = on_flight do
        arrived = said { PokeAccess::Puzzles.tick }
        plain = PokeAccess::Puzzles.info_line
        PokeAccess::Config.puzzle_assist = true
        far = PokeAccess::Puzzles.info_line
        $game_player.x = 12
        $game_player.y = 8
        on_it = PokeAccess::Puzzles.info_line
        PokeAccess::Config.puzzle_assist = false
        [arrived, plain, far, on_it]
      end
      $game_screen = nil
      out
    end
    probe(:temple_phases) do
      on_temple do
        PokeAccess::Puzzles.tick
        first = [PokeAccess::AshenWellTemple.next_rock[0], temple_targets, PokeAccess::Puzzles.info_line]
        place_rocks(49)
        moved = said { PokeAccess::Puzzles.tick }.map { |l| l[0] }
        second = [PokeAccess::AshenWellTemple.next_rock[0], temple_targets]
        place_rocks(50, 51, 52, 53, 54)
        last = PokeAccess::AshenWellTemple.next_rock
        $game_self_switches[[686, 61, "A"]] = true
        right = PokeAccess::AshenWellTemple.next_rock[0]
        $game_self_switches[[686, 61, "B"]] = true
        [first, moved, second, last, right, PokeAccess::AshenWellTemple.next_rock, PokeAccess::AshenWellTemple.wing]
      end
    end

    # With the key hints left out.
    probe(:no_hints) do
      PokeAccess::Config.verbosity = :brief
      out = {
        :sheet => said { pbEventScreen(SongRed) },
        :bag => said { PokemonBag_Scene.new.pbStartScene(nil) },
        :map => said { PokemonRegionMap_Scene.new("switcher" => Object.new, "mapbottom" => MapBottom.new("R")).pbStartScene }.map { |l| l[0] },
        :tabs => said { CaseUI_Menu_Scene.new.pbScene },
        :plate => said { pbEventScreen(PlateFlame); PokeAccess.say_dialogue("Words of a plate.") },
        :clue => said { CaseUI_Evidence.new([:CLUESAFE]).draw_list }
      }
      PokeAccess::Config.verbosity = nil
      out
    end

    # The journal's second page, whose reward the game paints as nothing while the quest runs.
    Quest = Struct.new(:id, :stage, :location, :time)
    $quest_data = Object.new
    def $quest_data.getQuestReward(_id); "A Rare Candy"; end
    def $quest_data.getMaxStagesForQuest(_id); 3; end
    def $quest_data.getQuestGiver(_id); "Eloise"; end
    $active_quests = []
    def getActiveQuests; $active_quests; end
    def getCompletedQuests; []; end
    probe(:quest_running) do
      $active_quests = [7]
      PokeAccess::QuestUI.other_lines(Quest.new(7, 1, "Riverview", nil), 7)
    end
    probe(:quest_done) do
      $active_quests = []
      PokeAccess::QuestUI.other_lines(Quest.new(7, 1, "Riverview", nil), 7)
    end
  RUBY

  profile "ashenfrost", WORLD, PLAY, "gamedata"

  test "loads whole and binds what it declares" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
    assert_equal "ashenfrost", played(:profile_name)
    assert played(:plain)
  end

  test "the game's own buttons go where the mod's modifiers do not reach, and its letters are declared" do
    assert_equal [:D, :F], played(:remap)
    assert_equal :r, played(:letters)["W"]
    assert_equal :a, played(:letters)["Z"]
  end

  test "its battle weathers have their names" do
    assert_equal [:ashen_w_freezing_rain, :ashen_w_frozen_storm, :ashen_w_holy_inferno, :ashen_w_solar_winds].map { |k| t(k) },
                 played(:weather)
  end

  test "the trainer line says the case and the level cap its panels paint" do
    assert_equal [t(:ashen_case_number, :n => 4), t(:ashen_level_cap, :n => 15)], played(:trainer_parts)
    assert_includes played(:trainer_order), :case_file
    assert_includes played(:trainer_order), :level_cap
  end

  test "the pause box, set on every frame of the menu, is said once, each value with its label" do
    assert_equal [["Aurora Downs, Money: $1,200, Level Cap: 15", false]], played(:pause_frames)
  end

  test "the pause box is said again on the next opening, and when it changes" do
    assert_equal [["Aurora Downs, Money: $1,200, Level Cap: 15", false]], played(:pause_again)
    assert_equal [["Aurora Downs, Money: $900, Level Cap: 15", false]], played(:pause_change)
  end

  test "the evidence screen opens on the count it paints and the piece, as painted, queued" do
    line = played(:ev_first)
    assert_equal 1, line.length
    assert_equal false, line[0][1]
    assert_match(/\AFound: 3\/5\. Postcard Clue/, line[0][0])
    assert_match(/Obtained: Case Fourteen's Hall, For: Reading Luciano's Papers\.,? ?A postcard\./, line[0][0])
    assert_includes line[0][0], t(:ashen_ev_examine, :key => "Z")
  end

  test "asked to present, it says so first" do
    assert played(:ev_present)[0][0].start_with?("#{t(:ashen_ev_present)} Found: 3/5.")
  end

  test "a case with no evidence says so" do
    assert_equal [["Found: 0/5. #{t(:ashen_ev_none)}", false]], played(:ev_empty)
  end

  test "the cursor's moves cut in, a testimony has no examine key and a place in the list is said" do
    line = played(:ev_moves)
    assert_equal 1, line.length
    assert_equal true, line[0][1]
    assert line[0][0].start_with?("Jade's Testimony, 2")
    refute_includes line[0][0], t(:ashen_ev_examine, :key => "Z")
    assert_includes played(:ev_next_is_a_clue)[0][0], t(:ashen_ev_examine, :key => "Z")
  end

  test "the info key holds the piece whole" do
    info, row = played(:ev_info)
    assert_includes info, "She was with Sammy."
    assert_equal info, row
  end

  test "an examined clue says its picture's description, and the info key has it until it closes" do
    assert played(:ev_examine)[0][0].start_with?(t(:ashen_clue_safe))
    assert_equal true, played(:ev_examine)[0][1]
    assert_includes played(:ev_examine)[0][0], t(:ashen_doc_close, :key => "C")
    assert_includes played(:ev_examine_info), "Safe Clue"
  end

  test "a clue with words says them, and closing brings the info key back to the piece" do
    assert played(:ev_clue_examine)[0][0].start_with?("Lucy, Here we are in Johto!")
    assert_includes played(:ev_clue_row_back), "Postcard Clue"
  end

  test "closing the evidence forgets its line" do
    assert_equal "", played(:ev_closed).sub(PokeAccess::Info.trainer_info.to_s, "") if played(:ev_closed).include?("Safe Clue")
    refute_includes played(:ev_closed), "Safe Clue"
  end

  test "the list of cases opens on its title and its row, each once, queued" do
    assert_equal [["Main Cases", false], ["Case One: Safety First", false]], played(:case_opening)
  end

  test "back on the list from a case, its row is said again" do
    assert_equal [["Case One: Safety First", false]], played(:case_back)
  end

  test "a change of tab says the tab once and then its first row, queued, wherever the cursor was" do
    want = [["Side Cases", true], ["The River's Base", false]]
    assert_equal want, played(:case_tab)
    assert_equal want, played(:case_tab_from_a_row)
  end

  test "with side cases, the keys of the tabs are said once a screen" do
    first, second = played(:case_hint)
    assert_includes first, [t(:ashen_case_tabs), false]
    refute_includes second, [t(:ashen_case_tabs), false]
  end

  test "a newspaper and a letter are transcribed, with the key that closes them, and stay on the info key" do
    line = played(:doc_newspaper)[0]
    assert line[0].start_with?("The Sunday Scolipede. FIGHT ON THE ROOFTOP.")
    assert line[0].end_with?(t(:ashen_doc_close, :key => "C"))
    assert played(:doc_newspaper_info).start_with?("The Sunday Scolipede.")
    refute_includes played(:doc_closed), "The Sunday Scolipede."
    assert played(:doc_letter)[0][0].start_with?("I can't do it anymore")
  end

  test "a sheet says its notes in words, and the key that closes it" do
    red, blue, eight = played(:doc_sheets).map { |l| l[0][0] }
    assert_includes red, "Play Along! #{%w[up right right down].map { |d| t("dir_#{d}".to_sym) }.join(', ')}"
    assert_includes blue, "Play Along! #{%w[left down right left].map { |d| t("dir_#{d}".to_sym) }.join(', ')}"
    assert_includes eight, %w[left down down down left right down right up right].map { |d| t("dir_#{d}".to_sym) }.join(", ")
    assert_includes red, t(:ashen_doc_close, :key => "X")
  end

  test "Case 13's newspaper says each page as it turns, and that the key turns it until the last closes it" do
    pages = played(:doc_pages).map { |l| l[0][0] }
    assert pages[0].start_with?("Riverview This Week.")
    assert pages[1].start_with?("The Severn Comet.")
    assert pages[2].start_with?("The Daily Pelipper.")
    assert pages[0].end_with?(t(:ashen_doc_next, :key => "C"))
    assert pages[1].end_with?(t(:ashen_doc_next, :key => "C"))
    assert pages[2].end_with?(t(:ashen_doc_close, :key => "C"))
  end

  test "a clue's words are the picture's, and what it only shows comes from the language files" do
    list, post, letter, grad = played(:clue_words)
    assert_equal "1. PEW's? 2. Lawyer's? 3. Lulu's? 4. Bolt. #{t(:ashen_clue_crossed)}", list
    refute_includes post, "To:"
    assert_includes post, "Luciano Meri, 84 Aurora Street"
    refute_includes letter, "Signed"
    assert letter.end_with?("Bruce Serenity.")
    assert_equal t(:ashen_clue_grad), grad
  end

  test "every clue with no words has a description of its own" do
    assert_equal played(:clue_views).length, played(:clue_views).uniq.length
  end

  test "a plate leaves its words to its message, and adds the key that closes it behind them" do
    assert_equal [], played(:doc_plate_alone)
    lines = played(:doc_plate_message).map { |l| l[0] }
    assert_equal "The power of defeated giants infuses this Plate.", lines[0]
    assert_includes lines[1].to_s, t(:ashen_doc_close, :key => "X")
  end

  test "a case's title is said on its first letter's picture, by the name the Case File gives it" do
    base, first, second, one, half, five, six = played(:pic_titles)
    assert_equal [], base
    assert_equal [["Case Two: Man's Greatest Vice", true]], first
    assert_equal [], second
    assert_equal [["Case One: Safety First", true]], one
    assert_equal [["Case Three-and-a-Half: Mordecai's Marvelous Misadventure", true]], half
  end

  test "the titles whose last frame paints other words than the Case File are said as painted" do
    _base, _first, _second, _one, _half, five, six = played(:pic_titles)
    assert_equal [["Case Five: Lu³", true]], five
    assert_equal [["Case Six: Lafayettes, Lonardos, Palermos", true]], six
  end

  test "the pictures that count are said, queued" do
    assert_equal [[[t(:ashen_court_lives, :n => 2), false]], [[t(:ashen_fly_health, :n => 3), false]],
                  [[t(:ashen_fly_health, :n => 1), false]], [[t(:ashen_hp_player, :n => 4), false]],
                  [[t(:ashen_hp_girl, :n => 0), false]]], played(:pic_counts)
  end

  test "a picture loaded out of sight is said as it starts to fade in, once" do
    loaded, still_out, up, again = played(:pic_unseen)
    assert_equal [], loaded, "the game loads it messages ahead"
    assert_equal [], still_out
    assert_equal [[t(:ashen_pic_rockruff_1), false]], up
    assert_equal [], again
  end

  test "a picture erased before it was seen is never said, not even by a fade after it" do
    assert_equal [], played(:pic_never_seen)
  end

  test "each picture out of sight waits on its own number, for the one that fades in" do
    assert_equal [[t(:ashen_pic_memory_spa), false], [t(:ashen_pic_rockruff_1), false]], played(:pic_unseen_apart)
  end

  test "a picture shown in sight replaces the one loaded out of sight on its number" do
    assert_equal [[t(:ashen_pic_memory_spa), false]], played(:pic_unseen_replaced)
  end

  test "a picture left faded and shown again by another event is said again, and a blink is not" do
    first, faded, second = played(:pic_faded_says_again)
    line = [[t(:ashen_pic_tv_sparky, :text => "OP QR ST, U"), false]]
    assert_equal line, first
    assert_equal [], faded
    assert_equal line, second
    assert_equal [["Start!", false]], played(:pic_blink)
  end

  test "a case's title loaded out of sight waits for its fade too" do
    loaded, up = played(:pic_unseen_title)
    assert_equal [], loaded
    assert_equal [["Case One: Safety First", true]], up
  end

  test "the pictures with words say them and the rest what they show, all queued" do
    words = played(:pic_words)
    assert_equal [[["Cleared!", false]], [["The Copper Ball", false]], [["Riverview Crossword: Priya, Silva.", false]],
                  [[t(:ashen_picture_research), false]]], words
  end

  test "the pictures of events no game state reaches, the plain backdrops and the wipes say nothing" do
    assert_equal [[], [], [], [], [], []], played(:pic_dead)
  end

  test "the flying game says its border, health and start in the frame they share, none cutting the last" do
    assert_equal [["Mordecai + Fearow. Level: 1.", false], [t(:ashen_fly_health, :n => 5), false], ["Start!", false]], played(:pic_flying)
    assert_equal [[t(:ashen_fly_health, :n => 0), false], ["Failed!", false]], played(:pic_flying_end)
  end

  test "a flying game's picture left up holds neither the locator nor its sounds" do
    showing, free, keys, texts = played(:fly_free)
    assert_equal false, showing
    assert_equal true, free
    assert_equal true, keys
    assert_equal [], texts, "no picture of this game is a menu of pictures"
  end

  test "a series of frames of one drawing is said once, until a picture is erased" do
    assert_equal [[t(:ashen_pic_lon), false], [t(:ashen_pic_static), false]], played(:pic_series)
    first, second = played(:pic_series_again)
    assert_equal [[t(:ashen_pic_lon), false]], first
    assert_equal [], second
    said, again, after = played(:pic_erased_says_again)
    assert_equal said, after
    assert_equal [], again
    assert said[0][0].start_with?("Iodine,")
  end

  test "words painted inside a picture go into its description untranslated" do
    young, culprit, poster = played(:pic_painted_inside)
    assert_equal [[t(:ashen_pic_young, :text => "Lose it all!"), false]], young
    assert_equal [[t(:ashen_pic_culprit_n, :text => 3), false]], culprit
    assert_equal [[t(:ashen_pic_tv_sparky, :text => "OP QR ST, U"), false]], poster
  end

  test "the brief verbosity drops what a picture shows, not what it paints or tells" do
    art, inventory, words = played(:pic_brief)
    assert_equal [], art
    assert_equal [[t(:ashen_pic_inv_rolls), false]], inventory
    assert_equal [["Start!", false]], words
  end

  test "every entry of the tables has its words" do
    bad = played(:pic_table_words).select { |w| w.to_s.empty? || w.to_s =~ /\Aashen_|%\{/ }
    assert_equal [], bad
  end

  test "a word of the crossword says its place, length and written letters as its screen opens, never the answer" do
    actress, villain, tech, sport, other = played(:xw).map { |l| l[0] }
    down = t(:ashen_xw_down)
    across = t(:ashen_xw_across)
    assert_equal ["#{t(:ashen_xw_word, :n => 1, :way => down, :len => 5)} #{t(:ashen_xw_shared, :n => 5, :w => 2, :way => across)}", false], actress
    assert_equal ["#{t(:ashen_xw_word, :n => 2, :way => across, :len => 5)} #{t(:ashen_xw_known, :n => 5, :c => "A")} " \
                  "#{t(:ashen_xw_shared, :n => 1, :w => 2, :way => down)}", false], villain
    assert_includes tech[0], t(:ashen_xw_known, :n => 2, :c => "E")
    assert_includes tech[0], t(:ashen_xw_shared, :n => 7, :w => 2, :way => down)
    assert_equal ["#{t(:ashen_xw_word, :n => 2, :way => down, :len => 7)} #{t(:ashen_xw_known, :n => 1, :c => "S")} " \
                  "#{t(:ashen_xw_known, :n => 4, :c => "T")} #{t(:ashen_xw_known, :n => 7, :c => "G")}", false], sport
    assert_equal [t(:ashen_letters, :n => 3), false], other
  end

  test "the info key has the word being asked from its picture coming up to the end of its screen" do
    unasked, asked, passed, closed, done, reset = played(:xw_info)
    line = "#{t(:ashen_xw_word, :n => 2, :way => t(:ashen_xw_across), :len => 5)} #{t(:ashen_xw_known, :n => 5, :c => "A")} " \
           "#{t(:ashen_xw_shared, :n => 1, :w => 2, :way => t(:ashen_xw_down))}"
    refute_includes unasked, line, "the picture is not up yet"
    assert_equal line, asked
    assert_equal false, passed, "the game's answer goes through"
    refute_includes closed, line
    refute_includes done, t(:ashen_xw_word, :n => 2, :way => t(:ashen_xw_across), :len => 5), "the last picture asks nothing"
    refute_includes reset, t(:ashen_xw_word, :n => 1, :way => t(:ashen_xw_down), :len => 5), "a reset of the game drops it"
  end

  test "a choice Hart's cutscene plays out is said once, however its cursor moves" do
    first, *rest = played(:pic_hart)
    assert first[0][0].include?("Why is your face bandaged?")
    assert_equal false, first[0][1], "queued, behind the line before it"
    assert_equal [[], [], []], rest
  end

  test "Blackjack says each card as it is turned up, and the sum behind the player's" do
    a, b, again, c, hidden, opened, bet, fresh = played(:bj_hand)
    king = t(:vp_card_bare, :value => t(:vp_king), :suit => t(:vp_spades))
    assert_equal [[t(:ashen_bj_you, :card => t(:vp_card_bare, :value => "4", :suit => t(:vp_hearts))), false], ["Card Sum: 8", false]], a
    assert_equal [[t(:ashen_bj_you, :card => t(:vp_card_bare, :value => "J".sub("J", t(:vp_jack)), :suit => t(:vp_diamonds))), false],
                  ["Card Sum: 19", false]], b
    assert_equal [], again, "a redraw of a card says nothing"
    assert_equal [[t(:ashen_bj_dealer, :card => t(:vp_card_bare, :value => t(:vp_ace), :suit => t(:vp_clubs))), false]], c
    assert_equal [], hidden, "the dealer's face-down card"
    assert_equal [[t(:ashen_bj_dealer, :card => king), false]], opened
    assert_equal [["Bet: 5", false]], bet
    assert_equal 2, fresh.length, "a new hand says its cards again"
  end

  test "Blackjack's info key keeps the cards in sight, the sum and the bet until the game ends" do
    shown, closed = played(:bj_info)
    assert_includes shown, t(:pkr_your_hand, :list => t(:vp_card_bare, :value => "4", :suit => t(:vp_hearts)))
    assert_includes shown, "Card Sum: 8"
    assert_includes shown, t(:ashen_bj_dealer_hand, :list => t(:vp_card_bare, :value => t(:vp_ace), :suit => t(:vp_clubs)))
    refute_includes shown, t(:vp_king), "the dealer's face-down card"
    assert_includes shown, "Bet: 5"
    refute_includes closed, "Card Sum: 8"
  end

  test "Blackjack's info key follows the sum and the bet as they are painted" do
    sum, bet = played(:bj_info_painted)
    assert_includes sum, "Card Sum: 11"
    assert_includes bet, "Bet: 5"
  end

  test "cancelling Tutor.net's grid says the list's row again, and choosing does not" do
    lines, cursor = played(:tutor_cancel)
    assert_equal 3, lines.length
    assert_equal lines[0], lines[2]
    assert_nil cursor
    assert_equal 1, played(:tutor_chosen)
  end

  test "leaving Tutor.net leaves no move on the info key" do
    assert_nil played(:tutor_end_clears)
  end

  test "Tutor.net's filter leaves the list it is about to close to no reader, for the new list to say its first move once" do
    assert_equal [false, true], played(:tutor_filter_list)
  end

  test "back on Tutor.net's list after refusing a move, its name is said again with the rest of the row" do
    assert_nil played(:tutor_back_on_list)
  end

  test "before the first hand's round starts, poker owes nothing yet" do
    info = played(:poker_first_deal)
    refute_includes info, t(:pkr_owed, :n => 10)
  end

  test "a list with no moves says so" do
    assert_equal [[t(:ashen_tutor_empty), false]], played(:tutor_empty)
  end

  test "Tutor.net's welcome is said with the key its button is on, not the one it names" do
    assert_equal "By pressing the AUX2 button (default: W), you can filter the move list.", played(:aux2)[0][0]
  end

  test "Tutor.net adds the type, the price and who it suits, queued behind the move's name" do
    line = played(:tutor_money)
    assert_equal false, line[0][1]
    assert_includes line[0][0], "$1500"
    assert_includes line[0][0], t(:tut_can_list, :names => "Truffles")
    assert_includes line[0][0], t(:tut_knows_list, :names => "Nie")
    typed, type = played(:tutor_type)
    assert_includes typed[0][0], type.to_s
    refute_equal "", played(:tutor_info).to_s
    assert_includes played(:tutor_free_nobody)[0][0], t(:tut_nobody)
    refute_includes played(:tutor_free_nobody)[0][0], "$"
  end

  test "Tutor.net says a price in bottle caps or an item as the icons paint it" do
    caps, scale = played(:prices)
    assert_includes played(:tutor_coins)[0][0], t(:ashen_tutor_price, :n => 100, :item => caps)
    assert_includes played(:tutor_item)[0][0], t(:ashen_tutor_price, :n => 3, :item => scale)
  end

  test "Tutor.net says each row once, and nothing on the filter's repaint or outside the list's loop" do
    assert_equal 1, played(:tutor_once).length
    assert_equal [], played(:tutor_filter_repaint)
    assert_equal [], played(:tutor_outside_loop)
  end

  test "Tutor.net's grid says each member and its icon" do
    open, same, other = played(:tutor_grid)
    assert_equal [["Nie, #{t(:tut_knows)}", true]], open
    assert_equal [["Truffles, #{t(:tut_can)}", true]], same
    assert_equal [["Egg", true]], other
  end

  test "remembering a move reads the list as the relearner's, its title first, and its questions" do
    first, moved, asked, dedicated = played(:remember)
    assert first[0][0].start_with?("Teach which move?")
    refute_includes moved[0][0], "Teach which move?"
    assert_equal [["Teach Tackle?", false]], asked.map { |l| [l[0], false] }
    assert dedicated
    assert_equal "", played(:remember_closed).sub(/.*/, "") if played(:remember_closed).empty?
  end

  test "the new-game options say their title once and keep each option's help on the info key" do
    title, help = played(:intro_options)
    assert_equal [["Options", false]], title
    assert_equal "Choose the difficulty you'd like to play on.", help
  end

  test "swapping the map's sheet says its name, cleaned, and the square is free to be said again" do
    said, cursor = played(:sheet_swap)
    assert_equal [["Riverview Island", false]], said
    assert_nil cursor
  end

  test "the map's sheet keys are said only where there are sheets" do
    with, without = played(:sheet_hint)
    assert_includes with, t(:ashen_map_sheets, :up => "A", :down => "S")
    refute_includes without, t(:ashen_map_sheets, :up => "A", :down => "S")
  end

  test "sorting the bag says so, and its key is said as it opens" do
    assert_equal [[t(:ashen_bag_sorted), true]], played(:bag_sorted)
    assert_equal [[t(:ashen_bag_sort, :key => "W"), false]], played(:bag_hint)
  end

  test "the bank's window is said as the money's, and its code leaves nothing in the message" do
    assert_equal [["Bank: $500", false]], played(:bank_window)
    assert_equal "ATM: Insufficient funds.", played(:atm_message)
  end

  test "the engine's mouse-only window of controls says so" do
    assert_equal [[t(:ashen_controls_window), true]], played(:controls_window)
  end

  test "the flying game's obstacles sound only once their routes give them a graphic, as moving traps" do
    assert_equal [nil, nil, nil], played(:fly_no_graphic_yet)
    families, = played(:fly_sonar)
    assert_equal [:trap, :trap, :trap], families
  end

  test "the flying game's obstacles are heard through the edge of its box, and followed as they move with the player still" do
    _families, heard, still, moved = played(:fly_sonar)
    assert_includes heard, [23, 6]
    assert_equal false, still
    assert_equal true, moved, "a route moves them, no page of theirs"
  end

  test "the flying game's obstacles sound far oftener, on its maps and for them alone" do
    _families, _heard, _still, _moved, mode, ping = played(:fly_sonar)
    assert_equal :hear, mode
    assert_equal 0.3, ping
    assert_equal [:hide, true], played(:fly_elsewhere)
    assert_equal true, played(:fly_other_sounds)
    assert_equal [:hear, :hear, :hear, :hide], played(:fly_all_maps)
  end

  test "only the obstacles on their way sound: not those that passed, however near, nor those whose routes ended" do
    coming, further_back, none = played(:fly_only_coming)
    assert_equal [[19, 6], [22, 3]], coming
    assert_includes further_back, [12, 6], "ahead of the player where they stand now"
    refute_includes further_back, [15, 6], "its route has ended, however far ahead"
    assert_nil none, "all the routes ended"
  end

  test "an obstacle past the player's column sounds while its route has yet to turn back, and not after" do
    heard, behind = played(:fly_turning_back)
    assert_equal [[behind, 2], [behind, 6]], heard.sort
  end

  test "the flying game says nothing of an obstacle beside the player, too late to dodge" do
    assert_empty played(:fly_near_quiet).select { |line, _cut| line.include?(t(:side_right)) }
  end

  test "the safe tile is one the routes of the three maps never cross" do
    x, y = played(:fly_safe_tile)
    assert_equal ".", FLY_BOX_CROSSED[y - 3][x - 10, 1]
  end

  test "the flying game says what to do on arriving, and its key the health painted and the rule" do
    arrived, plain, far, on_it = played(:fly_key)
    rule = t(:ashen_fly_rule)
    assert_equal [[rule, false]], arrived
    assert_equal "#{t(:ashen_fly_health, :n => 3)}. #{rule}", plain
    assert_includes far, t(:ashen_fly_safe, :dist => "1 #{t(:dir_left)}, 2 #{t(:dir_down)}"), "the assist's hint"
    assert_includes on_it, t(:ashen_fly_safe_here)
    refute_includes plain, t(:ashen_fly_safe_here)
  end

  test "a switch of protagonist is said, and a call on the one in play is not" do
    same, other = played(:switched)
    assert_equal [], same
    assert_equal [[t(:ashen_now_playing, :name => "Mordecai"), false]], other
  end

  test "the ocarina says its opening and each note with its place, only while the melody runs" do
    notes, after, opening = played(:ocarina)
    assert_equal [[[t(:oca_note, :n => 1, :dir => t(:dir_up)), true]], [],
                  [[t(:oca_note, :n => 2, :dir => t(:dir_right)), true]]], notes
    assert_equal [], after
    assert_includes opening.map { |l| l[0] }.join(" "), t(:oca_open)
  end

  test "the racecourse says each step's title and row, its bets and the lane that won" do
    lines = played(:racecourse).map { |l| l.map { |row| row[0] } }
    assert_equal ["#{t(:rc_menu)}. #{t(:rc_play)}"], lines[0].map { |x| x.sub(/\.\z/, "") }
    assert_equal [t(:rc_quit)], lines[1]
    assert_includes lines[2][0], t(:rc_pick_runner)
    assert_includes lines[3][0], "Gastrodon".downcase.capitalize.sub("Gastrodon", PokeAccess::Data.species_name(:GASTRODON).to_s)
    assert_includes lines[4][0], t(:rc_pick_wager)
    assert_includes lines[4][0], t(:mg_coins, :n => 77)
    assert_includes lines[4][0], t(:vp_wager, :n => 12)
    assert_includes lines[5][0], t(:rc_lane, :n => 3)
    assert_equal [t(:rc_running)], lines[6]
    assert_equal [], lines[7]
    assert_equal [t(:rc_winner, :n => 3)], lines[8]
    assert_includes lines[9][0], t(:rc_continue)
    assert_equal [t(:rc_no)], lines[10]
    assert_equal [], lines[11], "nothing while the cursor stays"
    assert_equal [[t(:rc_tie)]], played(:racecourse_tie).map { |l| l.map { |row| row[0] } }
    assert_equal [[]], played(:racecourse_no_menu), "no coin case: only the game's message"
  end

  test "the wager's box of coins opens and closes on its key, which is said with the way out, and the info key keeps the row" do
    lines, info, closed = played(:racecourse_box)
    keys = t(:rc_wager_keys, :a => "Z", :b => "X")
    assert_includes lines[0][0][0], t(:mg_coins, :n => 77)
    assert_includes lines[0][0][0], keys
    assert_equal [[PokeAccess.sentences([t(:mg_coins, :n => 77), t(:vp_wager, :n => 1)]), true]], lines[1]
    assert_equal [[PokeAccess.sentences([t(:mg_coins, :n => 77), t(:vp_wager, :n => 12)]), true]], lines[2]
    assert_equal [[t(:vp_wager, :n => 12), true]], lines[3]
    assert_includes info[3], t(:rc_pick_wager)
    assert_includes info[3], t(:mg_coins, :n => 77)
    assert_includes info[3], t(:vp_wager, :n => 12)
    refute_includes closed, t(:rc_pick_wager)
  end

  test "the racecourse's wager works where the game keeps no coins" do
    assert_includes played(:racecourse_no_coins)[0][0][0], t(:vp_wager, :n => 5)
    refute_includes played(:racecourse_no_coins)[0][0][0], t(:mg_coins, :n => 0)
  end

  test "poker says the hand as it is dealt, in the reader's language, queued" do
    assert_equal [[t(:pkr_your_hand, :list => hole_cards), false]], played(:poker_dealt)
  end

  test "the second hand's deal keeps the table's new cards out of the info key until they turn" do
    blind_message, blind_posted, flop = played(:poker_second_hand)
    hidden = [card(7, :vp_diamonds), card(7, :vp_clubs), card(7, :vp_hearts), card(7, :vp_spades), card(10, :vp_hearts)]
    [blind_message, blind_posted].each do |info|
      assert_includes info, t(:pkr_your_hand, :list => "#{card(3, :vp_spades)}, #{card(4, :vp_hearts)}")
      hidden.each { |face| refute_includes info, face }
      refute_includes info, t(:pkr_table, :list => "").strip
    end
    hidden.first(3).each { |face| assert_includes flop, face }
    hidden.last(2).each { |face| refute_includes flop, face }
  end

  test "from a hand's end to the next deal the info key has no cards, only the sums and the rivals" do
    winner, still_on, put_away, dealt = played(:poker_hand_over)
    own = t(:pkr_your_hand, :list => "#{card(3, :vp_spades)}, #{card(4, :vp_hearts)}")
    faces = [card(7, :vp_diamonds), card(7, :vp_clubs), card(7, :vp_hearts), card(7, :vp_spades), card(10, :vp_hearts)]
    [winner, still_on].each do |info|
      assert_includes info, own
      faces.each { |face| assert_includes info, face }
    end
    refute_includes put_away, own
    faces.each { |face| refute_includes put_away, face }
    assert_includes put_away, t(:pkr_pot, :n => 0)
    assert_includes put_away, t(:pkr_seat, :name => "Nie", :n => 480)
    assert_includes dealt, own, "the next hand's, as it is dealt"
    faces.each { |face| refute_includes dealt, face }
  end

  test "while the raise menu is open the info key leads with its sum and its row, and closing drops them" do
    first, all_in, raised, closed = played(:poker_menu_key)
    assert first.start_with?(PokeAccess.sentences([t(:pkr_raise, :n => 0), t(:pkr_row, :row => "5")]))
    assert_includes all_in, t(:pkr_row, :row => t(:pkr_all_in))
    assert raised.start_with?(PokeAccess.sentences([t(:pkr_raise, :n => 50), t(:pkr_row, :row => "50")]))
    assert_includes raised, t(:pkr_pot, :n => 30), "with the table behind them"
    refute_includes closed, t(:pkr_raise, :n => 50)
    refute_includes closed, t(:pkr_row, :row => "50")
    assert_includes closed, t(:pkr_pot, :n => 30)
  end

  test "the raise menu opens on its title and keys, its first row queued behind them, and the moves cut in" do
    opening, brief = played(:poker_raise_opens)
    title = t(:pkr_raise_menu)
    assert_equal [["#{title}. #{t(:pkr_raise_keys, :c => "C", :b => "X")}", false], ["5", false], ["10", true]], opening
    assert_equal [[title, false], ["5", false]], brief
  end

  test "poker's info key has the hand and the rivals' chips from the deal on" do
    info = played(:poker_dealt_info)
    assert_includes info, t(:pkr_your_hand, :list => hole_cards)
    assert_includes info, t(:pkr_seat, :name => "Nie", :n => 480)
    assert_includes info, t(:pkr_seat, :name => "Jade", :n => 500)
    refute_includes info, t(:pkr_seat, :name => "Sylvester", :n => 490)
    refute_includes info, "painted only"
  end

  test "poker's info key follows the table on the others' moves, as the chips are painted, without the ones out of the game" do
    _lines, info = played(:poker_not_your_turn)
    assert_includes info, t(:pkr_pot, :n => 40)
    assert_includes played(:poker_chips_painted), t(:pkr_seat, :name => "Nie", :n => 470)
    refute_includes played(:poker_out_of_chips), t(:pkr_seat, :name => "Cord", :n => 500)
  end

  test "poker's info key drops the player's cards and what they owe once they fold" do
    info = played(:poker_folded)
    refute_includes info, t(:pkr_your_hand, :list => "#{card(3, :vp_spades)}, #{card(4, :vp_hearts)}")
    refute_includes info, t(:pkr_owed, :n => 10)
    assert_includes info, t(:pkr_pot, :n => 30)
  end

  test "poker's info key follows the pot as each bet is painted, not only when it empties" do
    assert_includes played(:poker_last_bet), t(:pkr_pot, :n => 70)
  end

  test "poker's info key keeps the hands shown until the pot empties and every card goes" do
    shown, put_away = played(:poker_shown_kept)
    nie = t(:pkr_shows, :name => "Nie", :list => "#{card(10, :vp_clubs)}, #{card(:vp_jack, :vp_clubs)}")
    assert_includes shown, nie
    refute_includes put_away, nie
  end

  test "poker's sums lead the player's question, and the info key keeps them with the cards in sight" do
    line, info = played(:poker_turn)
    want = [t(:pkr_pot, :n => 30), t(:pkr_owed, :n => 10), t(:pkr_chips, :n => 490)].join(", ")
    assert_equal "#{want}: What will you do?", line[0][0]
    assert info.start_with?(want)
    assert_includes info, t(:pkr_your_hand, :list => hole_cards)
  end

  test "before the flop the bet to match starts at the blind" do
    line, info = played(:poker_blind)
    assert_includes line[0][0], t(:pkr_owed, :n => 10)
    assert_includes info, t(:pkr_pot, :n => 15), "no cards dealt yet: the rest of the line stands"
  end

  test "a player out of chips is told no hand" do
    assert_equal [], played(:poker_dealt_out)
  end

  test "the move after a seat that folded comes round to the player" do
    assert_includes played(:poker_wraps_to_the_player)[0][0], t(:pkr_chips, :n => 490)
  end

  test "poker adds nothing to another player's move, and finds the player past who folded" do
    assert_equal ["Nie calls."], played(:poker_not_your_turn)[0].map { |l| l[0] }
    lines = played(:poker_skips_who_folded).map { |l| l[0] }
    assert_equal t(:pkr_table, :list => [card(5, :vp_diamonds), card(6, :vp_clubs), card(:vp_queen, :vp_hearts)].join(", ")), lines[0]
    assert_equal "Jade checks.", lines[1]
  end

  test "poker says the table's cards once per turn of them, all that are up" do
    assert_equal ["Nie calls."], played(:poker_no_repeat).map { |l| l[0] }
    river = played(:poker_river).map { |l| l[0] }
    assert_includes river[0], card(9, :vp_clubs)
    assert_includes river[0], card(5, :vp_diamonds)
    assert_equal "#{t(:pkr_pot, :n => 30)}, #{t(:pkr_chips, :n => 490)}: What will you do?", river[1]
  end

  test "the showdown says the hands still in the round" do
    assert_equal [[t(:pkr_shows, :name => "Nie", :list => "#{card(10, :vp_clubs)}, #{card(:vp_jack, :vp_clubs)}"), false],
                  [t(:pkr_shows, :name => "Jade", :list => "#{card(:vp_king, :vp_clubs)}, #{card(4, :vp_clubs)}"), false]], played(:poker_showdown)
  end

  test "the raise menu says the row under its arrow and the sum it stands at" do
    all_in, ten, raised = played(:poker_menu)
    assert_equal [[t(:pkr_all_in), true]], all_in
    assert_equal [["10", true]], ten
    assert_equal [[t(:pkr_raise, :n => 50), true]], raised
  end

  test "with the key hints left out, no screen says its keys" do
    off = played(:no_hints)
    assert_equal [], off[:bag]
    assert_equal [], off[:map].select { |l| l.include?(t(:ashen_map_sheets, :up => "A", :down => "S")) }
    refute_includes off[:tabs], [t(:ashen_case_tabs), false]
    assert_equal [["Words of a plate.", false]], off[:plate].map { |l| [l[0], false] }
    refute_includes off[:sheet][0][0], t(:ashen_doc_close, :key => "X")
    refute_includes off[:clue][0][0], t(:ashen_ev_examine, :key => "Z")
  end

  test "the journal says the reward only where the game paints one" do
    running = played(:quest_running)
    done = played(:quest_done)
    assert_equal [], running.select { |l| l.include?(t(:quest_hidden)) }
    assert_equal 1, done.count { |l| l.include?("A Rare Candy") }
  end

  test "leaving the table forgets the info key's line" do
    refute_includes played(:poker_closed), "What will you do?"
    refute_includes played(:poker_closed), t(:pkr_pot, :n => 30)
  end

  test "the Well Temple's rocks go by their colour, on its map alone" do
    assert_equal [t(:ashen_rock_grey), t(:ashen_rock_orange), nil], played(:temple_names)
    assert_nil played(:temple_names_elsewhere)
  end

  test "each rock's mark is the tile EV61's pages check, and its colour the one its graphic wears" do
    assert_equal [[49, [13, 63], :grey], [50, [10, 63], :orange], [51, [10, 66], :grey], [52, [13, 68], :orange],
                  [53, [10, 74], :grey], [54, [13, 71], :orange], [55, [30, 64], :grey], [56, [26, 61], :orange],
                  [57, [30, 66], :grey], [58, [26, 69], :orange], [59, [30, 71], :grey], [60, [27, 74], :orange]], played(:temple_marks)
  end

  test "the rocks go under the locator's objects" do
    rock, other = played(:temple_category)
    assert_equal :objects, rock
    assert_equal :people, other
  end

  test "with the puzzle assist the key says how far the rock is from its mark, and the mark is a goal of the route" do
    info, targets = played(:temple_assist)
    assert_includes info, t(:puzzle_track_goal, :label => t(:ashen_rock_grey), :dist => "1 #{t(:dir_up)}", :goal => t(:ashen_mark_grey))
    assert_includes targets, [:puzzle_goal, 13, 63]
  end

  test "a rock is pushed by walking into it, with no field move, only onto the pits' floor" do
    assert_equal [nil, :walk, true, false], played(:temple_rule)
  end

  test "arriving at the pits says how the rocks work, and the info key closes with it" do
    assert_equal [[t(:ashen_temple_rule), false]], played(:temple_arrival)
    assert played(:temple_info_line).end_with?(t(:ashen_temple_rule))
  end

  test "the rest of the temple says nothing of the rocks, and neither the key nor the locator has them" do
    played(:temple_far_from_pits).each do |lines, info, targets|
      assert_equal [], lines
      assert_nil info
      assert_equal [], targets
    end
  end

  test "by the right wing's door with the left to do, it says the left comes first and points at no rock" do
    cut_off, opened = played(:temple_right_door)
    lines, info, targets = cut_off
    assert_equal [[t(:ashen_temple_left_first), false]], lines
    assert_equal t(:ashen_temple_left_first), info
    assert_equal [], targets
    lines, info, targets = opened
    assert_equal [[t(:ashen_temple_rule), false]], lines
    assert_includes info, t(:ashen_rock_orange)
    assert_includes targets, [:puzzle_spot, 26, 61]
  end

  test "with both wings done the pits say nothing more" do
    lines, info = played(:temple_done)
    assert_equal [], lines
    assert_nil info
  end

  test "on the map's real walls, each rock can move onto its mark in its turn, moving no other" do
    left, right, all = played(:temple_turns)
    (left + right).each { |id, ended, pushes| assert_equal [id, :placed], [id, ended], "after #{pushes} pushes" }
    assert_equal true, all, "both wings on their marks"
  end

  test "with the puzzle assist each rock of the right wing gets there in its turn too" do
    played(:temple_turns_assisted).each { |id, ended, pushes| assert_equal [id, :placed], [id, ended], "after #{pushes} pushes" }
  end

  test "the grey rocks of two pits cannot go first: the orange ones stand in their way" do
    turns = played(:temple_grey_first).select { |id, _ended, _pushes| [55, 59].include?(id) }
    assert_equal [[55, :none], [59, :none]], turns.map { |id, ended, _pushes| [id, ended] }
  end

  test "the temple points to each rock and its mark in turn, the left wing first, and ends with both wings" do
    first, moved, second, last, right, none, wing = played(:temple_phases)
    assert_equal 49, first[0]
    assert_includes first[1], [:puzzle_spot, 13, 63]
    assert_includes first[2], t(:ashen_temple_next, :rock => t(:ashen_rock_grey), :mark => t(:ashen_mark_grey), :n => 0)
    assert_equal [t(:ashen_temple_next, :rock => t(:ashen_rock_orange), :mark => t(:ashen_mark_orange), :n => 1)], moved
    assert_equal 50, second[0]
    assert_includes second[1], [:puzzle_spot, 10, 63]
    assert_nil last, "every rock of the left wing on its mark"
    assert_equal 56, right
    assert_nil none
    assert_nil wing
  end

  private

  # A card as the plugin says it.
  def card(value, suit)
    t(:vp_card_bare, :value => value.is_a?(Symbol) ? t(value) : value.to_s, :suit => t(suit))
  end

  # The player's two cards in the play.
  def hole_cards
    "#{card(2, :vp_spades)}, #{card(:vp_ace, :vp_hearts)}"
  end
end
