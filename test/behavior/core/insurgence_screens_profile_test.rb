require "rbconfig"
require "tempfile"

# Insurgence's own screens over stand-ins of its classes, in a process of their own: DexNav, Leaf Booklet, challenges,
# sponsors, tournament, certificate and diploma, Egg Generator, intro, upgrade shop, bag, custom move, databox marks,
# Speed-Up and quick save.
class InsurgenceScreensProfileTest < PokeAccessTest
  # The Insurgence-shaped classes, declared before the toolkit loads so its hooks find them.
  WORLD = <<-'RUBY'
    module Mouse
      def self.getMousePos(catch_anywhere = false)
        raise "Can't find RGSS player window" if $ins_no_window
        $ins_pointer
      end
    end
    module Input
      LeftMouseKey = 1
      def self.releaseex?(key); $ins_released == key; end
      class << self
        alias_method :ins_world_trigger?, :trigger?
        def trigger?(b); ($ins_keys || []).include?(b) || ins_world_trigger?(b); end
      end
    end
    module PBSpecies; DELTASNORLAX = 776; end
    module PBTypes; NORMAL = 0; FIGHTING = 1; STEEL = 8; FIRE = 10; end
    module MessageTypes; FormNames = 21; end
    def pbGetMessage(type, id)
      return nil if $ins_no_forms
      return "Spring Form,Summer Form,Autumn Form,Winter Form,Sakura Form" if type == 21 && id == 776
      "msg#{id}"
    end
    def pbIsImportantItem?(i); i >= 600; end
    def pbIsMegaStone?(i); i == 650; end
    def $Trainer.clothes; $ins_clothes; end
    class InsTextBox; attr_accessor :text; def initialize(t = ""); @text = t; end; end

    # The DexNav: update_command tests the pointer against each button's rectangle and a release of the left button.
    class Scene_DexNav
      RECTS = [[[120, 246, 222, 88], :scan], [[354, 246, 48, 88], :map], [[406, 246, 48, 88], :online],
               [[458, 246, 48, 88], :memory]]
      attr_reader :clicked
      def initialize(memory = false)
        cmds = ["Overworld", "Map", "Online Play"]
        cmds.push("Memory Chamber") if memory
        @cmdOverworld = 0; @cmdMap = 1; @cmdOnline = 2; @cmdMemoryChamber = memory ? 3 : -1
        @sprites = { "command_window" => Window_DrawableCommand.new(cmds) }
        @sprites["command_window"].active = true
      end
      def list; @sprites["command_window"]; end
      def update
        @sprites["command_window"].update
        update_command
      end
      def update_command
        pos = Mouse::getMousePos
        return unless pos
        RECTS.each do |(x, y, w, h), what|
          next unless pos[0] >= x && pos[0] < x + w && pos[1] >= y && pos[1] < y + h
          @clicked = what if Input.releaseex?(Input::LeftMouseKey)
        end
      end
    end

    class Scene_Leaf
      def initialize
        @sprites = { "command_window" => Window_DrawableCommand.new(["Cult Information"] + ["Character Information"] * 4) }
        @sprites["command_window"].active = true
      end
      def list; @sprites["command_window"]; end
      def update; @sprites["command_window"].update; end
    end

    # The challenge menu's controls, as the animation editor builds them.
    class UIControl; attr_accessor :label; def initialize(label); @label = label; end; end
    class PlainText < UIControl; end
    class Button < UIControl; end
    class Checkbox < Button; attr_reader :checked; def checked=(v); @checked = v; end; end
    class ControlWindow
      attr_reader :controls
      def initialize; @controls = []; end
      def addControl(c); @controls.push(c); @controls.length - 1; end
      def update; nil; end
      def value(i); @controls[i].checked; end
    end
    def pbNuzlockeMenu
      w = ControlWindow.new
      w.addControl(PlainText.new("Choose the settings for your challenge run."))
      nuz = w.addControl(Checkbox.new("Nuzlocke"))
      rnd = w.addControl(Checkbox.new("Randomized"))
      w.addControl(Button.new("OK"))
      ($ins_frames || []).each { |keys| $ins_keys = keys; w.update }
      $ins_keys = []
      [w.value(nuz), w.value(rnd)]
    end

    class SponsorScene
      def pbStartScene(company)
        @company = company.clone.push(0)
        @sprites = { "list" => Window_DrawableCommand.new(company.map { |c| c[0] }.push("CANCEL")),
                     "info" => InsTextBox.new, "msgwindow" => InsTextBox.new("Which company do you want to be sponsored by?") }
        pbRefreshInfo(company[0])
      end
      def pbRefreshInfo(company)
        text = "<c2=318c675a><ac>SPONSORSHIPS</ac>\n\n"
        text += " #{company[0]}\n\n Min. Races: #{company[1]}\n Min. Sponsorship Value: #{company[2]}\n Money Multiplier: #{company[3]}x" if company != 0
        @sprites["info"].text = text
      end
      def pbChooseMove
        @sprites["msgwindow"].text = "Which company do you want to be sponsored by?"
        Input.update
        @sprites["list"].update
        nil
      end
      def move_to(i); @sprites["list"].index = i; pbRefreshInfo(@company[i]); end
    end

    class PokemonWorldTournament
      def initialize(list, me); @trainer_list_int = list; @player_index_int = me; end
      def createScoreBoard(_list)
        @trainer_list_int.each_with_index do |t, i|
          pbDrawTextPositions(nil, [[i == @player_index_int ? "Yo" : t[1], 24, 34 + 64 * i]])
        end
        :painted
      end
    end

    class Scene_Certificate; def main; :main; end; end
    class Scene_Diploma; def main; :diploma; end; end

    # The Egg Generator's screens as the game builds them: bars whose labels (create_spriteset) and values
    # (drawWantedData) are painted on their bitmaps, and buttons that keep their name.
    class InsBar; attr_reader :bitmap; def initialize; @bitmap = Object.new; end; end
    class GTS_Button < InsBar; def initialize(name); super(); @name = name; end; end
    class Scene_GTS
      attr_accessor :index
      def initialize; @index = 0; @exit = false; end
      def create_spriteset
        @sprites = { "background" => InsBar.new, "0" => GTS_Button.new("Create Egg"), "1" => GTS_Button.new("Exit") }
        pbDrawTextPositions(@sprites["background"].bitmap, [["Egg Generator", 100, 6, 2]])
      end
      def update; end
      def do_command
        return @exit = true if @index == 1
        create_spriteset
        :closed
      end
    end
    class GTSWantedData
      LABELS = ["Species", "Gender", "Ability", "Item", "Nature", "Nickname", "IVs", "Moves", "Generate Egg!"]
      attr_accessor :index
      def initialize(data = {}); @index = 0; @exit = false; @data = data; end
      def create_spriteset
        @sprites = { "background" => InsBar.new, "9" => GTS_Button.new("Back") }
        pbDrawTextPositions(@sprites["background"].bitmap, [["Pokemon Wanted Data", 50, 6, 0]])
        LABELS.each_with_index do |label, i|
          @sprites[i.to_s] = InsBar.new
          @sprites["#{i}t"] = InsBar.new
          pbDrawTextPositions(@sprites[i.to_s].bitmap, [[label, 80, 0, 0]])
        end
        drawWantedData
      end
      def drawWantedData
        pbDrawTextPositions(@sprites["0t"].bitmap, [[@data[:species] || "????", 325, 4, 2]])
        pbDrawTextPositions(@sprites["1t"].bitmap, [["Male", 325, 2, 2]])
        pbDrawTextPositions(@sprites["2t"].bitmap, [["Static", 325, 4, 2]]) if @data[:species]
        pbDrawTextPositions(@sprites["6t"].bitmap, [[@data[:ivs].join("/"), 322, 4, 2]]) if @data[:ivs]
      end
      def update; end
      # Opens and runs its first frame, then Back leaves it with the data, as its loop would.
      def main
        create_spriteset
        update
        @exit = true
        @data
      end
      def do_command
        @data[:species] = "Pikachu" if @index == 0
        @data = GTSWantedDataIVs.new(@data).main if @index == 6
        @exit = true if @index == 8
        drawWantedData
      end
    end
    # The IVs page: its bars' labels painted on them, the values beside; Back from it opens a wanted data of its own,
    # whose Back returns the data to the wanted data that opened the page.
    class GTSWantedDataIVs
      LABELS = ["HP", "Attack", "Defense", "Speed", "Sp. Atk", "Sp. Defense"]
      def initialize(data); @index = 0; @exit = false; @data = data; @data[:ivs] ||= [31] * 6; end
      def create_spriteset
        @sprites = { "background" => InsBar.new, "6" => GTS_Button.new("Back") }
        pbDrawTextPositions(@sprites["background"].bitmap, [["Pokemon Wanted Data", 50, 6, 0]])
        LABELS.each_with_index do |label, i|
          @sprites[i.to_s] = InsBar.new
          @sprites["#{i}t"] = InsBar.new
          pbDrawTextPositions(@sprites[i.to_s].bitmap, [[label, 80, 0, 0]])
        end
        drawWantedData
      end
      def drawWantedData
        @data[:ivs].each_with_index { |v, i| pbDrawTextPositions(@sprites["#{i}t"].bitmap, [[v.to_s, 350, 4, 2]]) }
      end
      def update; end
      def main
        create_spriteset
        update
        @exit = true
        GTSWantedData.new(@data).main
      end
    end

    class IntroEventScene
      attr_accessor :index
      def initialize(pics); @pics = pics; @index = 0; end
      def openPic(_scene, _args); :pic; end
      def openSplash(_scene, _args); :splash; end
    end

    # The upgrade shop as the game builds it: the money in its one text window (the engine stubs'), sized as it is
    # made and repainted by a purchase (the new sum set twice); $ins_meanwhile, when set, opens whatever else comes up
    # while the shop runs.
    def buySecretBaseUpgrades(_sort)
      gold = Window_UnformattedTextPokemon.new("Money:\n$3000")
      gold.resizeToFit(gold.text, 512)
      $ins_meanwhile.call if $ins_meanwhile
      gold.text = "Money:\n$2000"
      gold.text = "Money:\n$2000"
      $ins_money_window = gold
      :done
    end
    # The other shops a function builds the same way, down to their money window: the upgrade shop the map opens and
    # the Sim Depot's two.
    def ins_money_shop(money, result)
      gold = Window_UnformattedTextPokemon.new("Money:\n$#{money}")
      gold.resizeToFit(gold.text, 512)
      result
    end
    def pbBuyUpgradesPre; ins_money_shop(500, :pbBuyUpgradesPre); end
    def pbBuyIDs; ins_money_shop(501, :pbBuyIDs); end
    def pbBattleIDs; ins_money_shop(502, :pbBattleIDs); end

    class InsBag
      attr_reader :pockets, :registeredItem, :registeredItem2, :registeredItem3, :registeredItem4, :registeredItem5
      def initialize(pockets, reg)
        @pockets = pockets
        @registeredItem, @registeredItem2, @registeredItem3, @registeredItem4, @registeredItem5 = reg
      end
    end
    class InsBagWindow
      attr_reader :pocket
      def initialize(bag, pocket); @bag = bag; @pocket = pocket; end
    end
    InsMove = Struct.new(:id, :pp, :totalpp, :type, :name)
  RUBY

  # The scenes, each a method of InsurgenceScenes whose plain-data value is reported under its name; each starts from
  # the mod's state reset and an empty speech log.
  SCENES = <<-'RUBY'
    # What the scenes share: the speech taken as it was said, and the screens worked as the game works them.
    module Stage
      # The [text, interrupt] pairs spoken since the last call; the log starts afresh.
      def self.heard
        out = SpeakCapture.log.map { |text, interrupt| [text, interrupt] }
        SpeakCapture.clear
        out
      end

      # A DexNav opened and moved to command i, what that said taken.
      def self.dexnav_on(i, memory = false)
        nav = Scene_DexNav.new(memory)
        nav.update
        nav.list.index = i
        nav.update
        heard
        nav
      end

      # One frame of a screen with the confirm key pressed.
      def self.confirm(scene)
        $ins_keys = [Input::C]
        scene.update
      ensure
        $ins_keys = []
      end

      # The challenge menu run over one frame per key list, as [what was said, what the accept returned].
      def self.challenge(frames)
        $ins_frames = frames
        picked = pbNuzlockeMenu
        [heard, picked]
      ensure
        $ins_frames = nil
      end

      # The challenge menu's key line with the game's Controls screen holding rows ([action, key name] pairs).
      def self.challenge_keys(rows)
        was = $PokemonSystem
        row = Struct.new(:controlAction, :keyName)
        $PokemonSystem = rows ? Struct.new(:gameControls).new(rows.map { |a, k| row.new(a, k) }) : Object.new
        PokeAccess::InsurgenceChallenges.keys_text
      ensure
        $PokemonSystem = was
      end

      # The bag's rows for a pocket's entries, the registered slots and the clothes worn.
      def self.bag_rows(entries, registered, clothes)
        $ins_clothes = clothes
        win = InsBagWindow.new(InsBag.new([[], entries], registered), 1)
        (0...entries.length).map { |i| PokeAccess::Menus.bag_row(win, i) }
      ensure
        $ins_clothes = nil
      end

      # The marks a foe's databox notes after drawing the given icons.
      def self.marks(icons)
        foe = Struct.new(:index, :name, :pokemon).new(1, "Snorlax", Object.new)
        box = PokemonDataBox.new(foe)
        box.extra = icons
        box.refresh
        PokeAccess::Battle.shown_marks(foe)
      end

      # The custom move as a screen paints it, with the name and type choice the Move Master stored.
      def self.custom_move(name, choice)
        $game_variables[100] = name
        $game_variables[98] = choice
        PokeAccess::MoveInfo.painted(InsMove.new(579, 10, 10, 9, "Custom Move"), "Custom Move", "???")
      end

      # The quick-save picture slot showing a picture of that name, with what it said and whether the map reads as a
      # picture menu while it shows.
      def self.picture(name)
        pics = (0..50).map { |i| Game_Picture.new(i) }
        was = $game_screen
        $game_screen = Struct.new(:pictures).new(pics)
        pics[20].show(name, 0, 15, 15, 100, 100, 255, 0)
        { :heard => heard, :menu => PokeAccess::PictureCues.menu_showing? }
      ensure
        $game_screen = was
      end
    end

    module InsurgenceScenes
      def self.load
        { :errors => ERRS }
      end

      def self.dexnav_opening
        Scene_DexNav.new.update
        { :heard => Stage.heard }
      end

      def self.dexnav_focus
        nav = Scene_DexNav.new
        nav.update
        Stage.heard
        nav.list.index = 1
        nav.update
        { :heard => Stage.heard }
      end

      def self.dexnav_confirm
        nav = Stage.dexnav_on(1)
        Stage.confirm(nav)
        at_click = Stage.heard
        nav.update
        { :clicked => nav.clicked, :at_click => at_click, :back => Stage.heard,
          :released => Input.releaseex?(Input::LeftMouseKey), :pointer => Mouse::getMousePos }
      end

      def self.dexnav_buttons
        clicked = (0..3).map do |i|
          nav = Stage.dexnav_on(i, true)
          Stage.confirm(nav)
          nav.clicked
        end
        { :clicked => clicked }
      end

      # The focus past the end of a three-command DexNav: on no command, so on no button.
      def self.dexnav_off_buttons
        nav = Stage.dexnav_on(3)
        Stage.confirm(nav)
        Stage.heard
        nav.update
        { :clicked => nav.clicked, :after => Stage.heard, :released => Input.releaseex?(Input::LeftMouseKey) }
      end

      def self.pointer_unreadable
        $ins_no_window = true
        nav = Scene_DexNav.new
        nav.update
        { :pointer => Mouse::getMousePos, :clicked => nav.clicked }
      ensure
        $ins_no_window = false
      end

      def self.armed_click
        PokeAccess::InsurgenceMouse.click_at([378, 290])
        { :releases => [Input.releaseex?(5), Input.releaseex?(Input::LeftMouseKey), Input.releaseex?(Input::LeftMouseKey)],
          :pointers => [Mouse::getMousePos, Mouse::getMousePos] }
      ensure
        PokeAccess::InsurgenceMouse.clear
      end

      def self.mouse_click
        $ins_pointer = [240, 290]
        $ins_released = Input::LeftMouseKey
        nav = Scene_DexNav.new
        nav.update
        { :clicked => nav.clicked, :other_key => Input.releaseex?(5) }
      ensure
        $ins_pointer = nil
        $ins_released = nil
      end

      def self.leaf_opening
        $game_variables[5] = 1
        $game_variables[171] = [true, true, false, false, false]
        Scene_Leaf.new.update
        { :heard => Stage.heard }
      end

      def self.leaf_moves
        $game_variables[5] = 1
        $game_variables[171] = [true, true, false, false, false]
        leaf = Scene_Leaf.new
        leaf.update
        Stage.heard
        leaf.list.index = 1
        leaf.update
        leaf.list.index = 3
        leaf.update
        leaf.update
        { :heard => Stage.heard }
      end

      def self.leaf_rows
        $game_variables[5] = 2
        $game_variables[171] = [true, false, true, false, true]
        rows = (0..4).map do |i|
          leaf = Scene_Leaf.new
          leaf.list.index = i
          leaf.update
          Stage.heard.map { |text, _i| text }
        end
        { :rows => rows }
      end

      def self.leaf_unnamed
        $ins_no_forms = true
        $game_variables[5] = 1
        $game_variables[171] = [true]
        Scene_Leaf.new.update
        { :heard => Stage.heard }
      ensure
        $ins_no_forms = nil
      end

      def self.challenge_menu
        heard, picked = Stage.challenge([[], [Input::DOWN], [Input::RIGHT], [Input::UP]])
        { :heard => heard, :picked => picked }
      end

      def self.challenge_ends
        heard, picked = Stage.challenge([[], [Input::RIGHT], [], [Input::UP], [Input::DOWN], [Input::DOWN], [Input::LEFT],
                                         [Input::LEFT]])
        { :heard => heard, :picked => picked }
      end

      def self.challenge_keys
        { :bound => Stage.challenge_keys([["Action", "C"], ["Action", "Space"], ["Cancel/Menu", "Esc"]]),
          :repeated => Stage.challenge_keys([["Action", "C"], ["Action", "C"], ["Action", ""], ["Cancel/Menu", "Esc"]]),
          :unbound => Stage.challenge_keys([["Action", "C"]]),
          :none => Stage.challenge_keys(nil) }
      end

      def self.challenge_outside
        w = ControlWindow.new
        w.addControl(Checkbox.new("Loose"))
        $ins_keys = [Input::DOWN]
        w.update
        { :heard => Stage.heard }
      ensure
        $ins_keys = []
      end

      def self.sponsor
        sp = SponsorScene.new
        sp.pbStartScene([["Devon Corp", 3, 50, 1.5], ["Silph Co.", 5, 100, 2]])
        opening = Stage.heard
        sp.move_to(1)
        sp.move_to(2)
        moves = Stage.heard
        sp.pbChooseMove
        first = Stage.heard
        sp.pbChooseMove
        back = Stage.heard
        Input.update
        { :opening => opening, :moves => moves, :first_choose => first, :back => back, :next_frame => Stage.heard }
      end

      def self.tournament
        pwt = PokemonWorldTournament.new([[:A, "Ana"], [:B, "Bruno"], [:C, "Clara"]], 0)
        { :result => pwt.createScoreBoard([[:A], [:C]]), :heard => Stage.heard }
      end

      def self.tournament_player_dropped
        PokemonWorldTournament.new([[:A, "Ana"], [:B, "Bruno"]], 0).createScoreBoard([[:B]])
        { :heard => Stage.heard }
      end

      def self.tournament_empty
        { :result => PokemonWorldTournament.new([], 0).createScoreBoard([]), :heard => Stage.heard }
      end

      def self.certificate
        { :result => Scene_Certificate.new.main, :heard => Stage.heard }
      end

      def self.certificate_brief
        PokeAccess::Config.verbosity = :brief
        Scene_Certificate.new.main
        { :heard => Stage.heard }
      end

      def self.diploma
        { :result => Scene_Diploma.new.main, :heard => Stage.heard }
      end

      # The Egg Generator opened, its focus moved down and back, a page opened and closed from it, then its exit.
      def self.egg_menu
        gts = Scene_GTS.new
        gts.create_spriteset
        gts.update
        opened = Stage.heard
        gts.index = 1
        gts.update
        moved = Stage.heard
        gts.index = 0
        gts.update
        Stage.heard
        result = gts.do_command
        gts.update
        back = Stage.heard
        gts.index = 1
        gts.update
        Stage.heard
        gts.do_command
        gts.update
        { :opened => opened, :moved => moved, :result => result, :back => back, :left => Stage.heard }
      end

      # The wanted data opened, its species chosen, the ability that brings and the last row, then the egg made.
      def self.egg_wanted_data
        data = GTSWantedData.new
        data.create_spriteset
        data.update
        opened = Stage.heard
        data.do_command
        data.update
        chosen = Stage.heard
        data.index = 2
        data.update
        ability = Stage.heard
        data.index = 8
        data.update
        last = Stage.heard
        data.do_command
        data.update
        { :opened => opened, :chosen => chosen, :ability => ability, :last => last, :made => Stage.heard }
      end

      # The wanted data's species chosen and its IVs row opened: the IVs page, Back into the wanted data that page
      # opens, Back from that one, then the first one's next frame.
      def self.egg_ivs_page
        data = GTSWantedData.new
        data.create_spriteset
        data.update
        data.do_command
        data.index = 6
        data.update
        Stage.heard
        data.do_command
        inside = Stage.heard
        data.update
        { :inside => inside, :back => Stage.heard }
      end

      def self.intro_cards
        intro = IntroEventScene.new(["intro0", "intro1"])
        intro.openPic(nil, nil)
        intro.index = 1
        intro.openPic(nil, nil)
        intro.openSplash(nil, nil)
        { :heard => Stage.heard }
      end

      def self.intro_other_picture
        intro = IntroEventScene.new(["intro2"])
        intro.openPic(nil, nil)
        intro.index = 4
        intro.openPic(nil, nil)
        { :heard => Stage.heard }
      end

      def self.upgrade_shop
        Window_UnformattedTextPokemon.new("Money:\n$9").text = "Money:\n$8"
        outside = Stage.heard
        result = buySecretBaseUpgrades(0)
        heard = Stage.heard
        $ins_money_window.text = "Money:\n$1000"
        after = Stage.heard
        Window_UnformattedTextPokemon.new("Money:\n$7").text = "Money:\n$6"
        { :outside => outside, :result => result, :heard => heard, :after => after, :later => Stage.heard }
      ensure
        $ins_money_window = nil
      end

      def self.other_shops
        results = [pbBuyUpgradesPre, pbBuyIDs, pbBattleIDs]
        { :heard => Stage.heard, :results => results }
      end

      def self.upgrade_shop_other_window
        $ins_meanwhile = lambda do
          other = Window_UnformattedTextPokemon.new("A bigger room.")
          other.resizeToFit(other.text, 200)
          other.text = "A desk."
        end
        buySecretBaseUpgrades(0)
        { :heard => Stage.heard }
      ensure
        $ins_meanwhile = nil
        $ins_money_window = nil
      end

      def self.bag_badges
        rows = Stage.bag_rows([[7, 3], [600, 1], [650, 2]], [0, 600, 0, 0, 0], [7, 0, 0, 0, 0, 0])
        { :rows => rows, :storage_hides => PokeAccess::Menus.bag_hides_qty?(650) }
      end

      def self.bag_keys
        { :rows => Stage.bag_rows([[601, 1], [602, 1], [603, 1], [604, 1], [605, 1]], [601, 602, 603, 604, 605], nil),
          :twice => Stage.bag_rows([[606, 1]], [606, 0, 606, 0, 0], nil) }
      end

      def self.bag_worn
        { :rows => Stage.bag_rows([[5, 1], [6, 1]], [0, 0, 0, 0, 0], [1, 2, 3, 4, 5, 6]) }
      end

      def self.custom_move_summary
        $game_variables[100] = "Fuego Fatuo"
        $game_variables[98] = 2
        pk = Poke.build(:moves => [InsMove.new(579, 10, 10, 9, "Custom Move"), InsMove.new(33, 35, 35, 0, "Tackle")])
        { :line => PokeAccess::Summary.moves_text(pk) }
      end

      def self.custom_move_fight
        $game_variables[100] = "Fuego Fatuo"
        $game_variables[98] = 2
        battler = Struct.new(:moves).new([InsMove.new(579, 10, 10, 9, "Custom Move")])
        disp = Object.new
        disp.instance_variable_set(:@battler, battler)
        disp.instance_variable_set(:@index, 0)
        PokeAccess::Battle.read_fight_move(disp)
        { :heard => Stage.heard }
      end

      def self.custom_move_types
        { :painted => [0, 2, 5, 16, 17, 18, -1, nil, "2"].map { |c| Stage.custom_move("Fuego Fatuo", c) } }
      end

      def self.custom_move_unnamed
        { :painted => [nil, ""].map { |n| Stage.custom_move(n, 2) } }
      end

      def self.other_move
        { :painted => PokeAccess::MoveInfo.painted(InsMove.new(33, 35, 35, 0, "Tackle"), "Tackle", "Normal") }
      end

      def self.databox_marks
        foe = Struct.new(:index, :name, :pokemon).new(1, "Snorlax", Object.new)
        box = PokemonDataBox.new(foe)
        box.shiny = true
        box.extra = %w[delta armor zeta omega]
        box.refresh
        { :marks => PokeAccess::Battle.shown_marks(foe), :heard => Stage.heard }
      end

      def self.databox_icon_names
        names = %w[delta Delta armor alpha omega zeta omicron epsilon deltas sigma]
        { :marks => names.map { |n| [n, Stage.marks([n])] } }
      end

      def self.turbo_steps
        was = $PokemonSystem
        $PokemonSystem = Struct.new(:turbospeed).new(nil)
        PokeAccess::Turbo.tick
        first = Stage.heard
        [1, 2, 3, 0].each do |step|
          $PokemonSystem.turbospeed = step
          PokeAccess::Turbo.tick
        end
        { :first => first, :heard => Stage.heard }
      ensure
        $PokemonSystem = was
      end

      def self.quick_save
        Stage.picture("save")
      end

      def self.other_picture
        Stage.picture("map")
      end
    end

    InsurgenceScenes.singleton_methods(false).sort.each do |name|
      Reset.before_test
      outcome = begin
        [:ok, InsurgenceScenes.send(name)]
      rescue StandardError, ScriptError, SystemStackError => e
        [:error, "#{e.class}: #{e.message} at #{(e.backtrace || []).first(3).join(' < ')}"]
      end
      puts "REPORT #{name} #{[Marshal.dump(outcome)].pack('m0')}"
    end
    nets = { :raw_codes => SpeakCapture.raw_offenders.map { |_test, text| text }, :arity => ArityNet.offenders }
    puts "REPORT nets #{[Marshal.dump([:ok, nets])].pack('m0')}"
  RUBY

  # The process's share of tools/coverage.rb's measure: the mod's line and branch coverage written beside the test
  # processes' own, as test_helper.rb writes it.
  COVERAGE = <<-'RUBY'
    if ENV["PA_COVERAGE"]
      require "coverage"
      require "json"
      Coverage.setup(:lines => true, :branches => true, :eval => true)
      Coverage.resume
      at_exit do
        root = File.expand_path(Dir.pwd).tr("\\", "/") + "/"
        out = {}
        Coverage.result.each do |path, cov|
          rel = path.tr("\\", "/").sub(root, "")
          next unless rel =~ %r{\A(core|games|plugins|loader)/}
          branches = {}
          (cov[:branches] || {}).each { |cond, targets| targets.each { |t, n| branches["#{cond.inspect}|#{t.inspect}"] = n } }
          out[rel] = { "lines" => cov[:lines], "branches" => branches }
        end
        File.write("#{ENV['PA_COVERAGE']}_insurgence_screens_profile.json", JSON.generate(out))
      end
    end
  RUBY

  test "loads whole, with no load error" do
    assert_equal [], observed(:load)[:errors]
  end

  test "no text of these screens reaches speech with raw control codes" do
    assert_equal [], observed(:nets)[:raw_codes]
  end

  test "no one-parameter block of the mod is handed several values on these screens" do
    assert_equal [], observed(:nets)[:arity]
  end

  test "the DexNav opens on the scan button, said by its painted caption" do
    assert_equal [[t(:ins_dexnav_scan), true]], observed(:dexnav_opening)[:heard]
  end

  test "a DexNav icon is said by the game's own name for its command" do
    assert_equal [["Map", true]], observed(:dexnav_focus)[:heard]
  end

  test "confirm on the DexNav clicks the focused button, silently" do
    seen = observed(:dexnav_confirm)
    assert_equal :map, seen[:clicked]
    assert_equal [], seen[:at_click]
  end

  test "back from a DexNav click the focused button is said again" do
    assert_equal [["Map", true]], observed(:dexnav_confirm)[:back]
  end

  test "a DexNav click is spent: no release nor pointer is left armed" do
    seen = observed(:dexnav_confirm)
    assert_equal false, seen[:released]
    assert_nil seen[:pointer]
  end

  test "confirm on each DexNav command clicks its own button" do
    assert_equal [:scan, :map, :online, :memory], observed(:dexnav_buttons)[:clicked]
  end

  test "confirm with the DexNav's focus on no button clicks nothing: no release armed, the focus not said again" do
    seen = observed(:dexnav_off_buttons)
    assert_nil seen[:clicked]
    assert_equal false, seen[:released]
    assert_equal [], seen[:after]
  end

  test "a pointer that cannot be read is no pointer, not a stopped screen" do
    seen = observed(:pointer_unreadable)
    assert_nil seen[:pointer]
    assert_nil seen[:clicked]
  end

  test "with nothing armed, the mouse clicks as the game reads it" do
    seen = observed(:mouse_click)
    assert_equal :scan, seen[:clicked]
    assert_equal false, seen[:other_key], "another key's release is the game's own answer"
  end

  test "an armed click answers the next pointer read and the next left release once each" do
    seen = observed(:armed_click)
    assert_equal [false, true, false], seen[:releases], "another key, then the left button twice"
    assert_equal [[378, 290], nil], seen[:pointers]
  end

  test "the Leaf Booklet opens on its first leaf, queued, by the form it stands for" do
    assert_equal [["Spring Form, #{t(:ins_leaf_open)}", false]], observed(:leaf_opening)[:heard]
  end

  test "each leaf focused is said once, by its form and whether it is on show or locked" do
    assert_equal [["Summer Form, #{t(:ins_leaf_current)}", true], ["Winter Form, #{t(:ins_leaf_locked)}", true]],
                 observed(:leaf_moves)[:heard]
  end

  test "every leaf stands for its season form, in the booklet's order" do
    want = [["Spring Form, #{t(:ins_leaf_open)}"], ["Summer Form, #{t(:ins_leaf_locked)}"],
            ["Autumn Form, #{t(:ins_leaf_current)}"], ["Winter Form, #{t(:ins_leaf_locked)}"],
            ["Sakura Form, #{t(:ins_leaf_open)}"]]
    assert_equal want, observed(:leaf_rows)[:rows]
  end

  test "a leaf whose form name cannot be read is said by its state alone" do
    assert_equal [[t(:ins_leaf_open), false]], observed(:leaf_unnamed)[:heard]
  end

  test "the challenge menu opens on its prompt, the keys and the first checkbox, then moves and flips" do
    keys = t(:ins_challenge_keys, :accept => t(:key_enter), :cancel => t(:key_escape))
    want = [["Choose the settings for your challenge run. #{keys} Nuzlocke, #{t(:val_off)}", false],
            ["Randomized, #{t(:val_off)}", true], [t(:val_on), true], ["Nuzlocke, #{t(:val_off)}", true]]
    assert_equal want, observed(:challenge_menu)[:heard]
  end

  test "the challenge menu's accept returns what was ticked" do
    assert_equal [nil, true], observed(:challenge_menu)[:picked]
  end

  test "the challenge menu's focus starts on the first box and stops at either end, a frame with no key is silent" do
    keys = t(:ins_challenge_keys, :accept => t(:key_enter), :cancel => t(:key_escape))
    want = [["Choose the settings for your challenge run. #{keys} Nuzlocke, #{t(:val_off)}", false],
            [t(:val_on), true], ["Nuzlocke, #{t(:val_on)}", true], ["Randomized, #{t(:val_off)}", true],
            ["Randomized, #{t(:val_off)}", true], [t(:val_on), true], [t(:val_off), true]]
    assert_equal want, observed(:challenge_ends)[:heard]
  end

  test "left flips a challenge box as right does, both ways" do
    assert_equal [true, false], observed(:challenge_ends)[:picked]
  end

  test "the challenge menu's keys are the ones the game's Controls screen binds" do
    assert_equal t(:ins_challenge_keys, :accept => "C, Space", :cancel => "Esc"), observed(:challenge_keys)[:bound]
  end

  test "a key the Controls screen binds twice is named once, and a blank binding not at all" do
    assert_equal t(:ins_challenge_keys, :accept => "C", :cancel => "Esc"), observed(:challenge_keys)[:repeated]
  end

  test "an action the Controls screen binds no key to keeps its default key" do
    assert_equal t(:ins_challenge_keys, :accept => "C", :cancel => t(:key_escape)), observed(:challenge_keys)[:unbound]
  end

  test "with no Controls screen the challenge menu names the default keys" do
    want = t(:ins_challenge_keys, :accept => t(:key_enter), :cancel => t(:key_escape))
    assert_equal want, observed(:challenge_keys)[:none]
  end

  test "a control window outside the challenge menu is left alone" do
    assert_equal [], observed(:challenge_outside)[:heard]
  end

  test "sponsorships open on the question, the heading and the first company's terms, queued" do
    opening = "Which company do you want to be sponsored by? SPONSORSHIPS. Devon Corp. Min. Races: 3. " \
              "Min. Sponsorship Value: 50. Money Multiplier: 1.5x"
    assert_equal [[opening, false]], observed(:sponsor)[:opening]
  end

  test "each sponsor focused is said by its terms, and CANCEL by its caption" do
    want = [["Silph Co. Min. Races: 5. Min. Sponsorship Value: 100. Money Multiplier: 2x", true], ["CANCEL", true]]
    assert_equal want, observed(:sponsor)[:moves]
  end

  test "the sponsor list's first run adds nothing to the opening" do
    assert_equal [], observed(:sponsor)[:first_choose]
  end

  test "back on the sponsor list after a declined question, the question and the panel are said once" do
    seen = observed(:sponsor)
    assert_equal [["Which company do you want to be sponsored by? SPONSORSHIPS. CANCEL", false]], seen[:back]
    assert_equal [], seen[:next_frame]
  end

  test "the tournament board is said, queued, as painted, a beaten trainer marked" do
    assert_equal [[t(:pwt_board, :list => "Yo; Bruno, #{t(:pwt_out)}; Clara"), false]], observed(:tournament)[:heard]
  end

  test "the player's own row on the tournament board is never marked out" do
    assert_equal [[t(:pwt_board, :list => "Yo; Bruno"), false]], observed(:tournament_player_dropped)[:heard]
  end

  test "a tournament board with no entrants painted says nothing" do
    assert_equal [], observed(:tournament_empty)[:heard]
  end

  test "the tournament board keeps the game's own result, said or not" do
    [:tournament, :tournament_empty].each { |scene| assert_equal :painted, observed(scene)[:result], "for #{scene}" }
  end

  test "the certificate is said as it opens, with the key that leaves it" do
    hint = t(:title_press, :key => t(:key_enter))
    assert_equal [["#{t(:ins_certificate)} #{hint}", true]], observed(:certificate)[:heard]
  end

  test "the certificate leaves its key out while key hints are not said" do
    assert_equal [[t(:ins_certificate), true]], observed(:certificate_brief)[:heard]
  end

  test "the certificate keeps the game's own result" do
    assert_equal :main, observed(:certificate)[:result]
  end

  test "the Pokegear's diploma, the same picture, is said as the certificate is" do
    hint = t(:title_press, :key => t(:key_enter))
    assert_equal({ :result => :diploma, :heard => [["#{t(:ins_certificate)} #{hint}", true]] }, observed(:diploma))
  end

  test "the Egg Generator opens on its title and first button, queued, and says each button focused" do
    menu = observed(:egg_menu)
    assert_equal [["Egg Generator. #{t(:list_entry, :name => 'Create Egg', :n => 1, :tot => 2)}", false]], menu[:opened]
    assert_equal [[t(:list_entry, :name => "Exit", :n => 2, :tot => 2), true]], menu[:moved]
  end

  test "back from a page the Egg Generator opened, its focused button is said again, queued and untitled" do
    menu = observed(:egg_menu)
    assert_equal :closed, menu[:result]
    assert_equal [[t(:list_entry, :name => "Create Egg", :n => 1, :tot => 2), false]], menu[:back]
  end

  test "leaving the Egg Generator says nothing more" do
    assert_equal [], observed(:egg_menu)[:left]
  end

  test "the wanted data opens on its title and species, an unchosen species said as unknown" do
    row = t(:ins_egg_row, :label => "Species", :value => t(:dex_unknown))
    opened = "Pokemon Wanted Data. #{t(:list_entry, :name => row, :n => 1, :tot => 9)}"
    assert_equal [[opened, false]], observed(:egg_wanted_data)[:opened]
  end

  test "a wanted-data choice says its row again with the value painted, queued" do
    row = t(:ins_egg_row, :label => "Species", :value => "Pikachu")
    assert_equal [[t(:list_entry, :name => row, :n => 1, :tot => 9), false]], observed(:egg_wanted_data)[:chosen]
  end

  test "each wanted-data row is said by its label and the value painted beside it, if any" do
    data = observed(:egg_wanted_data)
    ability = t(:ins_egg_row, :label => "Ability", :value => "Static")
    assert_equal [[t(:list_entry, :name => ability, :n => 3, :tot => 9), true]], data[:ability]
    assert_equal [[t(:list_entry, :name => "Generate Egg!", :n => 9, :tot => 9), true]], data[:last]
  end

  test "the egg made, the wanted data closing says nothing more" do
    assert_equal [], observed(:egg_wanted_data)[:made]
  end

  test "the IVs page opens on its title and first stat, then its Back on the wanted data it opens, both queued" do
    hp = t(:list_entry, :name => t(:ins_egg_row, :label => "HP", :value => "31"), :n => 1, :tot => 7)
    species = t(:list_entry, :name => t(:ins_egg_row, :label => "Species", :value => "Pikachu"), :n => 1, :tot => 9)
    assert_equal [["Pokemon Wanted Data. #{hp}", false], ["Pokemon Wanted Data. #{species}", false]],
                 observed(:egg_ivs_page)[:inside]
  end

  test "back on the wanted data that opened the IVs page, its IVs row is said again with the IVs set, queued" do
    ivs = t(:ins_egg_row, :label => "IVs", :value => "31/31/31/31/31/31")
    assert_equal [[t(:list_entry, :name => ivs, :n => 7, :tot => 9), false]], observed(:egg_ivs_page)[:back]
  end

  test "the opening cards are said, then the title prompt, all queued" do
    prompt = "#{t(:title_screen)}. #{t(:title_press, :key => t(:key_enter))}"
    assert_equal [[t(:ins_intro0), false], [t(:ins_intro1), false], [prompt, false]], observed(:intro_cards)[:heard]
  end

  test "an opening picture with no transcription says nothing" do
    assert_equal [], observed(:intro_other_picture)[:heard]
  end

  test "a text window outside the upgrade shop says nothing" do
    assert_equal [], observed(:upgrade_shop)[:outside]
  end

  test "the upgrade shop says its money window, queued, as it opens and after a purchase, once each" do
    assert_equal [["Money: $3000", false], ["Money: $2000", false]], observed(:upgrade_shop)[:heard]
  end

  test "a text window that opens while the upgrade shop runs is not taken for its money window" do
    assert_equal [["Money: $3000", false], ["Money: $2000", false]], observed(:upgrade_shop_other_window)[:heard]
  end

  test "the map's upgrade shop and the Sim Depot's ID shops say their money window as they open" do
    assert_equal [["Money: $500", false], ["Money: $501", false], ["Money: $502", false]], observed(:other_shops)[:heard]
    assert_equal [:pbBuyUpgradesPre, :pbBuyIDs, :pbBattleIDs], observed(:other_shops)[:results]
  end

  test "the upgrade shop keeps the game's own result" do
    assert_equal :done, observed(:upgrade_shop)[:result]
  end

  test "the money window is not followed once the upgrade shop has closed" do
    assert_equal [], observed(:upgrade_shop)[:after]
  end

  test "a text window made after the upgrade shop has closed says nothing" do
    assert_equal [], observed(:upgrade_shop)[:later]
  end

  test "a bag row badges what is worn, the key an item is registered to and a mega stone's count" do
    seen = observed(:bag_badges)
    want = ["Item7: 3, #{t(:shop_worn)}, #{list_place(1, 4)}", "Item600, #{t(:ins_bag_key, :key => 'W')}, #{list_place(2, 4)}",
            "Item650: 2, #{list_place(3, 4)}"]
    assert_equal want, seen[:rows]
  end

  test "the item storage keeps a mega stone's count hidden" do
    assert_equal true, observed(:bag_badges)[:storage_hides]
  end

  test "each of the five registered slots badges its own key, and an item on two keys gets both" do
    seen = observed(:bag_keys)
    keys = %w[Q W E T Y].each_with_index.map { |k, i| "Item#{601 + i}, #{t(:ins_bag_key, :key => k)}, #{list_place(i + 1, 6)}" }
    assert_equal keys, seen[:rows]
    assert_equal ["Item606, #{t(:ins_bag_key, :key => 'Q')}, #{t(:ins_bag_key, :key => 'E')}, #{list_place(1, 2)}"],
                 seen[:twice]
  end

  test "only the five clothes slots count as worn" do
    assert_equal ["Item5: 1, #{t(:shop_worn)}, #{list_place(1, 3)}", "Item6: 1, #{list_place(2, 3)}"], observed(:bag_worn)[:rows]
  end

  test "the summary names the custom move and its type as the player chose them" do
    fire = PBTypes.getName(10)
    moves = ["Fuego Fatuo. #{t(:mv_type, :t => fire)}. #{t(:mv_pp, :pp => 10, :tot => 10)}",
             "Tackle. #{t(:mv_type, :t => PBTypes.getName(0))}. #{t(:mv_pp, :pp => 35, :tot => 35)}"]
    assert_equal t(:sm_moves, :list => moves.join(", ")), observed(:custom_move_summary)[:line]
  end

  test "the fight button names the custom move and its type as the player chose them" do
    line = ["Fuego Fatuo", t(:mv_type, :t => PBTypes.getName(10)), t(:cat_physical), t(:mv_pp, :pp => 10, :tot => 10)]
    assert_equal [[line.join(". "), true]], observed(:custom_move_fight)[:heard]
  end

  test "the custom move's type follows the Move Master's list, Normal off it, unnamed where the game has no such type" do
    want = [["Fuego Fatuo", PBTypes.getName(0)], ["Fuego Fatuo", PBTypes.getName(10)],
            ["Fuego Fatuo", PBTypes.getName(1)], ["Fuego Fatuo", PBTypes.getName(8)], ["Fuego Fatuo", nil],
            ["Fuego Fatuo", PBTypes.getName(0)], ["Fuego Fatuo", PBTypes.getName(0)], ["Fuego Fatuo", PBTypes.getName(0)],
            ["Fuego Fatuo", PBTypes.getName(0)]]
    assert_equal want, observed(:custom_move_types)[:painted]
  end

  test "a custom move the player never named keeps the name its data gives" do
    assert_equal [["Custom Move", PBTypes.getName(10)]] * 2, observed(:custom_move_unnamed)[:painted]
  end

  test "any other move keeps the name and type it is painted with" do
    assert_equal ["Tackle", "Normal"], observed(:other_move)[:painted]
  end

  test "a foe's databox icons are its marks: Delta, armour and a Primal form's Greek letter, after the stock shiny" do
    assert_equal databox_marks, observed(:databox_marks)[:marks]
  end

  test "a foe's marks are said, queued, as it comes in" do
    want = [[t(:bt_marks_entry, :name => "Snorlax", :marks => databox_marks.join(", ")), false]]
    assert_equal want, observed(:databox_marks)[:heard]
  end

  test "each of Insurgence's databox icons stands for its mark, by its whole name in any case" do
    delta = [t(:ins_mark_delta)]
    primal = [t(:bt_mark_primal)]
    want = [["delta", delta], ["Delta", delta], ["armor", [t(:ins_mark_armor)]], ["alpha", primal], ["omega", primal],
            ["zeta", primal], ["omicron", primal], ["epsilon", primal], ["deltas", []], ["sigma", []]]
    assert_equal want, observed(:databox_icon_names)[:marks]
  end

  test "the first Speed-Up read only takes the step, silently" do
    assert_equal [], observed(:turbo_steps)[:first]
  end

  test "each Speed-Up step after it is said by its multiplier over the normal 40 frames" do
    want = [t(:turbo_speed, :n => "2,5"), t(:turbo_speed, :n => 4), t(:turbo_speed, :n => "5,5"), t(:turbo_speed, :n => 1)]
    assert_equal want.map { |line| [line, true] }, observed(:turbo_steps)[:heard]
  end

  test "a quick save's picture is said" do
    assert_equal [[t(:ins_quick_saved), true]], observed(:quick_save)[:heard]
  end

  test "the map is not taken for a picture menu while a quick save's picture shows" do
    assert_equal false, observed(:quick_save)[:menu]
  end

  test "any other picture is not taken for a quick save" do
    assert_equal [], observed(:other_picture)[:heard]
  end

  # The scenes' outcomes from one run of the profile's process, shared by the class's tests: { name => [status,
  # value] }, and the raw output under :raw.
  def self.reports
    @reports ||= begin
      out = profile_output
      found = { :raw => out }
      out.scan(/^REPORT (\w+) (\S+)$/) { |name, data| found[name.to_sym] = Marshal.load(data.unpack1("m0")) }
      found
    end
  end

  # The output of a gen-6 process that measures its coverage when asked, declares the world, loads the toolkit with
  # the profile and plays the scenes, run from a file (a script this long does not reach the child whole through a
  # Windows command line) in the mod's folder.
  def self.profile_output
    needs = %w[speak_capture poke_builder reset arity_net].map { |f| "require #{File.join(Harness::ROOT, 'test', 'support', f).inspect}" }
    script = [COVERAGE, "require #{File.join(Harness::ROOT, 'test', 'support', 'harness').inspect}", WORLD,
              "ERRS = Harness.load_all('insurgence')", needs, "SpeakCapture.install", SCENES].flatten.join("\n")
    file = Tempfile.new(["pa_insurgence_screens", ".rb"])
    begin
      file.write(script)
      file.close
      IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, file.path], :err => [:child, :out], :chdir => Harness::ROOT) do |io|
        io.read
      end.to_s
    ensure
      file.unlink
    end
  end
  private_class_method :profile_output

  private

  # What the scene of that name observed; a scene that raised, or never ran, fails the test.
  def observed(name)
    reports = self.class.reports
    status, value = reports.fetch(name) { flunk "the profile's process reported no #{name}: #{reports[:raw][0, 800]}" }
    flunk "#{name} raised in the profile's process: #{value}" unless status == :ok
    value
  end

  # The Spanish text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The marks of the databox scene's foe: the stock shiny, then Delta, armour and a Primal form's Greek letter.
  def databox_marks
    [t(:pk_shiny), t(:ins_mark_delta), t(:ins_mark_armor), t(:bt_mark_primal)]
  end
end
