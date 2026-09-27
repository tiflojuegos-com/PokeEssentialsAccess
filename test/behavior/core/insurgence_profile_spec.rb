require "rbconfig"

# The Insurgence profile loaded whole in a process of its own (its overrides would reach every other suite here), over
# stand-ins shaped as Insurgence's own classes: each hook binds, and each override does what its reader expects.
module InsurgenceProfileSpec
  # The Insurgence-shaped classes, declared before the toolkit loads so its hooks find them.
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
        @sprites = { "list" => InsList.new(moves.map { |m| "Mov#{m}" }.push("CANCEL")),
                     "msgwindow" => InsBox.new("Teach which move to Pika?") }
        pbRefreshInfo(moves[0])
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
  RUBY

  # The checks, run after the load; each prints "CHECK label|ok|detail".
  CHECKS = <<-'RUBY'
    def check(label, ok, detail = nil); puts "CHECK #{label}|#{ok ? 1 : 0}|#{detail.inspect}"; end
    t = PokeAccess::I18n
    check "loads whole", ERRS.empty?, ERRS.first(3)
    w = PokeAccess::Config.weather_names
    check "battle weathers renumbered", [w[5], w[6], w[7], w[9]] == [:ins_w_new_moon, :w_harsh_sun, :w_heavy_rain, :w_strong_winds], w
    fw = PokeAccess::Config.field_weather_names
    check "overworld sandstorm and sun", [fw[4], fw[5]] == [:w_sandstorm, :w_sun], fw
    mine = %w[PokemonSummaryScene#drawPageSix PokedexFormScene#pbUpdate PokedexFormScene#pbChooseForm]
    check "every hook of the profile binds", (PokeAccess::Hooks.missing & mine).empty?, PokeAccess::Hooks.missing & mine
    ov = PokeAccess::Hooks.overrides.select { |o| o.include?("game_insurgence") }
    want = ["PokeAccess::Summary.speak_page (game_insurgence)",
            "PokeAccess::Pathfinder.player_passable? (game_insurgence)"]
    check "its overrides are declared", (want - ov).empty?, ov

    sys = Game_System.new
    sys.hm7 = true
    check "a map setting H-Mode7 on reads it off", sys.hm7 == false, sys.hm7
    $game_system = Game_System.new
    $game_system.instance_variable_set(:@hm7, true)
    check "and so does a game saved with it on", $game_system.hm7 == false, $game_system.hm7

    pk = Poke.build(:ev => [1, 2, 3, 4, 5, 6], :ribbons => [])
    sc = PokemonSummaryScene.new(pk)
    SpeakCapture.clear
    sc.drawPageFour(pk)
    check "drawPageFour reads EV and IV", SpeakCapture.last == PokeAccess::InsurgenceSummary.eviv_text(pk), SpeakCapture.lines
    sc.drawPageFive(pk)
    check "drawPageFive reads the moves", SpeakCapture.last == PokeAccess::Summary.moves_text(pk), SpeakCapture.lines
    sc.drawPageSix(pk)
    check "drawPageSix reads the ribbons", SpeakCapture.last == PokeAccess::SummaryGen6.ribbons_text(pk), SpeakCapture.lines

    $PokemonGlobal.surfing = true
    $game_player.x = 1; $game_player.y = 1; $game_player.direction = 2
    def $game_map.passable?(x, y, d); $game_player.x == x && $game_player.y == y && $game_player.direction == d; end
    far = PokeAccess::Pathfinder.player_passable?(4, 4, 6)
    check "afloat, the engine is asked from the tile the search asks about", far == true, far
    check "and the player is put back", [$game_player.x, $game_player.y, $game_player.direction] == [1, 1, 2],
          [$game_player.x, $game_player.y, $game_player.direction]
    $PokemonGlobal.surfing = false

    SpeakCapture.clear
    mr = MoveRelearnerScene.new
    mr.pbStartScene(pk, [5, 6])
    check "the relearner opens on its question and the first move", SpeakCapture.last.to_s.index("Teach which move to Pika?") == 0,
          SpeakCapture.lines
    check "and its list's plain read is muted", PokeAccess.dedicated?(PokeAccess.sprite(mr, "list")), nil
    SpeakCapture.clear
    mr.pbChooseMove
    check "the list's first run says nothing more", SpeakCapture.lines.empty?, SpeakCapture.lines
    mr.pbChooseMove
    check "back on it after a declined question, the question and the focused move again",
          SpeakCapture.last.to_s.index("Teach which move to Pika?") == 0 && SpeakCapture.lines.length == 1, SpeakCapture.lines

    SpeakCapture.clear
    f = PokedexFormScene.new(25)
    f.pbUpdate
    f.pbUpdate
    check "the forms page is said once", SpeakCapture.lines == ["Especie25. #{t.t(:dex_form, :form => 'Male')}"], SpeakCapture.lines
    SpeakCapture.clear
    f.pbChooseForm
    f.pbUpdate
    check "and again with the form chosen", SpeakCapture.lines == ["Especie25. #{t.t(:dex_form, :form => 'Female')}"], SpeakCapture.lines
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

Suite.define("insurgence profile: loaded whole over Insurgence-shaped classes, every hook binds and does its part") do
  rows = InsurgenceProfileSpec.run
  if rows.is_a?(String)
    truthy "the profile process ran its checks: #{rows[0, 300]}", false
  else
    truthy "every check ran (#{rows.length})", rows.length >= 16
    rows.each { |label, ok, detail| Assert.check(label, ok == "1", detail) }
  end
end
