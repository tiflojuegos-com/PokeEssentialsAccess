require "rbconfig"
require "timeout"

# Sevii's Elite Battle System in its Next Generation style (command and move buttons, databoxes, the question boxes,
# its bag, the ability strip and the level-up panels), driven through loops shaped as Sevii's own in a Ruby of their
# own, as its classes must exist before the load.
class SeviiBattleTest < PokeAccessTest
  # The key feed and the classes shaped as Sevii's, declared before the toolkit loads so its hooks find them.
  WORLD = <<-'RUBY'
    module SvKeys
      def self.feed(list); @frames = list.dup; @cur = nil; end
      def self.step; @cur = (@frames || []).shift; end
      def self.cur; @cur; end
    end
    class << Input
      def update; SvKeys.step; end
      def trigger?(k); SvKeys.cur == k; end
      def repeat?(k); SvKeys.cur == k; end
    end
    class SvRect
      attr_accessor :x, :y, :width, :height
      def initialize; @x = 0; @y = 0; @width = 0; @height = 0; end
    end
    class SvSprite; attr_reader :src_rect; def initialize; @src_rect = SvRect.new; end; end
    def pbPocketNames
      ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]
    end

    class SvMove
      attr_reader :id, :name, :type, :pp, :totalpp
      def initialize(id, name, pp); @id = id; @name = name; @type = 0; @pp = pp; @totalpp = 35; end
    end
    class SvMon
      attr_accessor :name, :hp, :status, :shiny, :egg, :totalhp, :attack, :defense, :spatk, :spdef, :speed
      def initialize(name, hp = 20, status = 0); @name = name; @hp = hp; @status = status; @shiny = false; end
      def isShiny?; @shiny; end
      def isEgg?; @egg; end
    end
    class SvBattler
      attr_reader :index, :name, :moves, :effects
      attr_accessor :owned, :mega, :ability, :pokemon
      def initialize(battle, index, name, moves)
        @battle = battle; @index = index; @name = name; @moves = moves; @pokemon = SvMon.new(name)
        @owned = false; @mega = false; @ability = 7; @effects = {}
      end
      def level; 30; end
      def isShadow?; false; end
      def inHyperMode?; false; end
      def isMega?; @mega; end
    end
    class SvBattle
      attr_accessor :battlers, :mega, :party1, :party2, :opponent, :doublebattle, :player
      def initialize; @battlers = []; end
      def pbOwnedByPlayer?(index); index % 2 == 0 && !(@player.is_a?(Array) && index == 2); end
      def pbCanMegaEvolve?(i); @mega == i; end
      def pbRegisterMegaEvolution(i); @registered = i; end
      def pbSecondPartyBegin(battlerIndex); 3; end
    end

    class NextGenCommandWindow
      attr_accessor :index, :coolDown
      def initialize(viewport = nil, battle = nil, safari = false, viewport_top = nil)
        @battle = battle; @safaribattle = safari; @index = 0; @coolDown = 0
      end
      def refreshCommands(index)
        poke = @battle.battlers[index]
        cmds = []
        cmds.push(@safaribattle ? "BALL" : "FIGHT")
        cmds.push(@safaribattle ? "BAIT" : "BAG")
        cmds.push(@safaribattle ? "ROCK" : "PARTY")
        cmds.push((poke.isShadow? && poke.inHyperMode?) ? "CALL" : "RUN")
        for i in 0...4
          pbDrawOutlineText(nil, 30 * i, 44 * i, 98, 44, cmds[i], nil, nil, 1)
        end
      end
      def text=(msg); drawLineup; pbDrawOutlineText(nil, -2, 20, 300, 40, msg, nil, nil, 1); end
      def drawLineup; end
      def update; @over = false; end
    end
    class NextGenFightWindow
      attr_accessor :index, :battler, :refreshpos
      attr_reader :nummoves
      def initialize(viewport = nil, battle = nil); @battle = battle; @index = 0; @nummoves = 0; @showMega = false; @frame = 0; end
      def generateButtons
        @nummoves = @battler.moves.select { |m| m && m.id > 0 }.length
        @battler.moves.each { |m| pbDrawOutlineText(nil, 198, 0, 196, 42, m.name, nil, nil, 1) if m.id > 0 }
      end
      def hide; @showMega = false; end
      def megaButton; @showMega = true; end
      def megaButtonTrigger; @frame = (@frame == 44 ? 0 : 44); end
      def update; @over = false; end
    end
    class NextGenDataBox
      attr_reader :battler
      def initialize(battler, doublebattle, viewport = nil, player = nil, scene = nil)
        @battler = battler; @scene = scene; @sprites = {}; @loaded = false
      end
      def disposed?; @sprites["layer1"].nil?; end
      def appear; @sprites["layer1"] = Object.new; @loaded = true; refresh; end
      def getBattler(battler); battler.effects[:illusion] || battler; end
      def refresh; return if !@loaded; :refreshed; end
    end
    class NewChoiceSel
      attr_accessor :index
      def initialize(viewport, commands); @commands = commands; @index = 0; end
      def dispose(scene); nil; end
      def update
        if Input.trigger?(Input::LEFT)
          @index -= 1
          @index = @commands.length - 1 if @index < 0
        elsif Input.trigger?(Input::RIGHT)
          @index += 1
          @index = 0 if @index >= @commands.length
        end
      end
    end
    class NewBattleBag
      attr_reader :index, :ret, :finished
      def pbDisplayMessage(msg); @scene.pbDisplayMessage(msg); end
      def initialize(scene, viewport)
        @scene = scene; $lastUsed = 0 if $lastUsed.nil?; @lastUsed = $lastUsed; @index = 0; @item = 0
        @finished = false; @page = -1; @selPocket = 0; @ret = nil; @sprites = { "sel" => SvSprite.new }
      end
      def drawPocket(pocket, index)
        @pocket = []
        ($sv_bag || []).each { |it| @pocket.push([it[0], it[1]]) if it[2] == index }
        if @pocket.length < 1
          pbDisplayMessage("You have no usable items in this pocket.")
          return
        end
        @pages = @pocket.length / 6
        @pages += 1 if @pocket.length % 6 > 0
        @page = 0; @item = 0; @back = false; @selPocket = pocket; @pname = pbPocketNames[pocket]
      end
      def updatePocket
        @page = @item / 6
        if Input.trigger?(Input::LEFT) && !@back
          @item -= 1 if @item > 0
        elsif Input.trigger?(Input::RIGHT) && !@back
          @item += 1 if @item < @pocket.length - 1
        elsif Input.trigger?(Input::DOWN)
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
      def closeCurrent; @selPocket = 0; @page = -1; @back = false; @ret = nil; end
      def show; @ret = nil; end
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
          elsif Input.trigger?(Input::DOWN)
            index += 1
            index = 0 if index > 1
          end
          break if Input.trigger?(Input::C) || SvKeys.cur.nil?
          Input.update
          @scene.pbGraphicsUpdate
        end
        if index > 0
          @ret = nil
          return false
        end
        @index = 0 if @index == 4 && @lastUsed == 0
        true
      end
      def update
        if @selPocket == 0
          updateMain
        else
          intoPocket if Input.trigger?(Input::C) && !@back
          updatePocket
        end
      end
      def updateMain
        if Input.trigger?(Input::LEFT)
          @index -= 1
          @index += 2 if @index % 2 == 1
          @index = 3 if @index == 4 && !(@lastUsed > 0)
        elsif Input.trigger?(Input::RIGHT)
          @index += 1
          @index -= 2 if @index % 2 == 0
          @index = 2 if @index == 4 && !(@lastUsed > 0)
        elsif Input.trigger?(Input::UP)
          @index -= 2
          @index += 6 if @index < 0
          @index = 5 if @index == 4 && !(@lastUsed > 0)
        elsif Input.trigger?(Input::DOWN)
          @index += 2
          @index -= 6 if @index > 5
          @index = 5 if @index == 4 && !(@lastUsed > 0)
        end
        @doubleback = false
        @finished = false
        if Input.trigger?(Input::C) && !@doubleback && @index < 5
          confirm
        elsif (Input.trigger?(Input::B) || (Input.trigger?(Input::C) && @index == 5)) && @selPocket == 0 && !@doubleback
          @finished = true
        end
      end
      def confirm
        if @index < 4
          if $game_switches[142]
            pbDisplayMessage("You have no usable items in this pocket.")
          else
            drawPocket([2, 3, 5, 7][@index], @index)
          end
        else
          @selPocket = 0; @page = -1; @ret = @lastUsed
        end
      end
      def intoPocket
        @selPocket = 0; @page = -1; @lastUsed = 0
        @lastUsed = @pocket[@item][0] if @pocket[@item][1] > 1
        $lastUsed = @lastUsed
        @ret = @pocket[@item][0]
      end
    end

    class PokeBattle_Scene
      attr_reader :battle
      def initialize(battle, safari = false)
        @battle = battle; @safaribattle = safari; @lastcmd = [0, 0, 0, 0]; @lastmove = [0, 0, 0, 0]; @sprites = {}
        @commandWindow = NextGenCommandWindow.new(nil, battle, safari)
        @fightWindow = NextGenFightWindow.new(nil, battle)
        @bagWindow = NewBattleBag.new(self, nil)
      end
      def pbDisplayMessage(msg, brief = false); nil; end
      def pbDisplayPausedMessage(msg); nil; end
      def pbGraphicsUpdate; Graphics.update; end
      def pbInputUpdate; Input.update; end
      def animateBattleSprites(*a); nil; end
      def pbUpdateSelected(index); index; end
      def pbCommandMenuEx(index, texts, mode = 0)
        cw = @commandWindow
        cw.refreshCommands(index)
        name = @safaribattle ? "Red" : @battle.battlers[index].name
        cw.text = "What will #{name} do?"
        loop do
          pbGraphicsUpdate
          pbInputUpdate
          animateBattleSprites(true)
          cw.update
          return nil if SvKeys.cur.nil?
          if Input.trigger?(Input::LEFT) && cw.coolDown <= 0
            cw.index = (cw.index > 0 ? cw.index - 1 : 3)
          elsif Input.trigger?(Input::RIGHT) && cw.coolDown <= 0
            cw.index = (cw.index < 3 ? cw.index + 1 : 0)
          end
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
        cw.megaButton if @battle.pbCanMegaEvolve?(index) && $game_switches[168] != true
        cw.battler = battler
        last = @lastmove[index]
        cw.index = battler.moves[last].id != 0 ? last : 0
        cw.generateButtons
        loop do
          pbGraphicsUpdate
          pbInputUpdate
          animateBattleSprites(true)
          cw.update
          return nil if SvKeys.cur.nil?
          if Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            cw.index = [0, 1, 2, 3][[1, 0, 3, 2].index(cw.index)]
            cw.index = cw.nummoves - 1 if cw.index < 0
            cw.index = 0 if cw.index > cw.nummoves - 1
          end
          if Input.trigger?(Input::C)
            @ret = cw.index
            @battle.pbRegisterMegaEvolution(index) if mega
            @lastmove[index] = @ret
            break
          elsif Input.trigger?(Input::A)
            if @battle.pbCanMegaEvolve?(index) && $game_switches[168] != true
              mega = !mega
              cw.megaButtonTrigger
            end
          elsif Input.trigger?(Input::B)
            @lastmove[index] = cw.index
            @ret = -1
            break
          end
        end
        10.times { cw.hide } if @ret > -1
        @ret
      end
      def pbShowCommands(msg, commands, defaultValue)
        cw = NewChoiceSel.new(nil, commands)
        loop do
          animateBattleSprites(true)
          pbGraphicsUpdate
          pbInputUpdate
          cw.update
          return nil if SvKeys.cur.nil?
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
        ret = 0
        @bagWindow.show
        loop do
          Input.update
          @bagWindow.update
          return nil if SvKeys.cur.nil?
          break if @bagWindow.finished
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
      def showAbilityMessage(battler, hide = true)
        return if battler.pokemon.nil?
        pbDrawOutlineText(nil, 38, -3, 242, 20, "#{battler.pokemon.name}'s", nil, nil, 0)
        pbDrawOutlineText(nil, 0, 27, 252, 20, PBAbilities.getName(battler.ability), nil, nil, 2)
      end
      def pbLevelUp(pokemon, battler, oldtotalhp, oldattack, olddefense, oldspeed, oldspatk, oldspdef)
        pbTopRightWindow("Max. HP<r>+#{pokemon.totalhp - oldtotalhp}\r\nAttack<r>+#{pokemon.attack - oldattack}\r\n" \
                         "Defense<r>+#{pokemon.defense - olddefense}\r\nSp. Atk<r>+#{pokemon.spatk - oldspatk}\r\n" \
                         "Sp. Def<r>+#{pokemon.spdef - oldspdef}\r\nSpeed<r>+#{pokemon.speed - oldspeed}")
        pbTopRightWindow("Max. HP<r>#{pokemon.totalhp}\r\nAttack<r>#{pokemon.attack}\r\nDefense<r>#{pokemon.defense}\r\n" \
                         "Sp. Atk<r>#{pokemon.spatk}\r\nSp. Def<r>#{pokemon.spdef}\r\nSpeed<r>#{pokemon.speed}")
      end
      def pbTopRightWindow(text); text; end
    end
  RUBY

  # The scenarios, run after the load, each after the suite's reset and printed as "OUTCOME name<TAB>value" (the
  # value marshalled, base64): what the menus returned and what was said.
  SCENARIOS = <<-'RUBY'
    require "timeout"

    module SvScenarios
      extend self
      MOVES = [SvMove.new(33, "Tackle", 35), SvMove.new(45, "Growl", 40), SvMove.new(0, "", 0), SvMove.new(0, "", 0)]
      SEVII_HOOKS = %w[NextGenCommandWindow#refreshCommands NextGenCommandWindow#update NextGenCommandWindow#text=
                       NextGenFightWindow#battler= NextGenFightWindow#update NextGenFightWindow#megaButtonTrigger
                       NextGenDataBox#refresh NewChoiceSel#update NewChoiceSel#dispose NewBattleBag#show
                       NewBattleBag#update NewBattleBag#useItem? PokeBattle_Scene#showAbilityMessage
                       PokeBattle_Scene#pbLevelUp PokeBattle_Scene#pbTopRightWindow]

      # Runs a scenario after the suite's reset, switches off, and prints its value or what it raised.
      def outcome(name)
        Reset.before_test
        $game_switches = Hash.new(false)
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
        b = SvBattle.new
        b.mega = mega
        b.battlers = [SvBattler.new(b, 0, "Pika", MOVES), SvBattler.new(b, 1, "Foe", [])]
        b
      end

      # A double battle: Pika and Chu against Foe and Foe2.
      def double
        b = SvBattle.new
        b.doublebattle = true
        b.battlers = [["Pika", 0], ["Foe", 1], ["Chu", 2], ["Foe2", 3]].map { |n, i| SvBattler.new(b, i, n, MOVES) }
        b
      end

      # The bag's contents as [item, quantity, button] rows, each under the pocket button that lists its kind.
      def bag(rows = [[1, 3, 0], [50, 2, 0], [25, 1, 1]])
        $sv_bag = rows
        $lastUsed = 0
      end

      # Runs the block with keys fed one per frame, :none for a frame with no key.
      def run(keys)
        SvKeys.feed(keys)
        yield
      end

      # A party member as its ball is drawn: healthy, fainted, with a status problem.
      def ok; SvMon.new("Ok", 20, 0); end
      def down; SvMon.new("Down", 0, 0); end
      def sick; SvMon.new("Sick", 15, 1); end

      # A databox for the battle's battler at index, set up as appear does, after the block shapes that battler.
      def box_for(battle, index)
        b = battle.battlers[index]
        yield b if block_given?
        PokeAccess::Battle.set_battle(battle)
        box = NextGenDataBox.new(b, false, nil, nil, PokeBattle_Scene.new(battle))
        { :ret => box.appear, :marks => PokeAccess::Battle.shown_marks(b), :log => said }
      end

      K = Input
      outcome("load") { ERRS }
      outcome("unbound") { PokeAccess::Hooks.missing & SEVII_HOOKS }

      outcome("move lines") do
        MOVES[0, 2].map do |m|
          probe = NextGenFightWindow.new
          probe.instance_variable_set(:@battler, SvBattler.new(nil, 0, "Probe", [m]))
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
      outcome("commands with core labels") do
        scene = PokeBattle_Scene.new(single)
        texts = ["What will Pika do?", "Fight", "Bag", "Pokémon", "Call"]
        { :ret => run([:none, K::LEFT, K::C]) { scene.pbCommandMenuEx(0, texts) }, :log => said }
      end
      outcome("commands reopened") do
        scene = PokeBattle_Scene.new(single)
        2.times { run([:none, K::C]) { scene.pbCommandMenuEx(0, []) } }
        { :log => said }
      end
      outcome("safari commands") do
        b = single
        b.party1 = [ok]
        scene = PokeBattle_Scene.new(b, true)
        { :ret => run([:none, K::LEFT, K::C]) { scene.pbCommandMenuEx(0, []) }, :log => said,
          :info => PokeAccess::Info.info_text }
      end
      outcome("double commands") do
        scene = PokeBattle_Scene.new(double)
        { :ret => run([:none, K::C]) { scene.pbCommandMenuEx(2, []) }, :log => said }
      end
      outcome("partner commands") do
        b = double
        b.player = [:red, :partner]
        scene = PokeBattle_Scene.new(b)
        { :ret => run([:none, K::C]) { scene.pbCommandMenuEx(0, []) }, :log => said }
      end
      outcome("balls") do
        b = single
        b.party1 = [ok, sick, down]
        b.party2 = [ok, ok]
        b.opponent = true
        run([:none, K::C]) { PokeBattle_Scene.new(b).pbCommandMenuEx(0, []) }
        PokeAccess::Info.info_text
      end
      outcome("balls not drawn") do
        begin
          Object.const_set(:SHOWPARTYARROWS, false)
          b = single
          b.party1 = [ok]
          run([:none, K::C]) { PokeBattle_Scene.new(b).pbCommandMenuEx(0, []) }
          PokeAccess::Info.info_text
        ensure
          Object.send(:remove_const, :SHOWPARTYARROWS)
        end
      end

      outcome("fight opened") do
        scene = PokeBattle_Scene.new(single(0))
        { :ret => run([:none, K::C]) { scene.pbFightMenu(0) }, :log => said, :info => PokeAccess::Info.info_text }
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
      outcome("fight mega after a cancel") do
        scene = PokeBattle_Scene.new(single(0))
        run([:none, K::A, K::B]) { scene.pbFightMenu(0) }
        SpeakCapture.clear
        run([:none, K::A, K::C]) { scene.pbFightMenu(0) }
        { :log => said }
      end
      outcome("fight mega switch") do
        $game_switches[168] = true
        scene = PokeBattle_Scene.new(single(0))
        run([:none, K::A, K::C]) { scene.pbFightMenu(0) }
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
        { :ret => run([:none, K::RIGHT, K::DOWN, K::LEFT, K::DOWN, K::B]) { scene.pbItemMenu(0) }, :log => said }
      end
      outcome("bag empty pocket") do
        bag
        scene = PokeBattle_Scene.new(single)
        run([:none, K::DOWN, K::C, :none, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end
      outcome("bag switch") do
        bag
        $game_switches[142] = true
        scene = PokeBattle_Scene.new(single)
        run([:none, K::C, :none, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end
      outcome("bag pocket walked") do
        bag
        scene = PokeBattle_Scene.new(single)
        run([:none, K::C, K::RIGHT, K::DOWN, K::DOWN, K::B, :none, K::B]) { scene.pbItemMenu(0) }
        { :log => said, :info => PokeAccess::Info.info_text }
      end
      outcome("bag pages") do
        bag((1..8).map { |id| [id, 1, 0] })
        scene = PokeBattle_Scene.new(single)
        run([:none, K::C, K::DOWN, K::DOWN, K::DOWN, K::B, :none, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end
      outcome("bag declined") do
        bag
        scene = PokeBattle_Scene.new(single)
        keys = [:none, K::C, K::RIGHT, K::C, :none, K::DOWN, :none, K::C, :none, K::B]
        { :ret => run(keys) { scene.pbItemMenu(0) }, :log => said }
      end
      outcome("bag accepted") do
        bag
        scene = PokeBattle_Scene.new(single)
        { :ret => run([:none, K::C, K::RIGHT, K::C, :none, K::C]) { scene.pbItemMenu(0) }, :log => said }
      end
      outcome("bag last used") do
        bag
        $lastUsed = 50
        scene = PokeBattle_Scene.new(single)
        run([:none, K::DOWN, K::DOWN, K::DOWN, K::B]) { scene.pbItemMenu(0) }
        { :log => said }
      end

      outcome("ability strip") do
        scene = PokeBattle_Scene.new(single)
        scene.showAbilityMessage(scene.battle.battlers[1])
        { :log => said }
      end
      outcome("ability strip of an empty slot") do
        scene = PokeBattle_Scene.new(single)
        battler = scene.battle.battlers[1]
        battler.pokemon = nil
        scene.showAbilityMessage(battler)
        { :log => said }
      end

      outcome("level up") do
        pk = SvMon.new("Pika")
        pk.totalhp = 45; pk.attack = 30; pk.defense = 28; pk.spatk = 25; pk.spdef = 27; pk.speed = 40
        scene = PokeBattle_Scene.new(single)
        scene.pbLevelUp(pk, scene.battle.battlers[0], 42, 28, 28, 37, 24, 27)
        { :log => said }
      end
      outcome("panel outside a level-up") do
        PokeBattle_Scene.new(single).pbTopRightWindow("Max. HP<r>45\r\nAttack<r>30")
        { :log => said }
      end

      outcome("marks of a wild foe") do
        box_for(single, 1) { |b| b.owned = true; b.pokemon.shiny = true; b.mega = true }
      end
      outcome("marks of a trainer's foe") do
        battle = single
        battle.opponent = true
        box_for(battle, 1) { |b| b.owned = true }
      end
      outcome("marks of a disguise") do
        box_for(single, 1) { |b| d = SvMon.new("Zorua"); d.shiny = true; b.effects[:illusion] = d }
      end
      outcome("marks of the player's own") do
        box_for(single, 0) { |b| b.owned = true; b.pokemon.shiny = true }
      end
      outcome("marks before the box is set up") do
        battle = single
        b = battle.battlers[1]
        b.pokemon.shiny = true
        { :ret => NextGenDataBox.new(b, false, nil, nil, PokeBattle_Scene.new(battle)).refresh,
          :marks => PokeAccess::Battle.shown_marks(b), :log => said }
      end
    end
  RUBY

  test "the profile loads over the Next Generation classes" do
    assert_equal [], outcome("load")
  end

  test "every hook of its battle readers binds" do
    assert_equal [], outcome("unbound")
  end

  test "every menu still returns the choice the game's loop made" do
    { "commands" => 1, "commands with core labels" => 3, "safari commands" => 3, "double commands" => 0,
      "fight opened" => 0, "fight moved" => 1, "question" => 1, "bag pockets" => [0, -1], "bag declined" => [0, -1],
      "bag accepted" => [50, -1] }.each do |name, ret|
      assert_equal ret, outcome(name)[:ret], name
    end
  end

  test "the command menu says each button as refreshCommands paints it, the first queued" do
    assert_equal [["FIGHT", false], ["BAG", true], ["PARTY", true], ["BAG", true]], outcome("commands")[:log]
  end

  test "the fourth button is the Run refreshCommands paints, not the Call the scene's labels carry" do
    assert_equal [["FIGHT", false], ["RUN", true]], outcome("commands with core labels")[:log]
  end

  test "reopening the command menu says its button again, queued" do
    assert_equal [["FIGHT", false], ["FIGHT", false]], outcome("commands reopened")[:log]
  end

  test "the Safari Zone's buttons are said as painted, and the info key has no balls" do
    safari = outcome("safari commands")
    assert_equal [[["BALL", false], ["RUN", true]], ""], [safari[:log], safari[:info]]
  end

  test "a double battle's command menu says whose order it is, queued before the first button" do
    assert_equal [["What will Chu do?", false], ["FIGHT", false]], outcome("double commands")[:log]
  end

  test "a double battle beside a partner, who orders the second Pokemon, says no prompt, as a single battle" do
    assert_equal [["FIGHT", false]], outcome("partner commands")[:log]
  end

  test "with SHOWPARTYARROWS off the command menu draws no party balls, and the info key counts none" do
    assert_equal "", outcome("balls not drawn")
  end

  test "the info key counts each side's party balls as the command menu draws them" do
    mine = [t(:ura_balls_ok, :n => 1), t(:ura_balls_status, :n => 1), t(:ura_balls_fainted, :n => 1)].join(", ")
    expected = [t(:ura_balls_mine, :list => mine), t(:ura_balls_foe, :list => t(:ura_balls_ok, :n => 2))].join(". ")
    assert_equal expected, outcome("balls")
  end

  test "the fight menu opens on its move, queued, then says Mega Evolution is ready" do
    assert_equal [[tackle, false], [t(:bt_mega_ready), false]], outcome("fight opened")[:log]
  end

  test "with the fight menu open the info key describes the focused move" do
    assert_match(/Tackle/, outcome("fight opened")[:info].to_s)
  end

  test "moving along the moves reads each, interrupting" do
    assert_equal [[tackle, false], [growl, true]], outcome("fight moved")[:log]
  end

  test "the Mega Evolution button pressed says on and off" do
    assert_equal [[tackle, false], [t(:bt_mega_ready), false], [t(:bt_mega_on), true], [t(:bt_mega_off), true]],
                 outcome("fight mega toggled")[:log]
  end

  test "the Mega Evolution button starts off on every opening, also after one left with it on" do
    assert_equal [[tackle, false], [t(:bt_mega_ready), false], [t(:bt_mega_on), true]],
                 outcome("fight mega after a cancel")[:log]
  end

  test "with switch 168 on the Mega Evolution button is neither said nor pressed" do
    assert_equal [[tackle, false]], outcome("fight mega switch")[:log]
  end

  test "a battle question is said, then its boxes, the first queued" do
    assert_equal [["Use next Pokémon?", false], ["Yes", false], ["No", true]], outcome("question")[:log]
  end

  test "the bag's main screen says each pocket button by the name its list's header paints, and back" do
    assert_equal [["Medicine", true], ["Poké Balls", true], ["Battle Items", true], ["Berries", true],
                  [t(:bb_back), true]], outcome("bag pockets")[:log]
  end

  test "a pocket with nothing usable says the game's message and stays on the pockets" do
    assert_equal [["Medicine", true], ["Berries", true], ["You have no usable items in this pocket.", false]],
                 outcome("bag empty pocket")[:log]
  end

  test "with switch 142 on a pocket says the game's message and stays on the pockets" do
    assert_equal [["Medicine", true], ["You have no usable items in this pocket.", false]], outcome("bag switch")[:log]
  end

  test "inside a pocket each item is said as its button paints it, headed by the pocket and page" do
    walked = outcome("bag pocket walked")
    assert_equal [["Medicine", true], ["Medicine, 1/1. Pocion, x3", true], ["Caramelo Raro, x2", true],
                  [t(:bb_back), true], ["Caramelo Raro, x2", true], ["Medicine", true]], walked[:log]
    assert_equal "Caramelo Raro", walked[:info], "the focused item is what the info key describes"
  end

  test "a pocket's page is said when the cursor reaches its seventh item" do
    assert_equal [["Medicine", true], ["Medicine, 1/2. Pocion, x1", true], ["Item3, x1", true], ["Item5, x1", true],
                  ["Medicine, 2/2. Item7, x1", true], ["Medicine", true]], outcome("bag pages")[:log]
  end

  test "choosing an item says its description, then the use and don't-use boxes, the first queued" do
    assert_equal [["Medicine", true], ["Medicine, 1/1. Pocion, x3", true], ["Caramelo Raro, x2", true],
                  ["msg50", true], [t(:ura_bag_use), false], [t(:ura_bag_dont_use), true], ["Medicine", true]],
                 outcome("bag declined")[:log], "declined, the bag goes back to its pockets"
  end

  test "accepting the item ends the confirmation on its first box" do
    assert_equal [["Medicine", true], ["Medicine, 1/1. Pocion, x3", true], ["Caramelo Raro, x2", true],
                  ["msg50", true], [t(:ura_bag_use), false]], outcome("bag accepted")[:log]
  end

  test "with an item used before, the last-used button names it" do
    assert_equal [["Medicine", true], ["Berries", true], ["#{t(:bb_last)}, Caramelo Raro", true], ["Medicine", true]],
                 outcome("bag last used")[:log]
  end

  test "the ability strip says the Pokemon and the ability it paints, queued" do
    assert_equal [[t(:bt_ability, :name => "Foe", :ability => "Habilidad7"), false]], outcome("ability strip")[:log]
  end

  test "an ability strip with no Pokemon paints nothing and says nothing" do
    assert_equal [], outcome("ability strip of an empty slot")[:log]
  end

  test "a level-up says the gains, then the totals panel as written" do
    gains = [t(:lvl_stat, :stat => t(:st_hp), :n => 3), t(:lvl_stat, :stat => t(:st_atk), :n => 2),
             t(:lvl_stat, :stat => t(:st_spatk), :n => 1), t(:lvl_stat, :stat => t(:st_speed), :n => 3)].join(", ")
    totals = "Max. HP 45. Attack 30. Defense 28. Sp. Atk 25. Sp. Def 27. Speed 40"
    assert_equal [[gains, false], [totals, false]], outcome("level up")[:log]
  end

  test "a stat panel shown outside a level-up is said whole" do
    assert_equal [["Max. HP 45. Attack 30", false]], outcome("panel outside a level-up")[:log]
  end

  test "a wild foe's databox keeps its shiny name, caught ball and Mega symbol, said as it enters" do
    marks = [t(:pk_shiny), t(:dex_caught), t(:bt_mark_mega)]
    box = outcome("marks of a wild foe")
    assert_equal [:refreshed, marks, [[t(:bt_marks_entry, :name => "Foe", :marks => marks.join(", ")), false]]],
                 [box[:ret], box[:marks], box[:log]]
  end

  test "a trainer's foe gets no caught ball" do
    assert_equal [], outcome("marks of a trainer's foe")[:marks]
  end

  test "under Illusion the gold name is the disguise's" do
    assert_equal [t(:pk_shiny)], outcome("marks of a disguise")[:marks]
  end

  test "the player's own databox keeps its marks without saying them nor drawing the caught ball" do
    box = outcome("marks of the player's own")
    assert_equal [[t(:pk_shiny)], []], [box[:marks], box[:log]]
  end

  test "a databox not yet set up keeps no marks" do
    box = outcome("marks before the box is set up")
    assert_equal [nil, [], []], [box[:ret], box[:marks], box[:log]]
  end

  # Every scenario's outcome, from one run of the world (a script in a temporary folder, stopped after two minutes),
  # kept for the whole test process: name => [:ok, value] or [:error, message]; a run that printed none keeps its
  # raw output under nil.
  def self.outcomes
    @outcomes ||= Dir.mktmpdir("pa-sevii") do |dir|
      support = File.join(Harness::ROOT, "test", "support")
      path = File.join(dir, "sevii_world.rb")
      File.write(path, "require #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
                       "ERRS = Harness.load_all('sevii')\n" \
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
end
