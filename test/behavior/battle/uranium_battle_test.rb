require "rbconfig"
require "timeout"

# Uranium's Elite Battle System menus (command, move and question boxes, the target choice), its battle messages and
# bag, driven through loops shaped as Uranium's own in a Ruby of their own, as its classes must exist before the load.
class UraniumBattleTest < PokeAccessTest
  # The key feed and the EBS-shaped classes, declared before the toolkit loads so its hooks find them.
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
    end
    class UraSprite; attr_reader :src_rect; def initialize; @src_rect = UraRect.new; end; end
    def pbPocketNames
      ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]
    end

    class UraMove
      attr_reader :id, :name, :type, :pp, :totalpp
      def initialize(id, name, pp); @id = id; @name = name; @type = 0; @pp = pp; @totalpp = 35; end
    end
    class UraBattler
      attr_reader :index, :name, :moves
      def initialize(battle, index, name, moves); @battle = battle; @index = index; @name = name; @moves = moves; end
      def pokemon; true; end
      def isShadow?; false; end
      def inHyperMode?; false; end
    end
    class UraBattle
      attr_accessor :battlers, :mega, :party1, :party2, :opponent, :fullparty1, :fullparty2, :doublebattle
      def initialize; @battlers = []; end
      def pbOwnedByPlayer?(index); index % 2 == 0; end
      def pbCanMegaEvolve?(i); @mega == i; end
      def pbRegisterMegaEvolution(i); @registered = i; end
      def pbSecondPartyBegin(battlerIndex); ((battlerIndex % 2 == 1) ? @fullparty2 : @fullparty1) ? 6 : 3; end
    end
    UraMon = Struct.new(:hp, :status, :egg)
    class UraMon; def isEgg?; egg; end; end

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
      def pbDisplayPausedMessage(msg); nil; end
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

  # The scenarios, run after the load, each after the suite's reset and printed as "OUTCOME name<TAB>value" (the
  # value marshalled, base64): what the menus returned and what was said.
  SCENARIOS = <<-'RUBY'
    require "timeout"
    $PokemonGlobal ||= Object.new
    class << $PokemonGlobal; attr_accessor :lastUsed; end

    module UraScenarios
      extend self
      MOVES = [UraMove.new(33, "Tackle", 35), UraMove.new(45, "Growl", 40), UraMove.new(0, "", 0),
               UraMove.new(0, "", 0)]
      URANIUM_HOOKS = %w[NewCommandWindow#refreshCommands NewCommandWindow#update NewCommandWindow#text=
                         NewFightWindow#battler= NewFightWindow#update NewFightWindow#megaButtonSet NewChoiceSel#update
                         NewChoiceSel#dispose NewBattleBag#show NewBattleBag#update NewBattleBag#useItem?
                         PokeBattle_Scene#pbCommonAnimation]

      # Runs a scenario after the suite's reset, no target under the cursor, and prints its value or what it raised.
      def outcome(name)
        Reset.before_test
        PokeAccess::Battle.announce_target(nil, -1)
        value = Timeout.timeout(10) { yield }
        puts "OUTCOME #{name}\t#{[Marshal.dump([:ok, value])].pack('m0')}"
      rescue Exception => e
        failure = "#{e.class}: #{e.message} #{e.backtrace.first(3).inspect}"
        puts "OUTCOME #{name}\t#{[Marshal.dump([:error, failure])].pack('m0')}"
      end

      # What was said since the reset, as [text, interrupt] pairs.
      def said; SpeakCapture.log.dup; end

      # A wild single battle: Pika (knowing Tackle and Growl) against Foe; mega is the battler that can mega evolve.
      def single(mega = nil)
        b = UraBattle.new
        b.mega = mega
        b.battlers = [UraBattler.new(b, 0, "Pika", MOVES), UraBattler.new(b, 1, "Foe", [])]
        b
      end

      # A double battle: Pika and Chu against Foe and Foe2.
      def double
        b = UraBattle.new
        b.doublebattle = true
        b.battlers = [["Pika", 0], ["Foe", 1], ["Chu", 2], ["Foe2", 3]].map { |n, i| UraBattler.new(b, i, n, MOVES) }
        b
      end

      # The bag's contents (pocket => [[item, quantity], ...]), the items usable in battle and the last one used.
      def bag(pockets = { 2 => [[1, 3], [50, 2]], 3 => [[25, 1]] }, usable = [1, 50], last_used = 0)
        $PokemonGlobal.lastUsed = last_used
        $PokemonBag = Struct.new(:pockets).new((0..8).map { |i| pockets[i] || [] })
        $ura_usable = usable
      end

      # Runs the block with keys fed one per frame, :none for a frame with no key.
      def run(keys)
        UraKeys.feed(keys)
        yield
      end

      # Party members as their balls are drawn: healthy, fainted, with a status problem.
      def ok(n = 20); UraMon.new(n, 0, false); end
      def down; UraMon.new(0, 0, false); end
      def sick; UraMon.new(15, 1, false); end

      K = Input
      outcome("load") { ERRS }
      outcome("unbound") { PokeAccess::Hooks.missing & URANIUM_HOOKS }

      outcome("move lines") do
        MOVES[0, 2].map do |m|
          probe = NewFightWindow.new
          probe.instance_variable_set(:@battler, UraBattler.new(nil, 0, "Probe", [m]))
          PokeAccess::Battle.read_fight_move(probe)
          line = SpeakCapture.last
          SpeakCapture.clear
          line
        end
      end

      outcome("commands") do
        scene = PokeBattle_Scene.new(single)
        { :ret => run([:none, K::RIGHT, K::RIGHT, K::LEFT, K::C]) { scene.pbCommandMenuEx(0, []) }, :log => said }
      end
      outcome("commands reopened") do
        scene = PokeBattle_Scene.new(single)
        2.times { run([:none, K::C]) { scene.pbCommandMenuEx(0, []) } }
        { :log => said }
      end
      outcome("safari commands") do
        b = single
        b.party1 = [ok]
        b.party2 = [ok]
        scene = PokeBattle_Scene.new(b, true)
        { :ret => run([:none, K::LEFT, K::C]) { scene.pbCommandMenuEx(0, []) }, :log => said,
          :info => PokeAccess::Info.info_text }
      end
      outcome("double commands") do
        scene = PokeBattle_Scene.new(double)
        { :ret => run([:none, K::C]) { scene.pbCommandMenuEx(2, []) }, :log => said }
      end
      outcome("commands, flag raising") do
        b = single
        def b.doublebattle; raise NoMethodError, "doublebattle"; end
        scene = PokeBattle_Scene.new(b)
        { :ret => run([:none, K::C]) { scene.pbCommandMenuEx(0, []) }, :log => said }
      end

      # The info key's text once the command menu of battle's first battler has opened.
      def balls_after(battle)
        run([:none, K::C]) { PokeBattle_Scene.new(battle).pbCommandMenuEx(0, []) }
        PokeAccess::Info.info_text
      end
      outcome("balls") do
        b = double
        flagless = Struct.new(:hp, :status).new(30, 0)
        b.party1 = [ok, sick, down, UraMon.new(30, 0, true), flagless, ok(1)]
        b.party2 = [ok, ok]
        b.opponent = true
        balls_after(b)
      end
      outcome("balls drawn") do
        b = double
        b.party1 = [ok, ok, nil, nil, nil, nil, down, down, down]
        b.party2 = [ok, ok, ok, sick, sick, sick, down, ok, ok, sick]
        b.fullparty2 = true
        b.opponent = true
        balls_after(b)
      end
      outcome("balls single trainer") do
        b = single
        b.party1 = [ok]
        b.party2 = [ok, ok, ok, sick, ok, ok, down]
        b.opponent = true
        balls_after(b)
      end
      outcome("balls wild") do
        b = single
        b.party1 = [ok, down]
        b.party2 = [ok]
        balls_after(b)
      end

      outcome("fight opened") do
        scene = PokeBattle_Scene.new(single(0))
        { :ret => run([:none, K::C]) { scene.pbFightMenu(0) }, :log => said }
      end
      outcome("fight moved") do
        scene = PokeBattle_Scene.new(single)
        { :ret => run([:none, K::RIGHT, K::C]) { scene.pbFightMenu(0) }, :log => said }
      end
      outcome("fight mega toggled") do
        scene = PokeBattle_Scene.new(single(0))
        run([:none, K::A, K::A, K::C]) { scene.pbFightMenu(0) }
        { :log => said }
      end
      outcome("fight reopened") do
        scene = PokeBattle_Scene.new(single)
        run([:none, K::RIGHT, K::C]) { scene.pbFightMenu(0) }
        SpeakCapture.clear
        { :ret => run([:none, K::B]) { scene.pbFightMenu(0) }, :log => said }
      end
      outcome("fight mega gone") do
        battle = single(0)
        scene = PokeBattle_Scene.new(battle)
        run([:none, K::B]) { scene.pbFightMenu(0) }
        battle.mega = nil
        SpeakCapture.clear
        run([:none, K::B]) { scene.pbFightMenu(0) }
        { :log => said }
      end

      outcome("question") do
        scene = PokeBattle_Scene.new(single)
        { :ret => run([:none, K::RIGHT, K::C]) { scene.pbShowCommands("Use next Pokémon?", ["Yes", "No"], 1) },
          :log => said }
      end

      outcome("bag pockets") do
        bag
        scene = PokeBattle_Scene.new(single)
        { :ret => run([:none, :none, K::RIGHT, K::DOWN, K::LEFT, K::DOWN, K::B]) { scene.pbItemMenu(0) }, :log => said }
      end
      outcome("bag empty pocket") do
        bag
        scene = PokeBattle_Scene.new(single)
        run([:none, :none, K::RIGHT, K::C, :none, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end
      outcome("bag pocket opened") do
        bag
        scene = PokeBattle_Scene.new(single)
        run([:none, :none, K::C, K::B, :none, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end
      outcome("bag pocket walked") do
        bag
        scene = PokeBattle_Scene.new(single)
        run([:none, :none, K::C, K::RIGHT, K::DOWN, K::DOWN, K::B, :none, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end
      outcome("bag pages") do
        bag({ 2 => (1..8).map { |id| [id, 1] } }, (1..8).to_a)
        scene = PokeBattle_Scene.new(single)
        run([:none, :none, K::C, K::DOWN, K::DOWN, K::DOWN, K::B, :none, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end
      outcome("bag declined") do
        bag
        scene = PokeBattle_Scene.new(single)
        keys = [:none, :none, K::C, K::RIGHT, K::C, :none, K::DOWN, :none, K::C, :none, K::B]
        { :ret => run(keys) { scene.pbItemMenu(0) }, :log => said }
      end
      outcome("bag accepted") do
        bag
        scene = PokeBattle_Scene.new(single)
        { :ret => run([:none, :none, K::C, K::RIGHT, K::C, :none, K::C]) { scene.pbItemMenu(0) }, :log => said }
      end
      outcome("bag last used") do
        bag({ 2 => [[1, 3], [50, 2]] }, [1, 50], 50)
        scene = PokeBattle_Scene.new(single)
        run([:none, :none, K::DOWN, K::DOWN, K::DOWN, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end
      outcome("bag reopened") do
        bag
        scene = PokeBattle_Scene.new(single)
        2.times { run([:none, :none, K::B]) { scene.pbItemMenu(0) } }
        { :log => said }
      end
      outcome("bag item info") do
        bag
        scene = PokeBattle_Scene.new(single)
        run([:none, :none, K::C, K::RIGHT, K::B, :none, K::B]) { scene.pbItemMenu(0) }
        PokeAccess::Info.info_text
      end

      outcome("target") do
        scene = PokeBattle_Scene.new(double)
        { :ret => run([:none, K::DOWN, K::C]) { scene.pbChooseTarget(2) }, :log => said }
      end
      outcome("target released") do
        scene = PokeBattle_Scene.new(double)
        run([:none, K::C]) { scene.pbChooseTarget(2) }
        SpeakCapture.clear
        scene.pbUpdateSelected(0)
        { :log => said }
      end

      outcome("battle message") do
        PokeBattle_Scene.new(single).pbDisplayMessage("Foe used Growl!")
        log = said
        SpeakCapture.clear
        PokeAccess::Battle.announce_field
        { :log => log, :field => said }
      end
      outcome("paused message") do
        PokeBattle_Scene.new(single).pbDisplayPausedMessage("Pika grew to Lv. 21!")
        { :log => said }
      end

      outcome("nuclear") do
        scene = PokeBattle_Scene.new(single)
        scene.pbCommonAnimation("Nuclear", scene.instance_variable_get(:@battle).battlers[1], nil)
        PokeAccess.say_dialogue("A wild Foe appeared!")
        { :log => said }
      end
      outcome("other animation") do
        scene = PokeBattle_Scene.new(single)
        scene.pbCommonAnimation("Shiny", scene.instance_variable_get(:@battle).battlers[1], nil)
        PokeAccess.say_dialogue("A wild shiny Foe appeared!")
        { :log => said }
      end
      outcome("two nuclear") do
        battle = double
        scene = PokeBattle_Scene.new(battle)
        [1, 3].each { |i| scene.pbCommonAnimation("Nuclear", battle.battlers[i], nil) }
        PokeAccess.say_dialogue("A wild Foe and Foe2 appeared!")
        { :log => said }
      end
    end
  RUBY

  test "the profile loads over the Elite Battle System's classes" do
    assert_equal [], outcome("load")
  end

  test "every hook of its battle readers binds" do
    assert_equal [], outcome("unbound")
  end

  test "every menu still returns the choice the game's loop made" do
    { "commands" => 1, "safari commands" => 3, "double commands" => 0, "commands, flag raising" => 0,
      "fight opened" => 0, "fight moved" => 1, "fight reopened" => -1, "question" => 1, "bag pockets" => [0, -1],
      "bag declined" => [0, -1], "bag accepted" => [50, -1], "target" => 0 }.each do |name, ret|
      assert_equal ret, outcome(name)[:ret], name
    end
  end

  test "the command menu says each button as painted, the first queued" do
    assert_equal [["Fight", false], ["Bag", true], ["Pokemon", true], ["Bag", true]], outcome("commands")[:log]
  end

  test "reopening the command menu says its button again, queued" do
    assert_equal [["Fight", false], ["Fight", false]], outcome("commands reopened")[:log]
  end

  test "the Safari Zone's buttons are said as painted, the fourth still Run" do
    assert_equal [["Ball", false], ["Run", true]], outcome("safari commands")[:log]
  end

  test "a double battle's command menu says whose order it is, queued before the first button" do
    assert_equal [["What will Chu do?", false], ["Fight", false]], outcome("double commands")[:log]
  end

  test "a battle whose double flag raises is taken for a single one, its order's prompt unsaid" do
    assert_equal [["Fight", false]], outcome("commands, flag raising")[:log]
  end

  test "the info key counts each side's party balls by the state they are drawn in" do
    assert_equal balls([ball(:ura_balls_ok, 3), ball(:ura_balls_status, 1), ball(:ura_balls_fainted, 2)],
                       [ball(:ura_balls_ok, 2)]),
                 outcome("balls"),
                 "an egg is drawn fainted, one hit point is healthy, a member with no egg flag counts by its hit points"
  end

  test "the info key counts only the balls drawn: the player's six slots and each foe trainer's first three" do
    assert_equal balls([ball(:ura_balls_ok, 2)], [ball(:ura_balls_ok, 5), ball(:ura_balls_fainted, 1)]),
                 outcome("balls drawn")
  end

  test "against a single trainer the info key counts the foe's first six" do
    assert_equal balls([ball(:ura_balls_ok, 1)], [ball(:ura_balls_ok, 5), ball(:ura_balls_status, 1)]),
                 outcome("balls single trainer")
  end

  test "against a wild Pokemon the info key has only the player's balls" do
    assert_equal balls([ball(:ura_balls_ok, 1), ball(:ura_balls_fainted, 1)], nil), outcome("balls wild")
  end

  test "in the Safari Zone the info key has no balls" do
    assert_equal "", outcome("safari commands")[:info]
  end

  test "the fight menu opens on its move, queued, then says Mega Evolution is ready" do
    assert_equal [[tackle, false], [t(:bt_mega_ready), false]], outcome("fight opened")[:log]
  end

  test "moving along the moves reads each, interrupting" do
    assert_equal [[tackle, false], [growl, true]], outcome("fight moved")[:log]
  end

  test "the Mega Evolution button toggled says on and off" do
    assert_equal [[tackle, false], [t(:bt_mega_ready), false], [t(:bt_mega_on), true], [t(:bt_mega_off), true]],
                 outcome("fight mega toggled")[:log]
  end

  test "reopened, the fight menu says the last move again, queued" do
    assert_equal [[growl, false]], outcome("fight reopened")[:log]
  end

  test "a Mega button left up from an earlier turn is not said once the battler cannot mega evolve" do
    assert_equal [[tackle, false]], outcome("fight mega gone")[:log]
  end

  test "a battle question is said, then its boxes, the first queued" do
    assert_equal [["Use next Pokémon?", false], ["Yes", false], ["No", true]], outcome("question")[:log]
  end

  test "the bag's main screen says each pocket button by the name its header paints, and back" do
    assert_equal [["Medicine", true], ["Poké Balls", true], ["Battle Items", true], ["Berries", true],
                  [t(:bb_back), true]], outcome("bag pockets")[:log]
  end

  test "an empty pocket says the game's message and stays on the pockets" do
    assert_equal [["Medicine", true], ["Poké Balls", true], ["You have no usable items in this pocket.", false]],
                 outcome("bag empty pocket")[:log]
  end

  test "entering a pocket says its name and page with the first item, and leaving says the pocket button again" do
    assert_equal [["Medicine", true], ["Medicine, 1/1. Pocion, x3", true], ["Medicine", true]],
                 outcome("bag pocket opened")[:log]
  end

  test "inside a pocket each item is said as its button paints it, and so is its way back" do
    assert_equal [["Medicine", true], ["Medicine, 1/1. Pocion, x3", true], ["Caramelo Raro, x2", true],
                  [t(:bb_back), true], ["Caramelo Raro, x2", true], ["Medicine", true]],
                 outcome("bag pocket walked")[:log]
  end

  test "a pocket's page is said when the cursor reaches its seventh item" do
    assert_equal [["Medicine", true], ["Medicine, 1/2. Pocion, x1", true], ["Item3, x1", true], ["Item5, x1", true],
                  ["Medicine, 2/2. Item7, x1", true], ["Medicine", true]], outcome("bag pages")[:log]
  end

  test "choosing an item says its description, then the use and don't-use boxes, the first queued" do
    assert_equal [["Medicine", true], ["Medicine, 1/1. Pocion, x3", true], ["Caramelo Raro, x2", true],
                  ["msg50", true], [t(:ura_bag_use), false], [t(:ura_bag_dont_use), true], ["Medicine", true]],
                 outcome("bag declined")[:log], "declined, the bag goes back to its pockets, the boxes said no more"
  end

  test "accepting the item ends the confirmation on its first box" do
    assert_equal [["Medicine", true], ["Medicine, 1/1. Pocion, x3", true], ["Caramelo Raro, x2", true],
                  ["msg50", true], [t(:ura_bag_use), false]], outcome("bag accepted")[:log]
  end

  test "with an item used before, the last-used button names it" do
    assert_equal [["Medicine", true], ["Berries", true], ["#{t(:bb_last)}, Caramelo Raro", true], ["Medicine", true]],
                 outcome("bag last used")[:log]
  end

  test "reopening the bag says its focused button again" do
    assert_equal [["Medicine", true], ["Medicine", true]], outcome("bag reopened")[:log]
  end

  test "the focused item in a pocket is what the info key describes" do
    assert_equal "Caramelo Raro", outcome("bag item info"), "the focused item by the name its button paints"
  end

  test "choosing a target for the second battler says a foe, then its partner as an ally" do
    assert_equal [["Foe, #{t(:bt_target_foe)}", true], ["Pika, #{t(:bt_target_ally)}", true]], outcome("target")[:log]
  end

  test "once the target is chosen, slot 0 is the player's own again" do
    assert_equal [["Pika, #{t(:bt_target_self)}", true]], outcome("target released")[:log]
  end

  test "a battle message is said, queued" do
    assert_equal [["Foe used Growl!", false]], outcome("battle message")[:log]
  end

  test "after a battle message the field key describes that battle" do
    assert_equal [[t(:bt_no_field), true]], outcome("battle message")[:field], "no weather, terrain or field effect"
  end

  test "a paused battle message is said, queued" do
    assert_equal [["Pika grew to Lv. 21!", false]], outcome("paused message")[:log]
  end

  test "a wild Nuclear Pokemon's entrance is said after its appearance, by name" do
    assert_equal [["A wild Foe appeared!", false], [t(:ura_nuclear_entry, :name => "Foe"), false]],
                 outcome("nuclear")[:log]
  end

  test "another animation promises nothing after the message" do
    assert_equal [["A wild shiny Foe appeared!", false]], outcome("other animation")[:log]
  end

  test "two Nuclear entrances before the message are both said after it" do
    assert_equal [["A wild Foe and Foe2 appeared!", false],
                  ["#{t(:ura_nuclear_entry, :name => 'Foe')}. #{t(:ura_nuclear_entry, :name => 'Foe2')}", false]],
                 outcome("two nuclear")[:log]
  end

  # Every scenario's outcome, from one run of the world (a script in a temporary folder, stopped after two minutes),
  # kept for the whole test process: name => [:ok, value] or [:error, message]; a run that printed none keeps its
  # raw output under nil.
  def self.outcomes
    @outcomes ||= Dir.mktmpdir("pa-uranium") do |dir|
      support = File.join(Harness::ROOT, "test", "support")
      path = File.join(dir, "uranium_world.rb")
      File.write(path, "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
                       "ERRS = Harness.load_all('uranium')\n" \
                       "%w[speak_capture reset].each { |f| require File.join(#{support.inspect}, f) }\n" \
                       "SpeakCapture.install\n#{SCENARIOS}")
      out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, path], :err => [:child, :out]) do |io|
        begin
          Timeout.timeout(120) { io.read }
        rescue Timeout::Error
          Process.kill("KILL", io.pid)
          "the world ran past two minutes and was stopped"
        end
      end
      rows = out.to_s.scan(/^OUTCOME (.+?)\t(\S+)$/).map { |name, data| [name, Marshal.load(data.unpack1("m0"))] }
      rows.empty? ? { nil => out.to_s } : rows.to_h
    end
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # The value a scenario of the world ended with; fails with the reason when it raised or never ran.
  def outcome(name)
    all = self.class.outcomes
    flunk "the world printed no outcome: #{all[nil].to_s[0, 400]}" if all.key?(nil)
    status, value = all.fetch(name) { flunk "no outcome named #{name.inspect}" }
    flunk "#{name} raised #{value}" unless status == :ok
    value
  end

  def tackle; move_line(0, "Tackle"); end
  def growl; move_line(1, "Growl"); end

  # What core's move reader says for the world's move at index, in the world's own process, checked to open with the
  # name its button paints.
  def move_line(index, painted)
    line = outcome("move lines")[index]
    assert_match(/\A#{Regexp.escape(painted)}\. /, line.to_s, "the line for #{painted} opens with its painted name")
    line
  end

  def ball(key, n); t(key, :n => n); end

  # The info key's line for party balls: the player's states, then the foe's (nil: no foe trainer).
  def balls(mine, foe)
    parts = [t(:ura_balls_mine, :list => mine.join(", "))]
    parts.push(t(:ura_balls_foe, :list => foe.join(", "))) if foe
    parts.join(". ")
  end
end
