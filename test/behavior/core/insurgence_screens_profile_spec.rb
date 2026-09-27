require "rbconfig"

# Insurgence's own screens, loaded with the whole profile in a process of their own (the profile's overrides would
# reach every other suite here), over stand-ins shaped as the game's classes: the DexNav clicked from the keyboard,
# the Leaf Booklet, the challenge menu, sponsorships, the tournament board, the certificate, the opening cards, the
# upgrade shop's money, the bag's badges, the custom move, the turbo steps and the quick save's picture.
module InsurgenceScreensProfileSpec
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
      return "Spring Form,Summer Form,Autumn Form,Winter Form,Sakura Form" if type == 21 && id == 776
      "msg#{id}"
    end
    def pbIsImportantItem?(i); i >= 600; end
    def pbIsMegaStone?(i); i == 650; end
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

    class IntroEventScene
      attr_accessor :index
      def initialize(pics); @pics = pics; @index = 0; end
      def openPic(_scene, _args); :pic; end
      def openSplash(_scene, _args); :splash; end
    end

    class Window_UnformattedTextPokemon
      attr_reader :text
      def initialize(text = ""); @text = text; resizeToFit(text); end
      def text=(v); @text = v; end
      def resizeToFit(_text, _maxwidth = -1); nil; end
    end
    def buySecretBaseUpgrades(_sort)
      w = Window_UnformattedTextPokemon.new("Money:\n$3000")
      w.resizeToFit(w.text, 512)
      w.text = "Money:\n$2000"
      w.text = "Money:\n$2000"
      :done
    end

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

  # The checks, run after the load; each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    # The checks run in a method of their own, so no hook block closing over the top level can touch their locals.
    def insurgence_screen_checks
      tr = PokeAccess::I18n
      check "loads whole", ERRS.empty?, ERRS.first(3)
      absent = PokeAccess::Hooks.fn_absent & %w[pbNuzlockeMenu buySecretBaseUpgrades Mouse.getMousePos Input.releaseex?]
      check "its functions are wrapped", absent.empty?, absent
      ov = PokeAccess::Hooks.overrides.select { |o| o.include?("game_insurgence") }
      want = ["PokeAccess::MoveInfo.painted (game_insurgence)", "PokeAccess::Turbo.current_speed (game_insurgence)",
              "PokeAccess::Turbo.stage_table (game_insurgence)", "PokeAccess::Menus.bag_registered? (game_insurgence)",
              "PokeAccess::Menus.bag_row (game_insurgence)", "PokeAccess::Menus.bag_hides_qty? (game_insurgence)"]
      check "its overrides are declared", (want - ov).empty?, want - ov

      SpeakCapture.clear
      nav = Scene_DexNav.new
      nav.update
      list = nav.instance_variable_get(:@sprites)["command_window"]
      check "the DexNav opens on the scan button by its painted caption", SpeakCapture.lines == [tr.t(:ins_dexnav_scan)], SpeakCapture.lines
      check "and its hidden list is claimed", PokeAccess.dedicated?(list), nil
      SpeakCapture.clear
      list.index = 1
      nav.update
      check "an icon by the game's own name for its command", SpeakCapture.lines == ["Map"], SpeakCapture.lines
      $ins_keys = [Input::C]
      nav.update
      $ins_keys = []
      check "confirm clicks the focused button", nav.clicked == :map, nav.clicked
      SpeakCapture.clear
      nav.update
      check "and back from it the focus is said again", SpeakCapture.lines == ["Map"], SpeakCapture.lines
      released = Input.releaseex?(Input::LeftMouseKey)
      pointer = Mouse::getMousePos
      check "the click is spent: no release nor pointer left armed", released == false && pointer.nil?, [released, pointer]
      $ins_no_window = true
      nav.update
      $ins_no_window = false
      check "a pointer that cannot be read is no pointer, not a stopped screen", true
      $ins_pointer = [240, 290]
      $ins_released = Input::LeftMouseKey
      later = Scene_DexNav.new
      later.update
      check "the mouse still clicks as before", later.clicked == :scan, later.clicked
      $ins_pointer = nil
      $ins_released = nil

      SpeakCapture.clear
      $game_variables[5] = 1
      $game_variables[171] = [true, true, false, false, false]
      leaf = Scene_Leaf.new
      leaf.update
      check "the booklet opens on its first leaf, queued, by the form it stands for",
            SpeakCapture.log == [["Spring Form, #{tr.t(:ins_leaf_open)}", false]], SpeakCapture.log
      SpeakCapture.clear
      cmd = leaf.instance_variable_get(:@sprites)["command_window"]
      cmd.index = 1
      leaf.update
      cmd.index = 3
      leaf.update
      check "the form on show and a locked one", SpeakCapture.lines ==
            ["Summer Form, #{tr.t(:ins_leaf_current)}", "Winter Form, #{tr.t(:ins_leaf_locked)}"], SpeakCapture.lines
      check "and the Notebook's captions are never read", PokeAccess.dedicated?(cmd), nil

      SpeakCapture.clear
      $ins_frames = [[], [Input::DOWN], [Input::RIGHT], [Input::UP]]
      picked = pbNuzlockeMenu
      $ins_frames = nil
      keys = tr.t(:ins_challenge_keys, :accept => tr.t(:key_enter), :cancel => tr.t(:key_escape))
      check "the challenge menu opens on its prompt, the keys and the first checkbox",
            SpeakCapture.log[0] == ["Choose the settings for your challenge run. #{keys} Nuzlocke, #{tr.t(:val_off)}", false],
            SpeakCapture.log[0]
      check "then the next one, its flip, and back up", SpeakCapture.lines[1..-1] ==
            ["Randomized, #{tr.t(:val_off)}", tr.t(:val_on), "Nuzlocke, #{tr.t(:val_off)}"], SpeakCapture.lines
      check "and the accept reads what was ticked", picked == [nil, true], picked
      row = Struct.new(:controlAction, :keyName)
      controls = [row.new("Action", "C"), row.new("Action", "Space"), row.new("Cancel/Menu", "Esc")]
      old_system = $PokemonSystem
      $PokemonSystem = Struct.new(:gameControls).new(controls)
      bound = PokeAccess::InsurgenceChallenges.keys_text
      $PokemonSystem = old_system
      check "the keys are the ones the game's Controls screen binds",
            bound == tr.t(:ins_challenge_keys, :accept => "C, Space", :cancel => "Esc"), bound
      SpeakCapture.clear
      free = ControlWindow.new
      free.addControl(Checkbox.new("Loose"))
      free.update
      check "a control window outside the menu is left alone", SpeakCapture.lines.empty?, SpeakCapture.lines

      SpeakCapture.clear
      sp = SponsorScene.new
      sp.pbStartScene([["Devon Corp", 3, 50, 1.5], ["Silph Co.", 5, 100, 2]])
      opening = ["Which company do you want to be sponsored by? SPONSORSHIPS. Devon Corp.", "Min. Races: 3.",
                 "Min. Sponsorship Value: 50.", "Money Multiplier: 1.5x"].join(" ")
      check "sponsorships open on the question, the heading and the first company's terms, queued",
            SpeakCapture.log == [[opening, false]], SpeakCapture.log
      check "and the list's bare read is muted", PokeAccess.dedicated?(sp.instance_variable_get(:@sprites)["list"]), nil
      SpeakCapture.clear
      sp.move_to(1)
      sp.move_to(2)
      check "each company's terms, then CANCEL by its caption", SpeakCapture.lines ==
            ["Silph Co. Min. Races: 5. Min. Sponsorship Value: 100. Money Multiplier: 2x", "CANCEL"], SpeakCapture.lines
      SpeakCapture.clear
      sp.pbChooseMove
      check "the first run of the list says nothing more", SpeakCapture.lines.empty?, SpeakCapture.lines
      sp.pbChooseMove
      check "back on it after a declined question, the question and the panel again", SpeakCapture.lines ==
            ["Which company do you want to be sponsored by? SPONSORSHIPS. CANCEL"], SpeakCapture.lines

      SpeakCapture.clear
      pwt = PokemonWorldTournament.new([[:A, "Ana"], [:B, "Bruno"], [:C, "Clara"]], 0)
      check "the scoreboard keeps its result", pwt.createScoreBoard([[:A], [:C]]) == :painted, nil
      check "and is said, queued, as painted, the beaten one marked",
            SpeakCapture.log == [[tr.t(:pwt_board, :list => "Yo; Bruno, #{tr.t(:pwt_out)}; Clara"), false]], SpeakCapture.log

      SpeakCapture.clear
      Scene_Certificate.new.main
      hint = tr.t(:title_press, :key => tr.t(:key_enter))
      check "the certificate's transcription and the key that leaves it",
            SpeakCapture.lines == ["#{tr.t(:ins_certificate)} #{hint}"], SpeakCapture.lines

      SpeakCapture.clear
      intro = IntroEventScene.new(["intro0", "intro1"])
      intro.openPic(nil, nil)
      intro.index = 1
      intro.openPic(nil, nil)
      intro.openSplash(nil, nil)
      check "the opening cards, then the title prompt, all queued", SpeakCapture.log ==
            [[tr.t(:ins_intro0), false], [tr.t(:ins_intro1), false], [PokeAccess::TitleScreen.prompt, false]], SpeakCapture.log

      SpeakCapture.clear
      Window_UnformattedTextPokemon.new("Money:\n$9")
      check "a text window outside the shop says nothing", SpeakCapture.lines.empty?, SpeakCapture.lines
      check "the upgrade shop keeps its result", buySecretBaseUpgrades(0) == :done, nil
      check "and says its money as it opens and after a purchase, once each",
            SpeakCapture.log == [["Money: $3000", false], ["Money: $2000", false]], SpeakCapture.log

      def $Trainer.clothes; [7, 0, 0, 0, 0, 0]; end
      bag = InsBag.new([[], [[7, 3], [600, 1], [650, 2]]], [0, 600, 0, 0, 0])
      win = InsBagWindow.new(bag, 1)
      rows = (0..2).map { |i| PokeAccess::Menus.bag_row(win, i) }
      check "the bag's badges: worn, the key an item is registered to, and a mega stone's count", rows ==
            ["Item7: 3, #{tr.t(:shop_worn)}", "Item600, #{tr.t(:ins_bag_key, :key => 'W')}", "Item650: 2"], rows
      check "while the item storage keeps a mega stone's count hidden", PokeAccess::Menus.bag_hides_qty?(650), nil

      $game_variables[100] = "Fuego Fatuo"
      $game_variables[98] = 2
      pk = Poke.build(:moves => [InsMove.new(579, 10, 10, 9, "Custom Move"), InsMove.new(33, 35, 35, 0, "Tackle")])
      line = PokeAccess::Summary.moves_text(pk).to_s
      fire = PokeAccess::Data.type_name(10)
      qm = PokeAccess::Data.type_name(9)
      check "the custom move by the name and type the player gave it", line.include?("Fuego Fatuo") &&
            !line.include?("Custom Move") && line.include?(tr.t(:mv_type, :t => fire)) && qm && !line.include?(qm), line
      battler = Struct.new(:moves).new([InsMove.new(579, 10, 10, 9, "Custom Move")])
      disp = Object.new
      disp.instance_variable_set(:@battler, battler)
      disp.instance_variable_set(:@index, 0)
      SpeakCapture.clear
      PokeAccess::Battle.read_fight_move(disp)
      check "and so on its fight button", SpeakCapture.last.to_s.index("Fuego Fatuo") == 0 &&
            SpeakCapture.last.to_s.include?(fire), SpeakCapture.lines
      $game_variables[98] = 16
      check "Steel for the list's seventeenth type, as the battle fights with it",
            PokeAccess::InsurgenceCustomMove.chosen_type_name(16) == PokeAccess::Data.type_name(8), nil

      foe = Struct.new(:index, :name, :pokemon).new(1, "Snorlax", Object.new)
      box = PokemonDataBox.new(foe)
      box.shiny = true
      box.extra = %w[delta armor zeta omega]
      SpeakCapture.clear
      box.refresh
      marks = [tr.t(:pk_shiny), tr.t(:ins_mark_delta), tr.t(:ins_mark_armor), tr.t(:bt_mark_primal)]
      check "its databox icons: Delta, armour and a Primal form's Greek letter, after the stock shiny",
            PokeAccess::Battle.shown_marks(foe) == marks, PokeAccess::Battle.shown_marks(foe)
      check "said as the foe comes in", SpeakCapture.lines ==
            [tr.t(:bt_marks_entry, :name => "Snorlax", :marks => marks.join(", "))], SpeakCapture.lines

      $PokemonSystem = Struct.new(:turbospeed).new(nil)
      SpeakCapture.clear
      PokeAccess::Turbo.tick
      $PokemonSystem.turbospeed = 1
      PokeAccess::Turbo.tick
      $PokemonSystem.turbospeed = 0
      PokeAccess::Turbo.tick
      check "each Speed-Up step by its multiplier over the normal 40 frames", SpeakCapture.lines ==
            [tr.t(:turbo_speed, :n => "2,5"), tr.t(:turbo_speed, :n => 1)], SpeakCapture.lines

      SpeakCapture.clear
      pics = (0..50).map { |i| Game_Picture.new(i) }
      $game_screen = Struct.new(:pictures).new(pics)
      pics[20].show("save", 0, 15, 15, 100, 100, 255, 0)
      check "a quick save's picture is said", SpeakCapture.lines == [tr.t(:ins_quick_saved)], SpeakCapture.lines
      check "and the map is not taken for a picture menu while it shows", !PokeAccess::PictureCues.menu_showing?, nil
    end
    insurgence_screen_checks
  RUBY

  # Runs the world, the load and the checks in a gen-6 process: [[label, ok, detail], ...], or the raw output.
  def self.run
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
             "ERRS = Harness.load_all('insurgence')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "require #{File.join(support, 'poke_builder').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHECKS}"
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }
    rows = out.to_s.scan(/^CHECK (.*?)\|([01])\|(.*)$/)
    rows.empty? ? out.to_s : rows
  end
end

Suite.define("insurgence screens: the profile's readers of its own screens, bound over Insurgence-shaped classes") do
  rows = InsurgenceScreensProfileSpec.run
  if rows.is_a?(String)
    truthy "the profile process ran its checks: #{rows[0, 600]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 41
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end
