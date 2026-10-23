require "rbconfig"
require "tempfile"

# The Insurgence profile loaded whole in a process of its own (its overrides would reach every other test here), over
# stand-ins shaped as Insurgence's own classes: it binds, and each of its readers and rules does its part.
class InsurgenceProfileTest < PokeAccessTest
  # The Insurgence-shaped classes, declared before the profile loads so its hooks find them.
  WORLD = <<-'RUBY'
    class Game_System; attr_accessor :hm7; end
    class PokemonSummaryScene; def drawPageSix(pk = nil); (@pokemon = pk) if pk; end; end
    class InsBox; attr_accessor :text; def initialize(t = ""); @text = t; end; end
    class InsList
      attr_accessor :index, :active
      def initialize(commands); @commands = commands; @index = 0; end
    end
    class MoveRelearnerScene
      def pbStartScene(pokemon, moves)
        @pokemon = pokemon
        @moves = moves.dup.push(0)
        @sprites = { "list" => InsList.new(moves.map { |m| "Mov#{m}" }.push("CANCEL")),
                     "msgwindow" => InsBox.new("Teach which move to Pika?") }
        pbRefreshInfo(@moves[0])
      end
      def pbRefreshInfo(move); move; end
      def pbChooseMove
        @sprites["msgwindow"].text = "Teach which move to Pika?"
        Input.update
        pbUpdate
        0
      end
      def pbUpdate; end
    end
    class PokedexFormScene
      def initialize(species); @species = species; @gender = 0; @form = 0; @available = [["Male", 0, 0], ["Female", 1, 0]]; end
      def pbUpdate; nil; end
      def pbChooseForm; @gender = 1; nil; end
    end
    class PokemonMenu
      attr_reader :filed
      def initialize(scene); @scene = scene; end
      def pbStartPokemonMenu; @filed = PokeAccess::Speech.category_of(nil); end
    end
  RUBY

  # The play, run after the load: each probe prints its outcome as "PROBE name base64(Marshal)", or what it raised.
  # The probes run inside a method, as the profile's files are evaluated at the top level, where a local would be the
  # one their hook blocks assign.
  PLAY = <<-'RUBY'
    def probe(name)
      value = begin
                yield
              rescue StandardError, ScriptError => e
                { :probe_raised => "#{e.class}: #{e.message}" }
              end
      puts "PROBE #{name} #{[Marshal.dump(value)].pack('m0')}"
    end

    # A gen-6 move as a Pokemon knows it.
    InsMove = Struct.new(:id, :pp, :totalpp, :type)

    # What one summary page says, drawn first on a summary of a Pokemon with EVs 1 to 6, no ribbons and these moves
    # (move 33 alone by default).
    def summary_page(page, moves = [InsMove.new(33, 30, 35, 0)])
      pk = Poke.build(:ev => [1, 2, 3, 4, 5, 6], :ribbons => [], :moves => moves)
      scene = PokemonSummaryScene.new(pk)
      SpeakCapture.clear
      scene.send(page, pk)
      SpeakCapture.log.dup
    end

    # Whether the world's probe lets the player step from (4, 4) to the right, surfing or not, over a map whose
    # passable? answers open only from the tile the player stands on, facing the way asked, with (4, 4) water when
    # surfing; and where the player stands afterwards.
    def step_from_afar(surfing)
      $PokemonGlobal.surfing = surfing
      $game_map.set_terrain(4, 4, 7) if surfing
      $game_player.x = 1; $game_player.y = 1; $game_player.direction = 2
      def $game_map.passable?(x, y, d); $game_player.x == x && $game_player.y == y && $game_player.direction == d; end
      PokeAccess::World::Probe.forget
      open = PokeAccess::World::Probe.step?(4, 4, 6)
      [open, [$game_player.x, $game_player.y, $game_player.direction]]
    ensure
      $PokemonGlobal.surfing = false
      $game_map.singleton_class.send(:remove_method, :passable?)
      $game_map.clear_grid
    end

    # Where a planned surf moving down from each tile of a fall at (6, 3) and (6, 4), over water at (6, 5), is carried,
    # by tile; the map's tags are put back afterwards.
    def surf_down_falls
      $game_map.set_terrain(6, 3, 8).set_terrain(6, 4, 8).set_terrain(6, 5, 7)
      [[6, 3], [6, 4]].map do |x, y|
        s = PokeAccess::Routes::Moves.falls_step(x, y, 2, 0)
        [[x, y], s && [s.x, s.y]]
      end.to_h
    ensure
      $game_map.init_ledges
    end

    def insurgence_play
      probe(:load_errors) { ERRS }
      probe(:missing_hooks) { PokeAccess::Hooks.missing - CORE_MISSING }
      probe(:overrides) { PokeAccess::Hooks.overrides.select { |o| o.include?("Summary.speak_page") } }
      probe(:battle_weathers) { [5, 6, 7, 9].map { |i| PokeAccess::Battle.weather_name(i) } }
      probe(:field_weathers) { [4, 5].map { |i| PokeAccess::Battle.overworld_weather_name(i) } }

      probe(:hm7) do
        sys = Game_System.new
        sys.hm7 = true
        sys.hm7
      end

      probe(:page_four) { summary_page(:drawPageFour) }
      probe(:page_five) { summary_page(:drawPageFive) }
      probe(:page_five_moveless) do
        { "empty gen-6 slots" => summary_page(:drawPageFive, Array.new(4) { InsMove.new(0, 0, 0, 0) }),
          "slots holding no move" => summary_page(:drawPageFive, [nil, 7]) }
      end
      probe(:page_six) { summary_page(:drawPageSix) }

      probe(:step_afloat) { step_from_afar(true) }
      probe(:step_on_foot) { step_from_afar(false) }

      probe(:fall) { surf_down_falls }

      probe(:relearner) do
        pk = Poke.build(:name => "Pika")
        SpeakCapture.clear
        scene = MoveRelearnerScene.new
        scene.pbStartScene(pk, [5, 6])
        opened = SpeakCapture.log.dup
        muted = PokeAccess.dedicated?(PokeAccess.sprite(scene, "list"))
        SpeakCapture.clear
        scene.pbChooseMove
        first = SpeakCapture.log.dup
        SpeakCapture.clear
        scene.pbChooseMove
        { :opened => opened, :muted => muted, :first_run => first, :again => SpeakCapture.log.dup }
      end

      probe(:relearner_listless) do
        scene = MoveRelearnerScene.new
        scene.pbStartScene(Poke.build(:name => "Pika"), [5, 6])
        scene.pbChooseMove
        scene.instance_variable_set(:@moves, nil)
        SpeakCapture.clear
        scene.pbChooseMove
        SpeakCapture.log.dup
      end

      probe(:form_page) do
        SpeakCapture.clear
        f = PokedexFormScene.new(25)
        f.pbUpdate
        f.pbUpdate
        opened = SpeakCapture.log.dup
        SpeakCapture.clear
        f.pbChooseForm
        f.pbUpdate
        [opened, SpeakCapture.log.dup]
      end

      probe(:pause_menu) do
        menu = PokemonMenu.new(nil)
        menu.pbStartPokemonMenu
        [menu.filed, PokeAccess::Speech.category_of(nil)]
      end
    end
    insurgence_play
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
        File.write("#{ENV['PA_COVERAGE']}_insurgence.json", JSON.generate(out))
      end
    end
  RUBY

  test "loads whole" do
    assert_equal [], played(:load_errors)
  end

  test "binds every hook it declares" do
    assert_equal [], played(:missing_hooks)
  end

  test "takes the override of its summary pages from the six-page summary it declares, not one of its own" do
    assert_includes played(:overrides), "PokeAccess::Summary.speak_page (summary_six_pages)"
    refute_includes played(:overrides), "PokeAccess::Summary.speak_page (game_insurgence)"
  end

  test "names its battle weathers by its own numbers, New Moon at 5" do
    assert_equal [t(:ins_w_new_moon), t(:w_harsh_sun), t(:w_heavy_rain), t(:w_strong_winds)], played(:battle_weathers)
  end

  test "names its overworld sandstorm and sun by its own numbers, over the stock gen-6 ones" do
    assert_equal [t(:w_sandstorm), t(:w_sun)], played(:field_weathers)
  end

  test "reads H-Mode7 off on a map that turns it on" do
    assert_equal false, played(:hm7)
  end

  test "its summary's fourth page is the EV and IV page, in the stock order, with the ability under the rows" do
    rows = [[:st_hp, 1], [:st_atk, 2], [:st_def, 3], [:st_spatk, 5], [:st_spdef, 6], [:st_speed, 4]]
    want = "#{t(:sm_eviv)}. " + rows.map { |key, ev| t(:sm_eviv_row, :stat => t(key), :ev => ev, :iv => 31) }.join(". ")
    assert_equal [["#{want}. #{t(:sum_ability, :a => 'Habilidad1')}", false]], played(:page_four)
  end

  test "its summary's fifth page is the moves page" do
    move = "Mov33. #{t(:mv_type, :t => 'Tipo0')}. #{t(:mv_pp, :pp => 30, :tot => 35)}"
    assert_equal [[t(:sm_moves, :list => move), false]], played(:page_five)
  end

  test "its summary's fifth page says there are no moves when no slot holds a real one" do
    none = [[t(:sm_no_moves), false]]
    assert_equal({ "empty gen-6 slots" => none, "slots holding no move" => none }, played(:page_five_moveless))
  end

  test "its summary's sixth page is the ribbons page" do
    assert_equal [[t(:sm_ribbons_none), false]], played(:page_six)
  end

  test "asks the engine's passable? afloat as if the player stood on the water tile asked from, facing the way asked" do
    assert_equal true, played(:step_afloat)[0]
  end

  test "puts the player back where it stood after asking afloat" do
    assert_equal [1, 1, 2], played(:step_afloat)[1]
  end

  test "asks the engine's passable? on foot with the player where it stands" do
    assert_equal [false, [1, 1, 2]], played(:step_on_foot)
  end

  test "carries a planned surf down into a fall from any of its tiles, its falls having no crest" do
    assert_equal({ [6, 3] => [6, 5], [6, 4] => [6, 5] }, played(:fall))
  end

  test "the move relearner opens on its question and the first move, queued" do
    assert_equal [["Teach which move to Pika? #{first_move}", false]], played(:relearner)[:opened]
  end

  test "the move relearner mutes its list's generic read" do
    assert_equal true, played(:relearner)[:muted]
  end

  test "the move relearner says nothing more as its choice loop first runs" do
    assert_equal [], played(:relearner)[:first_run]
  end

  test "the move relearner says its question and the focused move again, back from a declined question" do
    assert_equal [["Teach which move to Pika? #{first_move}", false]], played(:relearner)[:again]
  end

  test "the move relearner says its question alone, back from a declined question, on a screen keeping no moves" do
    assert_equal [["Teach which move to Pika?", false]], played(:relearner_listless)
  end

  test "the Pokedex forms page is said once however often it repaints, and again with another form chosen" do
    opened, chosen = played(:form_page)
    head = t(:pdx_forms, :name => "Especie25")
    assert_equal [["#{head}. #{t(:dex_form, :form => 'Male')}", true]], opened, "on show, once"
    assert_equal [["#{head}. #{t(:dex_form, :form => 'Female')}", true]], chosen, "after the chooser"
  end

  test "files a line with no category said in its pause menu as a menu's, and on the map as navigation after" do
    assert_equal [:menu, :nav], played(:pause_menu)
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The relearner's first row as the mod words it from the engine's data for move 5: its name, type 0, a status move
  # of power 45 and accuracy 100, 15 of 15 PP.
  def first_move
    "Mov5. #{t(:mv_type, :t => 'Tipo0')}. #{t(:cat_status)}. #{t(:mv_power, :p => 45)}. #{t(:mv_acc, :a => 100)}. " \
      "#{t(:mv_pp, :pp => 15, :tot => 15)}"
  end

  # A probe's outcome in the profile's process; fails the test when the probe raised or was never reached.
  def played(name)
    found = self.class.outcomes
    flunk "the profile's process never reached #{name}: #{self.class.output[0, 400]}" unless found.key?(name.to_s)
    value = found[name.to_s]
    flunk "#{name} raised in the profile's process: #{value[:probe_raised]}" if value.is_a?(Hash) && value.key?(:probe_raised)
    value
  end

  class << self
    # Every probe's outcome by name, the profile's process run once per test process.
    def outcomes
      @outcomes ||= run_profile
    end

    # What the profile's process printed, for a failure's message.
    def output
      outcomes
      @output
    end

    private

    # Runs the world, the load (the core's hooks that do not bind in the stubs noted apart) and the play in a gen-6
    # process, from a file: a script this long does not reach the child whole through a Windows command line.
    def run_profile
      support = File.join(Harness::ROOT, "test", "support")
      script = "#{COVERAGE}\nrequire #{File.join(support, 'harness').inspect}\n#{WORLD}\n" \
               "Harness.load_dir('core')\nCORE_MISSING = PokeAccess::Hooks.missing.dup\n" \
               "Harness.load_dir('games/insurgence')\nERRS = Harness.errors\n" \
               "require #{File.join(support, 'speak_capture').inspect}\n" \
               "require #{File.join(support, 'poke_builder').inspect}\n" \
               "SpeakCapture.install\nPokeAccess::Config.language = :es\n#{PLAY}"
      file = Tempfile.new(["pa_insurgence", ".rb"])
      begin
        file.write(script)
        file.close
        @output = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, file.path], :err => [:child, :out],
                           :chdir => Harness::ROOT) { |io| io.read }.to_s
      ensure
        file.unlink
      end
      @output.scan(/^PROBE (\S+) (\S*)\r?$/).map { |name, data| [name, Marshal.load(data.unpack1("m0"))] }.to_h
    end
  end
end
