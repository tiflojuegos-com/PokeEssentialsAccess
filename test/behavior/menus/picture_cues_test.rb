# PictureCues, the picture name => text table of image-only screens: a shown picture says its text once until it is
# erased, a multibuild text follows the running build, and observers and the picture-menu check see what is shown.
class PictureCuesTest < PokeAccessTest
  Cues = PokeAccess::PictureCues
  Screen = Struct.new(:pictures)
  Picture = Struct.new(:name)

  test "a registered picture shown says its text, interrupting" do
    with_cues("pa_plain" => "texto plano") do
      Game_Picture.new.show("pa_plain", 0, 10, 20)
      assert_equal [["texto plano", true]], SpeakCapture.log
    end
  end

  test "a picture nobody registered says nothing" do
    with_cues("pa_plain" => "texto plano") do
      Game_Picture.new.show("pa_other")
      assert_nothing_spoken
    end
  end

  test "the same picture shown again says nothing" do
    with_cues("pa_plain" => "texto plano") do
      pic = Game_Picture.new
      pic.show("pa_plain")
      SpeakCapture.clear
      pic.show("pa_plain")
      assert_nothing_spoken
    end
  end

  test "once erased, the same picture shown again speaks again" do
    with_cues("pa_plain" => "texto plano") do
      pic = Game_Picture.new
      pic.show("pa_plain")
      pic.erase
      SpeakCapture.clear
      pic.show("pa_plain")
      assert_equal [["texto plano", true]], SpeakCapture.log
    end
  end

  test "only another registered picture in between lets the first speak again" do
    texts = { "pa_a" => "texto a", "pa_b" => "texto b" }
    { %w[pa_a pa_b pa_a] => ["texto a", "texto b", "texto a"],
      %w[pa_a pa_none pa_a] => ["texto a"] }.each do |shown, said|
      with_cues(texts) do
        shown.each { |name| Game_Picture.new.show(name) }
        assert_equal said, SpeakCapture.lines, "for #{shown.inspect}"
        SpeakCapture.clear
      end
    end
  end

  test "a text that names one of the mod's keys is said translated" do
    with_cues("pa_key" => :opt_unavailable) do
      Game_Picture.new.show("pa_key")
      assert_equal [PokeAccess::I18n.t(:opt_unavailable)], SpeakCapture.lines
    end
  end

  test "a multibuild text is the running build's transcription, else its authored language's, else Spanish's" do
    text = { :es => "hola cuadro", :en => "hello picture" }
    rows = { [:en, nil] => "hello picture", [nil, nil] => "hola cuadro", [nil, :en] => "hello picture",
             [:fr, :en] => "hello picture", [:fr, nil] => "hola cuadro", [:es, :en] => "hola cuadro" }
    rows.each do |(build, base), said|
      bases = base ? { "pa_multi" => base } : {}
      with_cues({ "pa_multi" => text }, bases) do
        with_build_language(build) { Game_Picture.new.show("pa_multi") }
        assert_equal [[said, true]], SpeakCapture.log, "build #{build.inspect}, authored in #{base.inspect}"
        SpeakCapture.clear
      end
    end
  end

  test "a multibuild text with no transcription for the running build or its authored language says nothing" do
    with_cues("pa_multi" => { :en => "hello picture" }) do
      Game_Picture.new.show("pa_multi")
      assert_nothing_spoken
    end
  end

  test "an observer hears every picture shown, registered or not, a repeat too, with the show's arguments" do
    heard = []
    with_cues("pa_plain" => "texto plano") do
      with_observer(proc { |name, args| heard.push([name, args]) }) do
        Game_Picture.new.show("pa_plain", 0, 10, 20)
        Game_Picture.new.show("pa_plain", 0, 10, 20)
        Game_Picture.new.show("pa_other", 1)
      end
    end
    assert_equal [["pa_plain", ["pa_plain", 0, 10, 20]], ["pa_plain", ["pa_plain", 0, 10, 20]],
                  ["pa_other", ["pa_other", 1]]], heard
  end

  test "an observer that raises does not keep the next one from hearing the picture" do
    heard = []
    with_cues({}) do
      with_observer(proc { |_name, _args| raise "observer failed" }) do
        with_observer(proc { |name, _args| heard.push(name) }) do
          Game_Picture.new.show("pa_other")
        end
      end
    end
    assert_equal ["pa_other"], heard
  end

  test "a picture menu is showing while a registered picture sits in slots 1 to 50" do
    with_cues("pa_menu" => "menú") do
      { 1 => true, 50 => true, 0 => false, 51 => false }.each do |slot, showing|
        with_screen(screen_showing(slot => "pa_menu")) do
          assert_equal showing, Cues.menu_showing?, "the registered picture in slot #{slot}"
        end
      end
    end
  end

  test "a screen showing only pictures nobody registered is no picture menu" do
    with_cues("pa_menu" => "menú") do
      with_screen(screen_showing(3 => "pa_other", 4 => "", 5 => nil)) do
        assert_equal false, Cues.menu_showing?
      end
    end
  end

  test "with no picture registered, nothing on screen is a picture menu" do
    with_cues({}) do
      with_screen(screen_showing(3 => "pa_menu")) do
        assert_equal false, Cues.menu_showing?
      end
    end
  end

  test "without a screen, or with one whose pictures cannot be read, no picture menu is showing" do
    broken = Object.new
    def broken.pictures; raise IOError, "no pictures yet"; end
    with_cues("pa_menu" => "menú") do
      { "no screen" => nil, "a screen that raises" => broken }.each do |what, screen|
        with_screen(screen) { assert_equal false, Cues.menu_showing?, what }
      end
    end
  end

  private

  # Runs the block with the cue tables holding only texts and bases and the dedup cleared; the profile's own tables
  # and the dedup are put back after.
  def with_cues(texts, bases = {})
    was = [Cues::TEXTS.dup, Cues::BASE_LANG.dup, Cues.instance_variable_get(:@last)]
    Cues::TEXTS.replace(texts)
    Cues::BASE_LANG.replace(bases)
    Cues.reset_last
    yield
  ensure
    Cues::TEXTS.replace(was[0])
    Cues::BASE_LANG.replace(was[1])
    Cues.instance_variable_set(:@last, was[2])
  end

  # Runs the block with the running build's language answering code; nil keeps the harness's build, which declares
  # none.
  def with_build_language(code)
    return yield if code.nil?
    lang = PokeAccess::GameLang
    was = lang.method(:code)
    begin
      lang.define_singleton_method(:code) { code }
      yield
    ensure
      lang.define_singleton_method(:code, was)
    end
  end

  # Runs the block with observer registered for every picture shown, taken out again after.
  def with_observer(observer)
    Cues.register(&observer)
    yield
  ensure
    Cues::HANDLERS.delete(observer)
  end

  # A screen whose picture slots show the given names ({slot => name}), the other slots empty.
  def screen_showing(slots)
    pictures = Array.new(52)
    slots.each { |slot, name| pictures[slot] = Picture.new(name) }
    Screen.new(pictures)
  end

  # Runs the block with $game_screen as screen, the previous one put back after.
  def with_screen(screen)
    was = $game_screen
    $game_screen = screen
    yield
  ensure
    $game_screen = was
  end
end
