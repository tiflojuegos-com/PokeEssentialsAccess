# The Deluxe Battle Kit's scripted battle speaker and evolution in battle, read by plugins/dbk_battle.rb and, for
# Soulstones 2's edited copy, by games/soulstones2/midbattle.rb: while the name window over a scripted line shows, its
# name leads the next line said, once; the line the evolution writes into its box is said while it runs. Both files'
# hooks are evaluated again over the stand-ins below so they bind, and each test runs one reader's bodies alone.

# The speaker windows as far as the readers go: the name window takes the speaker's name, a trainer's or a plain one,
# and shows while the windows are up, unless the game keeps it hidden (Sky's edit for Royal and World Frontier,
# @noShowNameTrainer).
class Battle::Scene
  SpeakerBox = Struct.new(:text, :visible)
  attr_accessor :noShowNameTrainer

  def pbUpdateSpeakerWindows(speaker = "", _windowskin = "")
    speaker = speaker.name unless speaker.is_a?(String)
    @sprites ||= {}
    win = (@sprites["nameWindow"] ||= SpeakerBox.new("", false))
    win.text = speaker
    win.visible = @showWindows ? true : false
    win.visible = false if @noShowNameTrainer
  end

  def pbShowSpeakerWindows(speaker = "", windowskin = "")
    @showWindows = true
    pbUpdateSpeakerWindows(speaker, windowskin)
  end

  def pbHideSpeakerWindows(_in_speech = false)
    @showWindows = false
    pbUpdateSpeakerWindows
  end
end

# The evolution scene as far as the readers go: the box it writes into, a line, and a frame for the box reader.
class PokemonEvolutionScene
  def initialize(box)
    @sprites = { "msgwindow" => box }
  end

  def pbBattleEvolution(_battler)
    @sprites["msgwindow"].text = "¡Pikachu está evolucionando!"
    PokeAccess::Frame.run_pollers
    :evolved
  end
end

# The bodies each file adds to the two hooks, keyed by hook.
module DbkMidbattleBodies
  KEYS = ["Battle::Scene#pbUpdateSpeakerWindows", "PokemonEvolutionScene#pbBattleEvolution"].freeze

  # Evaluates source (from path, starting at line) and answers the bodies it added to KEYS.
  def self.added(source, path, line)
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    before = Hash[KEYS.map { |k| [k, (chains[k] || []).dup] }]
    eval(source, TOPLEVEL_BINDING, path, line)
    Hash[KEYS.map { |k| [k, (chains[k] || []) - before[k]] }]
  end
end

dbk = File.join(Harness::ROOT, "plugins", "dbk_battle.rb")
dbk_source = Harness.source(dbk)
dbk_at = dbk_source.index('PokeAccess::Hooks.around_hook("PokemonEvolutionScene", :pbBattleEvolution')
DBK_MIDBATTLE = DbkMidbattleBodies.added(dbk_source[dbk_at..-1], dbk, dbk_source[0, dbk_at].count("\n") + 1)
ss2 = File.join(Harness::ROOT, "games", "soulstones2", "midbattle.rb")
SS2_MIDBATTLE = DbkMidbattleBodies.added(Harness.source(ss2), ss2, 1)

class DbkMidbattleGdTest < PokeAccessTest
  Trainer = Struct.new(:name)
  Box = Struct.new(:text)
  READERS = { "plugins/dbk_battle.rb" => DBK_MIDBATTLE, "games/soulstones2/midbattle.rb" => SS2_MIDBATTLE }.freeze

  test "each reader adds one body to each hook" do
    READERS.each do |file, bodies|
      assert_equal [1, 1], DbkMidbattleBodies::KEYS.map { |k| bodies[k].length }, file
    end
  end

  test "the speaker's name leads the next scripted line, once" do
    each_reader do |file|
      Battle::Scene.new.pbShowSpeakerWindows(Trainer.new("Brock"))
      PokeAccess.say_dialogue("¡Mis Pokémon son duros como la roca!")
      PokeAccess.say_dialogue("¡Prepárate!")
      assert_equal [["Brock: ¡Mis Pokémon son duros como la roca!", false], ["¡Prepárate!", false]],
                   SpeakCapture.log, file
    end
  end

  test "a new speaker leads the line after the swap" do
    each_reader do |file|
      scene = Battle::Scene.new
      scene.pbShowSpeakerWindows("Brock")
      PokeAccess.say_dialogue("¡Vamos!")
      scene.pbShowSpeakerWindows("Misty")
      PokeAccess.say_dialogue("¡No tan deprisa!")
      assert_equal ["Brock: ¡Vamos!", "Misty: ¡No tan deprisa!"], SpeakCapture.lines, file
    end
  end

  test "hidden windows lead nothing, and drop a name still pending" do
    each_reader do |file|
      scene = Battle::Scene.new
      scene.pbShowSpeakerWindows("Brock")
      scene.pbHideSpeakerWindows(true)
      PokeAccess.say_dialogue("¡El combate sigue!")
      assert_equal [["¡El combate sigue!", false]], SpeakCapture.log, file
    end
  end

  test "a name window the game keeps hidden leads nothing, though it holds the name" do
    each_reader do |file|
      scene = Battle::Scene.new
      scene.noShowNameTrainer = true
      scene.pbShowSpeakerWindows("Brock")
      PokeAccess.say_dialogue("¡Vamos!")
      assert_equal [["¡Vamos!", false]], SpeakCapture.log, file
    end
  end

  test "the line the evolution writes into its box is said, queued" do
    each_reader do |file|
      PokemonEvolutionScene.new(Box.new("")).pbBattleEvolution(nil)
      assert_equal [["¡Pikachu está evolucionando!", false]], SpeakCapture.log, file
    end
  end

  test "the box is no longer read once the evolution ends, which keeps its own result" do
    each_reader do |file|
      box = Box.new("")
      assert_equal :evolved, PokemonEvolutionScene.new(box).pbBattleEvolution(nil), file
      SpeakCapture.clear
      box.text = "¡Otra línea!"
      PokeAccess::Frame.run_pollers
      assert_nothing_spoken file
    end
  end

  private

  # Runs the block once per reader with only that reader's bodies on the two hooks, from a clean log and no line just
  # said (the dialogue reader drops a repeat within half a second); the hooks' chains and a pending name are put back
  # after each.
  def each_reader
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    READERS.each do |file, bodies|
      kept = Hash[DbkMidbattleBodies::KEYS.map { |k| [k, chains[k]] }]
      begin
        DbkMidbattleBodies::KEYS.each { |k| chains[k] = bodies[k] }
        SpeakCapture.clear
        PokeAccess.instance_variable_set(:@last_say, nil)
        yield file
      ensure
        kept.each { |k, list| chains[k] = list }
        PokeAccess.before_next_line(nil)
      end
    end
  end
end
