# Vitro's map: what stands on it (whirlpools, holes, torches, the Pokemon that walk it), its puzzles of falling boulders and of
# doors, and its services with something to read beyond their messages (the tarot, the savings window), loaded with the whole
# profile over doubles with the shape of its scripts. In a process of its own, since its overrides would reach every other test.
class VitroMapTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    require File.join(Harness::ROOT, "test", "support", "world_builder")
    $game_self_switches = {}

    class << $PokemonGlobal
      attr_accessor :storedRouteMon, :daycare
    end
    $PokemonGlobal.storedRouteMon = {}
    $PokemonGlobal.daycare = [[nil, 0], [nil, 0]]

    # 0228_Creditos: credits joins its lines and goes through show; an entry lives until update drops it.
    class SubtitleSystem
      def initialize; @entries = {}; end

      def show(text, duration = 120, _opts = {})
        @entries[99] = [text, duration]
      end

      def credits(lines, duration = 0, opts = {})
        parts = lines.map do |line_text, type|
          case type
          when :header then "<b>#{line_text}</b>"
          when :spacer then ""
          else line_text.to_s
          end
        end
        show(parts.join("<br>"), duration, opts)
      end

      def active?; !@entries.empty?; end

      def finish; @entries.clear; end

      def update
        TarotFrame.new.tick
        :updated
      end
    end

    class Game_Map
      attr_writer :map_id

      # 0365_OWE_Spawner: answers the new event's id, or nil when the Pokemon has no sprite.
      def spawnPokemonEvent(_x, _y, pokemon, _spawner_id, _encounter_type)
        return nil unless pokemon
        TarotFrame.new.tick
        key = 500 + $PokemonGlobal.storedRouteMon.length
        $PokemonGlobal.storedRouteMon[key] = pokemon
        key
      end
    end

    # What a frame's waiting runs while a card turns: a hook on it fires only if the card's own hook leaves others on.
    class TarotFrame
      def tick; :ticked; end
    end

    # 0344_Tarot: the constructor turns the three cards.
    class TarotAnimation
      def initialize(cartas)
        @cartas = cartas
        reveal_cards
      end

      def reveal_cards
        3.times { |i| reveal_card(:sprite, @cartas[i]) }
      end

      def reveal_card(_sprite, _carta_name)
        TarotFrame.new.tick
      end

      def dispose; :disposed; end
    end

    # 0345_Banco: its window as the \MG code builds it.
    BankWindow = Struct.new(:text)
    def pbDisplayBankWindow(_msgwindow, _goldwindow)
      BankWindow.new("Banco:<br><ar>1000$</ar>")
    end

    class PokeBattle_Battle
      def pbDisplayConfirm(_msg)
        $confirm_info = PokeAccess::Info.info_text
        TarotFrame.new.tick
        :answered
      end
    end

    # 0182_PBattle_BugContest: its second copy, as it paints the comparison before asking.
    class PokeBattle_BugContestBattle < PokeBattle_Battle
      def pbStorePokemon(last)
        return :stored unless last
        pbDrawTextPositions(:overlay, [["Anterior:", 80, 8], ["Ledyba", 80, 32], ["Nuevo:", 80, 88], ["Ledian", 80, 112]])
        pbDrawTextPositions(:overlay, [["Nv.5", 176, 48], ["PS: 20/20", 80, 56], ["Nv.7", 176, 136], ["PS: 15/15", 80, 136]])
        pbDisplayConfirm("¿Quieres cambiar a Ledyba por Ledian?")
      end
    end

    class WildMon
      attr_reader :name

      def initialize(name, shiny = false)
        @name = name
        @shiny = shiny
      end

      def isShiny?; @shiny; end

      def species; 25; end
    end
  RUBY

  PLAY = <<-'RUBY'
    # A map event with the one page it stands with.
    def event(id, name, sprite, list = [], opts = {})
      page = TestPage.new({ :sprite => sprite, :list => list }.merge(opts))
      $game_map.events[id] = TestGameEvent.new(:id => id, :name => name, :x => id, :y => 5, :pages => [page])
    end

    # Names and categories of events built on the map given, its events gone after.
    def on_map(map_id)
      $game_map.map_id = map_id
      $game_map.events.clear
      PokeAccess::World::Mechanics.forget
      yield
    ensure
      $game_map.events.clear
    end

    # One map frame of the puzzles, what it says.
    def puzzle_frame
      said { PokeAccess::Puzzles.tick }
    end

    # The info key's line of the puzzle on this map.
    def puzzle_line
      PokeAccess::Puzzles.state_line(PokeAccess::World::Mechanics.instance.spec)
    end

    def tarot_play
      $frame_ticks = 0
      PokeAccess::Hooks.after_hook("TarotFrame", :tick) { |_f, _r, _a| $frame_ticks += 1 }
      probe(:tarot) do
        animation = nil
        lines = said { animation = TarotAnimation.new(%w[Carta0 Carta16 Carta21]) }
        shown = PokeAccess::Info.info_text
        animation.dispose
        [lines, shown, PokeAccess::Info.instance_variable_get(:@kind), $frame_ticks]
      end
      probe(:tarot_back) do
        animation = TarotAnimation.allocate
        [PokeAccess::VitroTarot.card("Carta_back"), said { PokeAccess::VitroTarot.turned(animation, "Carta_back") },
         animation.instance_variable_get(:@access_cards)]
      end
      probe(:spawn_inside) do
        was = $frame_ticks
        $game_map.spawnPokemonEvent(1, 1, WildMon.new("Pidgey"), 9, 0)
        $frame_ticks - was
      end
      probe(:tarot_cards) do
        names = (0..21).map { |n| PokeAccess::VitroTarot.card("Carta#{n}") }
        [names.compact.uniq.length, PokeAccess::VitroTarot.card("Carta22")]
      end
      probe(:bank) { said { pbDisplayBankWindow(nil, nil) } }
    end

    def wild_play
      loc = PokeAccess::Locator
      plain = WildMon.new("Pidgey")
      shiny = WildMon.new("Zubat", true)
      probe(:wild_names) do
        on_map(3) do
          $PokemonGlobal.storedRouteMon = { 40 => plain, 41 => shiny, 42 => plain }
          [loc.target_name(event(40, "SpawnedPokemon", "016")), loc.target_name(event(41, "PokeBattle", "041")),
           [loc.target_name(event(42, "Pidgeotto", "017")), PokeAccess::VitroWild.pokemon($game_map.events[42])],
           PokeAccess::VitroWild.pokemon(event(43, "SpawnedPokemon", "016")), PokeAccess::Party.shiny_word(shiny)]
        end
      end
      probe(:wild_spawn) do
        $PokemonGlobal.storedRouteMon = {}
        [said { $game_map.spawnPokemonEvent(1, 1, plain, 9, 0) }, said { $game_map.spawnPokemonEvent(1, 1, shiny, 9, 0) },
         said { $game_map.spawnPokemonEvent(1, 1, nil, 9, 0) }, $game_map.spawnPokemonEvent(1, 1, plain, 9, 0)]
      end
      probe(:wild_moved) do
        $PokemonGlobal.storedRouteMon = nil
        [PokeAccess::VitroWild.pokemon(TestGameEvent.new(:id => 40, :name => "SpawnedPokemon")), said { PokeAccess::VitroWild.spawned(40) }]
      end
    end

    def objects_play
      loc = PokeAccess::Locator
      probe(:standing) do
        on_map(8) do
          [["Torbellino/noShadow/sizeC(3,1)", "Torbellino"], ["Holed boulder/noShadow", "Object boulder2"],
           ["CaveMon", "CaveMon"], ["Camera/noShadow", "barril"], ["noShadow", "Peluches_2"], ["/glowsize(100)", "Fuego Vela"],
           ["aspas", "Turbina"], ["Size(2,2)noShadowBoulder", "Armario"], ["noShadow", "Tuberia"]].each_with_index.map do |row, i|
            ev = event(i + 1, row[0], row[1])
            [loc.target_name(ev), loc.event_category(ev)]
          end
        end
      end
      probe(:people_stay) do
        on_map(8) do
          ev = event(1, "Nina", "Nina")
          [loc.target_name(ev), loc.event_category(ev), loc.target_name(event(2, "aspas man", "Senor"))]
        end
      end
      probe(:holes) do
        loc.instance_variable_set(:@mapinfos, { 78 => TestMapInfo.new(78, "Ruta Helada") })
        on_map(77) do
          down = event(5, "Agujero", "", [TestCmd.new(201, [0, 78, 17, 17, 0, 1])], :trigger => 1, :through => true)
          same = event(6, "Agujero", "", [TestCmd.new(201, [0, 77, 5, 16, 0, 1])], :trigger => 1, :through => true)
          [loc.target_name(down), loc.target_name(same), loc.in_category?(down, :exits), loc.in_category?(down, :people)]
        end
      end
      probe(:torch) do
        on_map(29) do
          ev = event(16, "glowswitch(A)/glowsize(200)", "Antorcha Madera", [TestCmd.new(117, [31])])
          unlit = [loc.target_name(ev), loc.event_category(ev), loc.interactable?(ev)]
          $game_self_switches[[29, 16, "A"]] = true
          lit = loc.target_name(ev)
          $game_self_switches[[32, 16, "A"]] = false
          $game_self_switches.delete([29, 16, "A"])
          $game_self_switches[[29, 99, "A"]] = true
          other = loc.target_name(ev)
          [unlit, lit, other, loc.target_name(event(4, "EV004", "Antorcha Madera"))]
        end
      end
      probe(:decor) do
        on_map(3) do
          comment = [TestCmd.new(108, ["noShadow"])]
          [loc.hidden?(event(1, "RegularLight", "light1", comment)), loc.hidden?(event(2, "RegularLight/noShadow", "light1", comment)),
           loc.hidden?(event(3, "Deco/noShadow", "pantallas")), loc.hidden?(event(4, "Healing balls", "Healing balls 1")),
           loc.hidden?(event(5, "Wall middle/noShadow", "elevatorwall")), loc.hidden?(event(6, "Ojos/noShadow", "fx-luz")),
           loc.hidden?(event(7, "Deco", "pantallas", [TestCmd.new(101, ["Hola"])])), loc.hidden?(event(8, "Nina", "Nina"))]
        end
      end
      probe(:dark) do
        [29, 32, 35, 98, 100, 101, 33].map do |map_id|
          on_map(map_id) do
            first = puzzle_frame
            [first, puzzle_frame, PokeAccess::Puzzles.active?, PokeAccess::Puzzles.has_locator_targets?]
          end
        end
      end
    end

    def rocks_play
      probe(:rocks_ice) do
        on_map(77) do
          arrival = puzzle_frame
          quiet = puzzle_frame
          $game_switches[84] = true
          fell = puzzle_frame
          line = puzzle_line
          $game_switches[83] = true
          $game_switches[85] = true
          $game_switches[86] = true
          puzzle_frame
          done = [puzzle_line, PokeAccess::Puzzles.active?]
          [83, 84, 85, 86].each { |id| $game_switches[id] = false }
          [arrival, quiet, fell, line, done, puzzle_frame.length]
        end
      end
      probe(:rocks_each) do
        [[77, [83, 84, 85, 86]], [86, [89, 90, 91]]].map do |map_id, switches|
          on_map(map_id) do
            puzzle_frame
            switches.map do |id|
              $game_switches[id] = true
              one = [puzzle_frame.length, puzzle_line]
              $game_switches[id] = false
              puzzle_frame
              one
            end
          end
        end
      end
      probe(:rocks_gym) do
        on_map(86) do
          arrival = puzzle_frame
          $game_switches[90] = true
          fell = puzzle_frame
          line = puzzle_line
          $game_switches[89] = true
          $game_switches[91] = true
          puzzle_frame
          active = PokeAccess::Puzzles.active?
          [89, 90, 91].each { |id| $game_switches[id] = false }
          [arrival, fell, line, active]
        end
      end
      probe(:rock_map_below) do
        on_map(78) { [puzzle_frame, PokeAccess::World::Mechanics.declared(78)] }
      end
    end

    def doors_play
      loc = PokeAccess::Locator
      probe(:door_names) do
        on_map(128) do
          ids = [23, 17, 20, 21, 22, 18, 19, 24, 16, 25, 27]
          doors = ids.map { |id| loc.target_name(event(id, "PUERTA/size(1,3)", "puertas_lateral")) }
          buttons = [13, 14, 15, 28].map { |id| loc.target_name(event(id, "EV0#{id}", "", [TestCmd.new(355, ["PuzzlePuertas.press_button(:blue)"])])) }
          other = loc.target_name(event(30, "Nina", "Nina"))
          [doors, buttons, other, loc.event_category($game_map.events[23])]
        end
      end
      probe(:door_elsewhere) do
        on_map(127) { loc.target_name(event(13, "EV013", "Nina")) }
      end
      probe(:door_each) do
        on_map(128) do
          (151..161).each { |id| $game_switches[id] = false }
          puzzle_frame
          (151..161).map do |id|
            $game_switches[id] = true
            opened = puzzle_frame
            $game_switches[id] = false
            puzzle_frame
            opened
          end
        end
      end
      probe(:door_flips) do
        on_map(128) do
          $game_player.moveto(9, 11) if $game_player.respond_to?(:moveto)
          (151..160).each { |id| $game_switches[id] = false }
          [152, 153, 154, 156, 157, 159].each { |id| $game_switches[id] = true }
          arrival = puzzle_frame
          [151, 152, 153, 154, 155, 156].each { |id| $game_switches[id] = !$game_switches[id] }
          flips = puzzle_frame
          line = puzzle_line
          [arrival, flips, line, puzzle_frame]
        end
      end
      probe(:door_assist) do
        on_map(128) do
          puzzle_frame
          was = PokeAccess::Config.puzzle_assist
          PokeAccess::Config.puzzle_assist = true
          with = puzzle_line
          PokeAccess::Config.puzzle_assist = was
          [with, puzzle_line]
        end
      end
      probe(:door_area) do
        on_map(128) do
          y = $game_player.y
          $game_player.instance_variable_set(:@y, 10)
          up = PokeAccess::Puzzles.active?
          $game_player.instance_variable_set(:@y, 40)
          down = PokeAccess::Puzzles.active?
          $game_player.instance_variable_set(:@y, y)
          [up, down]
        end
      end
    end

    def credits_play
      probe(:credits) do
        system = SubtitleSystem.new
        page = said do
          system.credits([["Pokémon Essentials", :header], ["Flameguru<tab>Poccil (Peter O.)", :name], ["", :spacer], ["Maruno", :name]], 160)
        end
        shown = PokeAccess::Info.info_text
        system.update
        kept = PokeAccess::Info.info_text
        empty = said { system.show("", 60) }
        still = PokeAccess::Info.info_text
        system.finish
        was = $frame_ticks
        system.update
        [page, shown, kept, empty, still, PokeAccess::Info.instance_variable_get(:@kind), $frame_ticks - was]
      end
    end

    def bug_contest_play
      probe(:contest_compare) do
        battle = PokeBattle_BugContestBattle.new
        was = $frame_ticks
        answer = nil
        lines = said { answer = battle.pbStorePokemon(:a_pokemon) }
        [lines, answer, $confirm_info, PokeAccess::Info.instance_variable_get(:@kind), $frame_ticks - was]
      end
      probe(:contest_first) do
        battle = PokeBattle_BugContestBattle.new
        [said { battle.pbStorePokemon(nil) }, battle.pbStorePokemon(nil), PokeAccess::PaintCapture.armed?(PokeAccess::VitroBugContest::TAG)]
      end
      probe(:other_confirm) do
        pbDrawTextPositions(:overlay, [["Otra", 80, 8]])
        said { PokeBattle_Battle.new.pbDisplayConfirm("¿Seguro?") }
      end
    end

    def day_care_play
      loc = PokeAccess::Locator
      probe(:day_care_species) { PokeAccess::Data.species_name(25) }
      probe(:day_care) do
        on_map(20) do
          $PokemonGlobal.daycare = [[WildMon.new("Bobby"), 0], [nil, 0]]
          kept = [loc.target_name(event(27, "Poke 1", "025")), loc.target_name(event(28, "Poke 0", "")),
                  loc.target_name(event(29, "Poke 2", "Senor"))]
          $PokemonGlobal.daycare = [[nil, 0], [WildMon.new("Rex"), 0]]
          kept + [loc.target_name(event(27, "Poke 1", "")), loc.target_name(event(28, "Poke 0", "026"))]
        end
      end
    end

    tarot_play
    wild_play
    objects_play
    rocks_play
    doors_play
    credits_play
    bug_contest_play
    day_care_play
  RUBY

  profile "vitro", WORLD, PLAY

  def wild(name)
    t(:loc_wild, :name => name)
  end

  test "loads whole, its new hooks bound" do
    assert_equal [], played(:load_errors)
    assert_equal [], played(:missing_hooks).select { |m| m.to_s =~ /Tarot|spawnPokemonEvent/ }
    assert_equal [], played(:absent_functions) & %w[pbDisplayBankWindow]
  end

  test "each card is said queued as it turns, and the info key keeps those shown until the pictures go" do
    lines, shown, kind, ticks = played(:tarot)
    names = [t(:vitro_tarot_fool), t(:vitro_tarot_tower), t(:vitro_tarot_world)]
    assert_equal names.map { |n| [t(:vitro_tarot_card, :name => n), false] }, lines
    assert_equal t(:vitro_tarot_cards, :list => names.join(", ")), shown
    assert_nil kind, "dispose gives the info key back"
    assert_equal 3, ticks, "a turning card leaves the frame's other hooks on"
  end

  test "the back of a card has no name and turning it says nothing, and the 22 cards go each by its own" do
    assert_equal [nil, [], nil], played(:tarot_back)
    assert_equal [22, nil], played(:tarot_cards)
  end

  test "a spawn leaves the frame's other hooks on" do
    assert_equal 1, played(:spawn_inside)
  end

  test "the savings window beside a message is said queued" do
    assert_equal [["Banco: 1000$", false]], played(:bank)
  end

  test "a Pokemon on the map goes by its species, shiny said, and a name that only looks like it does not" do
    spawned, cave, other, none, word = played(:wild_names)
    assert_equal wild("Pidgey"), spawned
    assert_equal "#{wild('Zubat')}, #{word}", cave
    assert_equal ["Pidgeotto", nil], other
    assert_nil none, "with no Pokemon kept for it, it is left to core"
  end

  test "only a shiny spawn is said, queued" do
    plain, shiny, none, id = played(:wild_spawn)
    assert_equal [], plain
    assert_equal 1, shiny.length
    assert_match(/\AZubat/, shiny[0][0])
    assert_equal false, shiny[0][1]
    assert_equal [], none
    assert_kind_of Integer, id, "the game's value still comes back"
  end

  test "with no Pokemon kept yet nothing fails" do
    assert_equal [nil, []], played(:wild_moved)
  end

  test "what stands on the map goes by what it is, filed as an object" do
    names = [t(:vitro_whirlpool), t(:vitro_fallen_rock), t(:vitro_dust_cloud), t(:vitro_camera), t(:vitro_doll), "Fuego Vela",
             "Turbina", "Armario", "Tuberia"]
    assert_equal names.map { |n| [n, :objects] }, played(:standing)
  end

  test "a person keeps name and category" do
    assert_equal ["Nina", :people, "aspas man"], played(:people_stay)
  end

  test "a hole goes by its word and where it leads, as an exit" do
    down, same, exit, person = played(:holes)
    assert_equal "#{t(:vitro_hole)}, #{t(:loc_takes_to, :map => 'Ruta Helada')}", down
    assert_equal t(:vitro_hole), same, "a hole within the map says no map"
    assert_equal [true, false], [exit, person]
  end

  test "a torch says its state by its own self switch, and one with no switch none" do
    unlit, lit, other, plain = played(:torch)
    assert_equal [t(:vitro_torch_unlit), :objects, true], unlit
    assert_equal t(:vitro_torch_lit), lit
    assert_equal t(:vitro_torch_unlit), other, "another event's or another map's switch is not its own"
    assert_equal t(:vitro_torch), plain
  end

  test "lights and decoration with nothing to run stay out of the list" do
    assert_equal [true, true, true, true, true, true, false, false], played(:decor)
  end

  test "a dark map says so on arrival only, and leaves the info key and the list alone" do
    played(:dark)[0, 6].each do |first, again, active, targets|
      assert_equal [[t(:vitro_dark_area), false]], first
      assert_equal [], again
      assert_equal [false, false], [active, targets]
    end
    first, = played(:dark)[6]
    assert_equal [], first, "any other map says nothing"
  end

  test "on the ice floor a boulder's fall is said once, and the info key counts them until all have fallen" do
    arrival, quiet, fell, line, done, off = played(:rocks_ice)
    assert_equal [[t(:vitro_rocks_ice), false]], arrival
    assert_equal [], quiet
    assert_equal [["#{t(:vitro_rock)}: #{t(:vitro_rock_fell)}", false]], fell
    assert_equal "#{t(:vitro_rocks_fallen, :n => 1, :of => 4)} #{t(:vitro_rocks_ice)}", line
    assert_equal false, done[1]
    assert_equal 4, off, "a switch back off is told too"
  end

  test "in the gym the same, with its own rule and three boulders" do
    arrival, fell, line, active = played(:rocks_gym)
    assert_equal [[t(:vitro_rocks_gym), false]], arrival
    assert_equal [["#{t(:vitro_rock)}: #{t(:vitro_rock_fell)}", false]], fell
    assert_equal "#{t(:vitro_rocks_fallen, :n => 1, :of => 3)} #{t(:vitro_rocks_gym)}", line
    assert_equal false, active
  end

  test "every boulder's switch is watched and counted" do
    ice, gym = played(:rocks_each)
    assert_equal [[1, "#{t(:vitro_rocks_fallen, :n => 1, :of => 4)} #{t(:vitro_rocks_ice)}"]] * 4, ice
    assert_equal [[1, "#{t(:vitro_rocks_fallen, :n => 1, :of => 3)} #{t(:vitro_rocks_gym)}"]] * 3, gym
  end

  test "the floor below declares nothing" do
    assert_equal [[], nil], played(:rock_map_below)
  end

  test "each door goes by its place and each button by its colour, only on its map" do
    doors, buttons, other, category = played(:door_names)
    keys = [:vitro_door_top_left, :vitro_door_top_right, :vitro_door_bottom_left, :vitro_door_bottom_right, :vitro_door_left,
            :vitro_door_middle, :vitro_door_right, :vitro_door_exit_top_left, :vitro_door_entrance_top_right,
            :vitro_door_exit_bottom_right, :vitro_door_of_switch]
    assert_equal keys.map { |k| t(:vitro_door_named, :door => t(k)) }, doors
    assert_equal [t(:vitro_button_green), t(:vitro_button_blue), t(:vitro_button_red), t(:vitro_door_switch)], buttons
    assert_equal "Nina", other
    assert_equal :objects, category
    assert_equal "Nina", played(:door_elsewhere), "the same ids on another map are its own"
  end

  test "each door follows its own switch" do
    keys = [:vitro_door_top_left, :vitro_door_top_right, :vitro_door_bottom_left, :vitro_door_bottom_right, :vitro_door_left,
            :vitro_door_middle, :vitro_door_right, :vitro_door_exit_top_left, :vitro_door_entrance_top_right,
            :vitro_door_exit_bottom_right, :vitro_door_of_switch]
    assert_equal keys.map { |k| [["#{t(k)}: #{t(:vitro_door_open)}", false]] }, played(:door_each)
  end

  test "a button's flips are said door by door, queued, and the info key lists every door and the rule" do
    arrival, flips, line, after = played(:door_flips)
    assert_equal [[t(:vitro_doors_rule), false]], arrival
    open = t(:vitro_door_open)
    closed = t(:vitro_door_closed)
    expected = [[:vitro_door_top_left, open], [:vitro_door_top_right, closed], [:vitro_door_bottom_left, closed],
                [:vitro_door_bottom_right, closed], [:vitro_door_left, open], [:vitro_door_middle, closed]]
    assert_equal expected.map { |k, s| ["#{t(k)}: #{s}", false] }, flips
    [:vitro_door_right, :vitro_door_exit_top_left, :vitro_door_entrance_top_right, :vitro_door_exit_bottom_right,
     :vitro_door_of_switch].each do |k|
      assert_includes line, t(k)
    end
    assert_includes line, "#{t(:vitro_door_top_left)}: #{open}"
    assert line.end_with?(t(:vitro_doors_rule)), line
    assert_equal [], after
  end

  test "the assist tells how to open the way, only with it on" do
    with, without = played(:door_assist)
    assert_includes with, t(:vitro_doors_hint)
    refute_includes without, t(:vitro_doors_hint)
  end

  test "the doors answer the info key only in their part of the map" do
    assert_equal [true, false], played(:door_area)
  end

  test "each page of the credits is said queued, its lines and columns apart, and kept for the info key while one is up" do
    page, shown, kept, empty, still, kind, ticks = played(:credits)
    assert_equal 1, ticks, "a page's frame leaves the frame's other hooks on"
    line = "Pokémon Essentials. Flameguru, Poccil (Peter O.). Maruno"
    assert_equal [[line, false]], page
    assert_equal [line, line, line], [shown, kept, still]
    assert_equal [], empty
    assert_nil kind, "the last page gone, the info key goes back"
  end

  test "the Bug Contest's comparison is said as painted, a sentence per Pokemon, as the game asks, and the info key keeps it meanwhile" do
    lines, answer, info, kind, ticks = played(:contest_compare)
    line = "Anterior: Ledyba Nv.5 PS: 20/20. Nuevo: Ledian PS: 15/15 Nv.7"
    assert_equal [[line, false]], lines
    assert_equal :answered, answer, "the game's answer still comes back"
    assert_equal line, info
    assert_nil kind, "answered, the info key goes back"
    assert_equal 1, ticks, "the question's frames leave their hooks on"
  end

  test "a first catch paints nothing and says nothing, and leaves nothing armed" do
    assert_equal [[], :stored, false], played(:contest_first)
  end

  test "any other question says nothing" do
    assert_equal [], played(:other_confirm)
  end

  test "a Day Care event goes by the species of the Pokemon in its slot, the slot crossed as the game's call has it" do
    species = played(:day_care_species)
    assert_equal [species, "Poke 0", "Poke 2", "Poke 1", species], played(:day_care)
  end
end
