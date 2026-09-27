# The title screen's prompt: Luka's sixth and seventh styles (Armonia, Awakening) and the stock v19+ title. The
# classes are made here, this repo's two readers evaluated again over them, and the classes taken away after.
Suite.define("title screens: every Luka style and the stock title say the prompt") do
  made = []
  begin
    { "GenSixStyle" => Class.new { def initialize; end },
      "GenSevenStyle" => Class.new { def initialize; end },
      "IntroEventScene" => Class.new do
        def open_title_screen(_scene, *args); :opened; end
      end }.each do |n, k|
      next if Object.const_defined?(n)
      Object.const_set(n, k)
      made.push(n)
    end
    verbose = $VERBOSE
    begin
      $VERBOSE = nil
      [["plugins", "luka_title"], ["core/menus", "title_screen"]].each do |dir, f|
        path = File.join(Harness::ROOT, dir, "#{f}.rb")
        eval(File.read(path), TOPLEVEL_BINDING, path)
      end
    ensure
      $VERBOSE = verbose
    end
    prompt = PokeAccess::TitleScreen.prompt
    SpeakCapture.clear
    GenSixStyle.new
    eq "Armonia's style", SpeakCapture.lines, [prompt]
    SpeakCapture.clear
    GenSevenStyle.new
    eq "Awakening's style", SpeakCapture.lines, [prompt]
    SpeakCapture.clear
    eq "the stock title keeps its result", IntroEventScene.new.open_title_screen(nil), :opened
    eq "and says the prompt", SpeakCapture.lines, [prompt]
  ensure
    made.each { |n| Object.send(:remove_const, n) }
  end
end

# The v16/v17 title (core/menus/gen6/title_screen_g6.rb; Soulstones, Insurgence, Reborn): the splash with its flashing
# "Press Enter" goes up and waits for the key. Desolation arms the key before the splash's fade, so an early press
# closes the scene and runs the load screen inside openSplash. The class is made here and the reader evaluated again
# over it.
module TitleG6Spec
  # A title scene whose splash records whether a hooked screen inside it would be muted, and closes itself when told
  # to, as a press during the fade does.
  SCENE = Class.new do
    attr_accessor :closes
    def openSplash(_scene, _args)
      @muted = PokeAccess::Hooks.nested_other?(:pbStartLoadScreen)
      @disposed = true if @closes
      :splash
    end
    def muted?; @muted; end
    def disposed?; @disposed ? true : false; end
  end
end

Suite.define("title screens: the gen-6 title says the prompt as its splash goes up") do
  made = !Object.const_defined?(:IntroEventScene)
  Object.const_set(:IntroEventScene, TitleG6Spec::SCENE) if made
  begin
    path = File.join(Harness::ROOT, "core", "menus", "gen6", "title_screen_g6.rb")
    eval(File.read(path), TOPLEVEL_BINDING, path)
    SpeakCapture.clear
    scene = IntroEventScene.new
    eq "the splash keeps its result", scene.openSplash(nil, nil), :splash
    eq "and the prompt is queued behind the opening cards", SpeakCapture.log, [[PokeAccess::TitleScreen.prompt, false]]
    falsy "a screen run inside it keeps its own readers", scene.muted?

    SpeakCapture.clear
    early = IntroEventScene.new
    early.closes = true
    early.openSplash(nil, nil)
    silent "a splash the key closed during its fade, the game gone on, is not announced"
  ensure
    Object.send(:remove_const, :IntroEventScene) if made
  end
end
