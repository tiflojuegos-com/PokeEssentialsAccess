# The title prompt: Luka's styles (plugins/luka_title.rb) and the stock v19+ title say it, the v16/v17 splash
# (core/menus/gen6/title_screen_g6.rb) queues it; each test makes the game's classes and evaluates the readers over them.
class TitleScreensTest < PokeAccessTest
  # Luka S.J.'s Modern Title Screen styles, each built, then made to play its skippable intro, then to wait for a key.
  STYLES = %w[GenOneStyle GenTwoStyle GenThreeStyle GenFourStyle GenFiveStyle GenSixStyle GenSevenStyle GenCustomStyle]

  test "each of Luka's styles says the prompt, queued, once its intro is over, not as it is built" do
    with_title(STYLES.map { |n| [n, Class.new { def intro; :shown; end }] }, ["plugins/luka_title.rb"]) do
      STYLES.each do |name|
        SpeakCapture.clear
        screen = Object.const_get(name).new
        built = SpeakCapture.log.dup
        assert_equal :shown, screen.intro, "#{name} keeps its intro's result"
        assert_equal [[], [[prompt, false]]], [built, SpeakCapture.log], name
      end
    end
  end

  test "Luka's intro keeps the readers of what it shows, the prompt after them" do
    child = Class.new { def read; :read; end }
    style = Class.new do
      def intro
        TitleReadyChild.new.read
        :ready
      end
    end
    with_title([["GenOneStyle", style], ["TitleReadyChild", child]], ["plugins/luka_title.rb"]) do
      PokeAccess::Hooks.after_hook("TitleReadyChild", :read) { |_s, _r, _a| PokeAccess.speak("Nested intro message", false) }
      assert_equal :ready, GenOneStyle.new.intro
    end
    assert_equal [["Nested intro message", false], [prompt, false]], SpeakCapture.log
  end

  test "a Luka intro that fails passes its error on and says no prompt" do
    style = Class.new { def intro; raise "original intro failure"; end }
    with_title([["GenOneStyle", style]], ["plugins/luka_title.rb"]) do
      error = assert_raises(RuntimeError) { GenOneStyle.new.intro }
      assert_equal "original intro failure", error.message
    end
    assert_nothing_spoken
  end

  test "a Luka title opened again says the prompt once for each intro" do
    style = Class.new { def intro; :ready; end }
    with_title([["GenOneStyle", style]], ["plugins/luka_title.rb"]) do
      2.times { GenOneStyle.new.intro }
    end
    assert_equal [[prompt, false]] * 2, SpeakCapture.log
  end

  test "Luka's splash says each picture's transcription, queued, and nothing for one without" do
    intro = Class.new { def cyclePics(_pics, _bgm = nil); :cycled; end }
    with_transcription("intro_city", "Una ciudad bajo la niebla") do
      with_title([["Scene_Intro", intro]], ["plugins/luka_title.rb"]) do
        assert_equal :cycled, Scene_Intro.new.cyclePics(["intro_logo", "intro_city"]), "the splash keeps its result"
      end
    end
    assert_equal [["Una ciudad bajo la niebla", false]], SpeakCapture.log
  end

  test "Luka's splash with no pictures says nothing" do
    intro = Class.new { def cyclePics(_pics); :cycled; end }
    with_title([["Scene_Intro", intro]], ["plugins/luka_title.rb"]) { Scene_Intro.new.cyclePics(nil) }
    assert_nothing_spoken
  end

  test "the stock title says the prompt, interrupting, as it opens" do
    title = Class.new { def open_title_screen(_scene, *_args); :opened; end }
    with_title([["IntroEventScene", title]], ["core/menus/title_screen.rb"]) do
      assert_equal :opened, IntroEventScene.new.open_title_screen(nil), "the title keeps its result"
    end
    assert_equal [[prompt, true]], SpeakCapture.log
  end

  test "the gen-6 splash queues the prompt once it waits for the key" do
    with_title([["IntroEventScene", splash_scene]], ["core/menus/gen6/title_screen_g6.rb"]) do
      assert_equal :splash, IntroEventScene.new.openSplash(nil, nil), "the splash keeps its result"
    end
    assert_equal [[prompt, false]], SpeakCapture.log
  end

  test "a screen run inside the gen-6 splash keeps its own readers" do
    with_title([["IntroEventScene", splash_scene]], ["core/menus/gen6/title_screen_g6.rb"]) do
      scene = IntroEventScene.new
      scene.openSplash(nil, nil)
      assert_equal false, scene.muted
    end
  end

  test "a gen-6 splash the key closed during its fade, the game gone on, is not announced" do
    with_title([["IntroEventScene", splash_scene]], ["core/menus/gen6/title_screen_g6.rb"]) do
      scene = IntroEventScene.new
      scene.closes = true
      scene.openSplash(nil, nil)
    end
    assert_nothing_spoken
  end

  test "a gen-6 splash that cannot tell whether it is gone says the prompt" do
    title = Class.new { def openSplash(_scene, _args); :splash; end }
    with_title([["IntroEventScene", title]], ["core/menus/gen6/title_screen_g6.rb"]) { IntroEventScene.new.openSplash(nil, nil) }
    assert_equal [[prompt, false]], SpeakCapture.log
  end

  private

  # The title prompt: the screen's name, then the key that starts the game while hints are said.
  def prompt
    t = PokeAccess::I18n
    "#{t.t(:title_screen)}. #{t.t(:title_press, :key => t.t(:key_enter))}"
  end

  # The v16/v17 IntroEventScene's splash: it notes whether a hooked screen run inside it would be muted, and is gone
  # once it returns when told to close, as a key pressed during the fade closes it.
  def splash_scene
    Class.new do
      attr_accessor :closes
      attr_reader :muted
      def openSplash(_scene, _args)
        @muted = PokeAccess::Hooks.nested_other?(:pbStartLoadScreen)
        @disposed = true if @closes
        :splash
      end
      def disposed?; @disposed ? true : false; end
    end
  end

  # Runs the block with each [name, class] pair under its game name and the reader files (repo paths) evaluated over
  # them, their hooks bound afresh; the classes and the hook chains kept under those names are put back after.
  def with_title(classes, files)
    names = classes.map { |n, _k| n }
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    ours = lambda { |key| names.include?(key.split("#", 2)[0]) }
    kept_chains = chains.select { |key, _v| ours.call(key) }
    kept = names.map { |n| [n, Object.const_defined?(n, false) ? Object.const_get(n, false) : nil] }
    chains.delete_if { |key, _v| ours.call(key) }
    classes.each do |n, k|
      Object.send(:remove_const, n) if Object.const_defined?(n, false)
      Object.const_set(n, k)
    end
    quietly { files.each { |rel| evaluate(File.join(Harness::ROOT, rel)) } }
    yield
  ensure
    if kept_chains
      chains.delete_if { |key, _v| ours.call(key) }
      chains.update(kept_chains)
    end
    (kept || []).each do |n, k|
      Object.send(:remove_const, n) if Object.const_defined?(n, false)
      Object.const_set(n, k) if k
    end
  end

  # Evaluates a reader file of the mod as the harness loads it, so a mutant under test applies.
  def evaluate(path)
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
  end

  # Runs the block with Ruby's warnings off (evaluating a file again redefines its methods).
  def quietly
    verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = verbose
  end

  # Runs the block with a profile's transcription registered for a splash picture, the table put back after.
  def with_transcription(picture, text)
    texts = PokeAccess::PictureCues::TEXTS
    kept = texts.dup
    texts[picture] = text
    yield
  ensure
    texts.clear
    texts.update(kept)
  end
end
