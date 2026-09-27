require "rbconfig"

# Uranium's Elite Battle System menus (command, move and question boxes) and its battle bag, driven through loops
# shaped as Uranium's own in a process of their own: each box says its focus as the keys move it.
module UraniumBattleSpec
  # The key feed, the EBS-shaped classes and a battle, declared before the toolkit loads so its hooks find them.
  WORLD = <<-'RUBY'
    module UraKeys
      def self.feed(list); @frames = list.dup; @cur = nil; end
      def self.step; @cur = (@frames || []).shift; end
      def self.cur; @cur; end
    end
    class << Input
      def update; UraKeys.step; end
      def trigger?(k); UraKeys.cur == k; end
      def repeat?(k); UraKeys.cur == k; end
    end
    USEMOUSE = false
    class UraRect
      attr_accessor :x, :y, :width, :height
      def initialize; @x = 0; @y = 0; @width = 0; @height = 0; end
      def set(x, y, w, h); @x = x; @y = y; @width = w; @height = h; end
    end
    class UraSprite; attr_reader :src_rect; def initialize; @src_rect = UraRect.new; end; end
    def pbPocketNames; ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]; end

    class UraMove
      attr_reader :id, :name, :type, :pp, :totalpp
      def initialize(id, name, pp); @id = id; @name = name; @type = 0; @pp = pp; @totalpp = 35; end
    end
    class UraBattler
      attr_reader :index, :name, :moves
      def initialize(battle, index, name, moves); @battle = battle; @index = index; @name = name; @moves = moves; end
      def isShadow?; false; end
      def inHyperMode?; false; end
    end
    class UraBattle
      attr_accessor :battlers, :mega, :party1, :party2, :opponent, :fullparty2
      def initialize; @battlers = []; end
      def pbCanMegaEvolve?(i); @mega == i; end
      def pbRegisterMegaEvolution(i); @registered = i; end
      def pbSecondPartyBegin(i); @fullparty2 ? 6 : 3; end
    end

    class NewCommandWindow
      attr_accessor :index
      def initialize(viewport = nil, battle = nil, safari = false)
        @battle = battle; @safaribattle = safari; @index = 0
        @texts = [["Fight", "Bag", "Pokemon", "Run"], ["Ball", "Bait", "Rock", "Call"]]
      end
      def refreshCommands(index)
        poke = @battle.battlers[index]
        text = []
        for i in 0...4
          row = @safaribattle ? 1 : 0
          row = ((poke.isShadow? && poke.inHyperMode?) ? 1 : 0) if i == 3
          text.push([@texts[row][i], 78 + (i * 122), 40, 2, nil, nil])
        end
        pbDrawTextPositions(nil, text)
      end
      def text=(msg); pbDrawTextPositions(nil, [[msg, 256, 2, 2, nil, nil]]); end
      def update; @over = false; end
    end
    class NewFightWindow
      attr_accessor :index, :battler, :refreshpos
      attr_reader :nummoves
      def initialize(viewport = nil); @index = 0; @nummoves = 0; @showMega = false; @megaRow = 0; end
      def generateButtons; @nummoves = @battler.moves.select { |m| m && m.id > 0 }.length; end
      def megaButton; @showMega = true; end
      def megaButtonSet(enabled); @megaRow = enabled ? 48 : 0; end
      def hide; @showMega = false; megaButtonSet(false); end
      def update; @over = false; end
    end
    class NewChoiceSel
      attr_accessor :index
      def initialize(viewport, commands); @commands = commands; @index = 0; end
      def dispose(scene); @commands = []; end
      def update
        if Input.trigger?(Input::LEFT)
          @index -= 1
          @index = @commands.length - 1 if @index < 0
        end
        if Input.trigger?(Input::RIGHT)
          @index += 1
          @index = 0 if @index >= @commands.length
        end
      end
    end
    class NewBattleBag
      attr_reader :index, :ret
      def pbDisplayMessage(msg); @scene.pbDisplayMessage(msg); end
      def initialize(scene, viewport)
        @scene = scene; @lastUsed = $PokemonGlobal.lastUsed; @index = 0; @item = 0; @page = -1; @selPocket = 0
        @ret = nil; @sprites = { "sel" => UraSprite.new }
      end
      def drawPocket(pocket)
        @pocket = []
        ($PokemonBag.pockets[pocket] || []).each { |it| @pocket.push([it[0], it[1]]) if $ura_usable.include?(it[0]) }
        if @pocket.length < 1
          pbDisplayMessage("You have no usable items in this pocket.")
          return
        end
        @pages = @pocket.length / 6
        @pages += 1 if @pocket.length % 6 > 0
        @page = 0; @item = 0; @back = false; @selPocket = pocket
        @pname = pbPocketNames[pocket]
      end
      def updatePocket
        @page = @item / 6
        @item -= 1 if Input.trigger?(Input::LEFT) && !@back && @item > 0
        @item += 1 if Input.trigger?(Input::RIGHT) && !@back && @item < @pocket.length - 1
        if Input.trigger?(Input::DOWN)
          if @back
            @back = false
          else
            @item += 2
            @back = true if @item > @pocket.length - 1
          end
          @item = @pocket.length - 1 if @item > @pocket.length - 1
        end
        if (@back && Input.trigger?(Input::C)) || Input.trigger?(Input::B)
          @selPocket = 0; @page = -1; @back = false; @doubleback = true
        end
      end
      def show; @ret = nil; @index = 0 if @index == 4 && @lastUsed == 0; end
      def hide; nil; end
      def useItem?
        Input.update
        @sprites["sel"].src_rect.width = 466
        index = 0
        loop do
          @sprites["sel"].src_rect.x = 466 * (index + 2)
          if Input.trigger?(Input::UP)
            index -= 1
            index = 1 if index < 0
          end
          if Input.trigger?(Input::DOWN)
            index += 1
            index = 0 if index > 1
          end
          break if Input.trigger?(Input::C) || UraKeys.cur.nil?
          Input.update
        end
        if index > 0
          @ret = nil
          return false
        end
        true
      end
      def finish
        if (Input.trigger?(Input::B) || (Input.trigger?(Input::C) && @index == 5)) && @selPocket == 0 && !@doubleback
          return true
        end
        @doubleback = false
        false
      end
      def update
        if @selPocket == 0
          updateMain
        else
          if Input.trigger?(Input::C) && !@back
            @selPocket = 0; @page = -1; @lastUsed = 0
            @lastUsed = @pocket[@item][0] if @pocket[@item][1] > 1
            $PokemonGlobal.lastUsed = @lastUsed
            @ret = @pocket[@item][0]
          end
          updatePocket
        end
      end
      def updateMain
        if Input.trigger?(Input::UP)
          @index -= 2
          @index += 6 if @index < 0
          @index = 5 if @index == 4 && !(@lastUsed > 0)
        end
        if Input.trigger?(Input::DOWN)
          @index += 2
          @index -= 6 if @index > 5
          @index = 5 if @index == 4 && !(@lastUsed > 0)
        end
        if Input.trigger?(Input::LEFT)
          @index -= 1
          @index += 2 if @index % 2 == 1
        end
        if Input.trigger?(Input::RIGHT)
          @index += 1
          @index -= 2 if @index % 2 == 0
        end
        if Input.trigger?(Input::C) && !@doubleback && @index < 5
          if @index < 4
            drawPocket([2, 3, 5, 7][@index])
          else
            @selPocket = 0; @page = -1; @ret = @lastUsed
          end
        end
      end
    end

    class PokeBattle_Scene
      def initialize(battle, safari = false)
        @battle = battle; @sprites = {}; @lastcmd = [0, 0, 0, 0]; @lastmove = [0, 0, 0, 0]
        @commandWindow = NewCommandWindow.new(nil, battle, safari)
        @fightWindow = NewFightWindow.new(nil)
        @bagWindow = NewBattleBag.new(self, nil)
      end
      def pbDisplayMessage(msg, brief = false); nil; end
      def pbCommonAnimation(animname, user, target, hitnum = 0); animname; end
      def pbGraphicsUpdate; Graphics.update; end
      def pbInputUpdate; Input.update; end
      def animateBattleSprites(*a); nil; end
      def pbCommandMenuEx(index, texts, mode = 0)
        cw = @commandWindow
        cw.refreshCommands(index)
        cw.text = "What will #{@battle.battlers[index].name} do?"
        loop do
          pbGraphicsUpdate
          pbInputUpdate
          animateBattleSprites(true)
          cw.update
          return nil if UraKeys.cur.nil?
          cw.index = (cw.index > 0 ? cw.index - 1 : 3) if Input.trigger?(Input::LEFT)
          cw.index = (cw.index < 3 ? cw.index + 1 : 0) if Input.trigger?(Input::RIGHT)
          if Input.trigger?(Input::C)
            @ret = cw.index
            @lastcmd[index] = @ret
            break
          end
        end
        @ret
      end
      def pbFightMenu(index)
        cw = @fightWindow
        mega = false
        battler = @battle.battlers[index]
        cw.megaButton if @battle.pbCanMegaEvolve?(index)
        cw.battler = battler
        last = @lastmove[index]
        cw.index = battler.moves[last].id != 0 ? last : 0
        cw.generateButtons
        loop do
          pbGraphicsUpdate
          pbInputUpdate
          animateBattleSprites(true)
          cw.update
          return nil if UraKeys.cur.nil?
          if Input.trigger?(Input::LEFT)
            cw.index = cw.index > 0 ? cw.index - 1 : cw.nummoves - 1
          elsif Input.trigger?(Input::RIGHT)
            cw.index = cw.index < cw.nummoves - 1 ? cw.index + 1 : 0
          end
          if Input.trigger?(Input::C)
            @ret = cw.index
            @battle.pbRegisterMegaEvolution(index) if mega
            @lastmove[index] = @ret
            break
          elsif Input.trigger?(Input::A)
            if @battle.pbCanMegaEvolve?(index)
              mega = !mega
              cw.megaButtonSet(mega)
            end
          elsif Input.trigger?(Input::B)
            @lastmove[index] = cw.index
            @ret = -1
            break
          end
        end
        3.times { cw.hide } if @ret > -1
        @ret
      end
      def pbShowCommands(msg, commands, defaultValue)
        cw = NewChoiceSel.new(nil, commands)
        loop do
          animateBattleSprites(true)
          pbGraphicsUpdate
          pbInputUpdate
          cw.update
          return nil if UraKeys.cur.nil?
          if Input.trigger?(Input::B) && defaultValue >= 0
            cw.dispose(self)
            return defaultValue
          end
          if Input.trigger?(Input::C)
            cw.dispose(self)
            return cw.index
          end
        end
      end
      def pbItemMenu(index)
        Input.update
        ret = 0
        @bagWindow.show
        loop do
          break if @bagWindow.finish
          Input.update
          @bagWindow.update
          return nil if UraKeys.cur.nil?
          if !@bagWindow.ret.nil? && @bagWindow.useItem?
            ret = @bagWindow.ret
            break
          end
          animateBattleSprites
          pbGraphicsUpdate
        end
        @bagWindow.hide
        [ret, -1]
      end
      def pbUpdateSelected(index); index; end
      def pbChooseTarget(index)
        curwindow = 1
        loop do
          pbGraphicsUpdate
          pbInputUpdate
          pbUpdateSelected(curwindow)
          return nil if UraKeys.cur.nil?
          if Input.trigger?(Input::C)
            pbUpdateSelected(-1)
            return curwindow
          end
          curwindow = 0 if Input.trigger?(Input::DOWN)
        end
      end
    end
  RUBY

  # The checks, run after the load; each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    T = PokeAccess::I18n
    check "loads whole", ERRS.empty?, ERRS.first(3)
    mine = %w[NewCommandWindow#refreshCommands NewCommandWindow#update NewFightWindow#battler= NewFightWindow#update
              NewFightWindow#megaButtonSet NewChoiceSel#update NewChoiceSel#dispose NewBattleBag#show NewBattleBag#update NewBattleBag#useItem?]
    check "every battle hook binds", (PokeAccess::Hooks.missing & mine).empty?, PokeAccess::Hooks.missing & mine

    $PokemonGlobal ||= Object.new
    class << $PokemonGlobal; attr_accessor :lastUsed; end
    $PokemonGlobal.lastUsed = 0
    $PokemonBag = Struct.new(:pockets).new([[], [], [[1, 3], [50, 2]], [[25, 1]], [], [], [], [], []])
    $ura_usable = [1, 50]
    ura_battle = UraBattle.new
    ura_moves = [UraMove.new(33, "Tackle", 35), UraMove.new(45, "Growl", 40), UraMove.new(0, "", 0), UraMove.new(0, "", 0)]
    ura_battle.battlers = [UraBattler.new(ura_battle, 0, "Pika", ura_moves), UraBattler.new(ura_battle, 1, "Foe", [])]
    ebs = PokeBattle_Scene.new(ura_battle)

    UraKeys.feed([:none, Input::RIGHT, Input::RIGHT, Input::LEFT, Input::C])
    SpeakCapture.clear
    r = ebs.pbCommandMenuEx(0, [])
    check "the command buttons as painted, the first queued", [r, SpeakCapture.log] ==
          [1, [["Fight", false], ["Bag", true], ["Pokemon", true], ["Bag", true]]], [r, SpeakCapture.log]
    safari = PokeBattle_Scene.new(ura_battle, true)
    UraKeys.feed([:none, Input::LEFT, Input::C])
    SpeakCapture.clear
    r = safari.pbCommandMenuEx(0, [])
    check "the safari buttons, whose fourth is still Run", [r, SpeakCapture.lines] == [3, ["Ball", "Run"]],
          [r, SpeakCapture.lines]

    fight_lines = ura_moves[0, 2].map do |m|
      w = NewFightWindow.new
      w.battler = ura_battle.battlers[0]
      w.index = ura_moves.index(m)
      SpeakCapture.clear
      PokeAccess::Battle.read_fight_move(w)
      SpeakCapture.lines.first
    end
    ura_battle.mega = 0
    UraKeys.feed([:none, Input::RIGHT, Input::A, Input::A, Input::C])
    SpeakCapture.clear
    r = ebs.pbFightMenu(0)
    want = [[fight_lines[0], false], [PokeAccess::Battle.ready_text(:mega), false], [fight_lines[1], true],
            [T.t(:bt_mega_on), true], [T.t(:bt_mega_off), true]]
    check "the moves as core reads them, the Mega Evolution button and its toggles",
          fight_lines.all? { |l| l.to_s.index("Tackle") || l.to_s.index("Growl") } && [r, SpeakCapture.log] == [1, want],
          [r, SpeakCapture.log, fight_lines]
    ura_battle.mega = nil
    UraKeys.feed([:none, Input::B])
    SpeakCapture.clear
    r = ebs.pbFightMenu(0)
    check "reopened on the last move: said again, queued, without the button", [r, SpeakCapture.log] ==
          [-1, [[fight_lines[1], false]]], [r, SpeakCapture.log]

    UraKeys.feed([:none, Input::RIGHT, Input::C])
    SpeakCapture.clear
    r = ebs.pbShowCommands("Use next Pokémon?", ["Yes", "No"], 1)
    check "a battle question, then its boxes, the first queued", r == 1 &&
          SpeakCapture.lines == ["Use next Pokémon?", "Yes", "No"] && SpeakCapture.log[1] == ["Yes", false],
          [r, SpeakCapture.log]

    UraKeys.feed([:none, :none, Input::RIGHT, Input::C, Input::LEFT, Input::C, Input::RIGHT, Input::DOWN,
                  Input::DOWN, Input::C, :none, Input::DOWN, :none, Input::C, :none, Input::B])
    SpeakCapture.clear
    r = ebs.pbItemMenu(0)
    want = ["Medicine", "Poké Balls", "You have no usable items in this pocket.", "Medicine",
            "Medicine, 1/1. Pocion, x3", "Caramelo Raro, x2", T.t(:bb_back), "Caramelo Raro, x2", "msg50",
            T.t(:ura_bag_use), T.t(:ura_bag_dont_use), "Medicine"]
    check "the bag: pockets, an empty pocket's message, the items, the confirmation and back to the pockets",
          [r, SpeakCapture.lines] == [[0, -1], want], [r, SpeakCapture.lines]
    check "the confirmation's first box is queued behind the description",
          SpeakCapture.log.include?([T.t(:ura_bag_use), false]) && PokeAccess::UraniumBattleBag.confirming.nil?,
          SpeakCapture.log
    UraKeys.feed([:none, :none, Input::DOWN, Input::DOWN, Input::DOWN, Input::B])
    SpeakCapture.clear
    ebs.pbItemMenu(0)
    check "reopened: the last-used button names its item", SpeakCapture.lines ==
          ["Medicine", "Berries", "#{T.t(:bb_last)}, Caramelo Raro", "Medicine"], SpeakCapture.lines

    class UraBattle; attr_accessor :doublebattle; end
    class UraFieldBattler < UraBattler; def pokemon; :mon; end; end
    duo = UraBattle.new
    duo.doublebattle = true
    duo.battlers = [["Pika", 0], ["Foe", 1], ["Chu", 2], ["Foe2", 3]].map { |n, i| UraFieldBattler.new(duo, i, n, []) }
    duo_scene = PokeBattle_Scene.new(duo)
    check "the target hook binds", !PokeAccess::Hooks.missing.include?("PokeBattle_Scene#pbChooseTarget"),
          PokeAccess::Hooks.missing
    UraKeys.feed([:none, Input::DOWN, Input::C])
    SpeakCapture.clear
    r = duo_scene.pbChooseTarget(2)
    check "the second battler's targets: a foe, then its partner as an ally, though the old fight window is empty",
          [r, SpeakCapture.lines] == [0, ["Foe, #{T.t(:bt_target_foe)}", "Pika, #{T.t(:bt_target_ally)}"]],
          [r, SpeakCapture.lines]
    check "the chooser is let go when the choice ends", PokeAccess.ivar(duo_scene, :@access_target_chooser).nil?,
          PokeAccess.ivar(duo_scene, :@access_target_chooser)

    UraMon = Struct.new(:hp, :status, :egg)
    class UraMon; def isEgg?; egg; end; end
    duo.party1 = [UraMon.new(20, 0, false), UraMon.new(15, 1, false), UraMon.new(0, 0, false), UraMon.new(30, 0, true)]
    duo.party2 = [UraMon.new(20, 0, false), UraMon.new(20, 0, false)]
    duo.opponent = true
    UraKeys.feed([:none, Input::C])
    SpeakCapture.clear
    r = duo_scene.pbCommandMenuEx(2, [])
    check "a double battle's command menu says whose order it is, queued before the first button",
          [r, SpeakCapture.log] == [0, [["What will Chu do?", false], ["Fight", false]]], [r, SpeakCapture.log]
    balls = [T.t(:ura_balls_mine, :list => [T.t(:ura_balls_ok, :n => 1), T.t(:ura_balls_status, :n => 1),
                                           T.t(:ura_balls_fainted, :n => 2)].join(", ")),
             T.t(:ura_balls_foe, :list => T.t(:ura_balls_ok, :n => 2))].join(". ")
    check "and the info key has the party balls of both sides by their state", PokeAccess::Info.info_text == balls,
          PokeAccess::Info.info_text
    ok = UraMon.new(20, 0, false)
    down = UraMon.new(0, 0, false)
    duo.party1 = [ok, ok, nil, nil, nil, nil, down, down, down]
    duo.party2 = [ok, ok, ok, UraMon.new(20, 1, false), nil, nil, down, ok, ok, ok]
    duo.fullparty2 = true
    UraKeys.feed([:none, Input::C])
    duo_scene.pbCommandMenuEx(2, [])
    drawn = [T.t(:ura_balls_mine, :list => T.t(:ura_balls_ok, :n => 2)),
             T.t(:ura_balls_foe, :list => [T.t(:ura_balls_ok, :n => 5), T.t(:ura_balls_fainted, :n => 1)].join(", "))].join(". ")
    check "only drawn balls count: the player's six slots, not a partner's, and each foe trainer's first three",
          PokeAccess::Info.info_text == drawn, PokeAccess::Info.info_text
    SpeakCapture.clear
    ebs.pbCommonAnimation("Shiny", ura_battle.battlers[1], nil)
    ebs.pbCommonAnimation("Nuclear", ura_battle.battlers[1], nil)
    PokeAccess.say_dialogue("A wild Foe appeared!")
    check "a wild Nuclear Pokemon's entrance is said after its appearance, by name",
          SpeakCapture.lines == ["A wild Foe appeared!", T.t(:ura_nuclear_entry, :name => "Foe")], SpeakCapture.lines
  RUBY

  # Runs the world, the load and the checks in a gen-6 process: [[label, ok, detail], ...], or the raw output.
  def self.run
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
             "ERRS = Harness.load_all('uranium')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{CHECKS}"
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }
    rows = out.to_s.scan(/^CHECK (.*?)\|([01])\|(.*)$/)
    rows.empty? ? out.to_s : rows
  end
end

Suite.define("uranium battle: the EBS command, move and question boxes and the battle bag say their focus") do
  rows = UraniumBattleSpec.run
  if rows.is_a?(String)
    truthy "the ura_battle process ran its checks: #{rows[0, 300]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 17
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end
