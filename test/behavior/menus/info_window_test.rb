# InfoWindow, gen-6 pass: a watched window is said when it changes, only while its screen is up; a focused-row one from
# its reading's level, joining the info key's row; the painted dex header leaves out what the list reader says.

# A screen with the engine's lifecycle (pbStartScene builds it, pbEndScene closes it) and two text windows.
class SpecInfoScene
  attr_reader :sprites
  def initialize; @sprites = { "bottom" => FakeTextWin.new, "info" => FakeTextWin.new }; end
  def pbStartScene; :opened; end
  def pbEndScene; :closed; end
end

# A screen with two openers of its own and no pbStartScene, as Fire Ash's swap screen; each writes the help window.
class SpecOwnOpenerScene
  attr_reader :sprites
  def initialize; @sprites = { "help" => FakeTextWin.new }; end
  def pbStartRentScene(_a); @sprites["help"].text = "Elige tres"; end
  def pbStartSwapScene(_a, _b); @sprites["help"].text = "Elige uno"; end
  def pbEndScene; :closed; end
end

# A screen with a close and no opener at all.
class SpecNoOpenerScene
  attr_reader :sprites
  def initialize; @sprites = { "help" => FakeTextWin.new }; end
  def pbEndScene; :closed; end
end

# A screen whose opener writes a title and a text box in the same frame.
class SpecBuffScene
  attr_reader :sprites
  def initialize; @sprites = { "title" => FakeTextWin.new, "textbox" => FakeTextWin.new }; end
  def pbStartScene; @sprites["title"].text = "Mejoras (Sync)"; @sprites["textbox"].text = "Pulsa Enter."; end
  def pbEndScene; :closed; end
end

# A screen whose opener paints its title, and whose close a farewell, through methods another reader hooks, which
# says what they paint.
class SpecPaintScene
  attr_reader :sprites
  def initialize; @sprites = { "help" => FakeTextWin.new }; end
  def pbStartScene; paint_title; end
  def paint_title; :painted; end
  def pbEndScene; paint_farewell; end
  def paint_farewell; :painted; end
end
PokeAccess::Hooks.after_hook("SpecPaintScene", :paint_title) { |_s, _r, _a| PokeAccess.speak("Mejoras", false) }
PokeAccess::Hooks.after_hook("SpecPaintScene", :paint_farewell) { |_s, _r, _a| PokeAccess.speak("Hasta pronto", false) }

# A screen with an opener and nothing else: no close, no start.
class SpecOpenOnlyScene
  attr_reader :sprites
  def initialize; @sprites = { "help" => FakeTextWin.new("Ayuda") }; end
  def pbStartScene; :opened; end
end

# A shop screen whose count window belongs to the focused row.
class SpecShopScene
  attr_reader :sprites
  def initialize; @sprites = { "count" => FakeTextWin.new("En la mochila: 2") }; end
  def pbStartScene; :opened; end
  def pbEndScene; :closed; end
end

class InfoWindowTest < PokeAccessTest
  # A window that can be hidden, as the gamedata era's are.
  Win = Struct.new(:text, :visible)

  test "reads a watched window only once its screen opens" do
    with_watch("SpecInfoScene", "bottom", :spec_bottom) do
      scene = SpecInfoScene.new
      scene.sprites["bottom"].text = "<ac>Ruta 3"
      assert_equal [], ticked, "before the screen opens"
      scene.pbStartScene
      assert_equal [["Ruta 3", false]], ticked, "once it is open"
    end
  end

  test "speaks a watched window of the open screen, queued, its markup flattened into fields" do
    with_watch("SpecInfoScene", "bottom", :spec_bottom) do
      fields = { "<ac>Ruta 3" => "Ruta 3", "Registrados <r>12" => "Registrados, 12", "Ruta<br>3,000 m" => "Ruta, 3,000 m" }
      fields.each do |raw, said|
        scene = opened(SpecInfoScene)
        scene.sprites["bottom"].text = raw
        assert_equal [[said, false]], ticked, "for #{raw.inspect}"
      end
    end
  end

  test "says a window again only when its text changes" do
    with_watch("SpecInfoScene", "bottom", :spec_bottom) do
      scene = opened(SpecInfoScene)
      scene.sprites["bottom"].text = "<ac>Ruta 3"
      ticked
      assert_equal [], ticked, "a frame where it did not change"
      scene.sprites["bottom"].text = "<ac>Ciudad Verde"
      assert_equal [["Ciudad Verde", false]], ticked, "a rewrite"
    end
  end

  test "says a window rewritten after a clear, but not one whose text went missing" do
    with_watch("SpecInfoScene", "bottom", :spec_bottom) do
      scene = opened(SpecInfoScene)
      window = scene.sprites["bottom"]
      window.text = "Ruta 3"
      ticked
      window.text = ""
      assert_equal [], ticked, "a cleared window says nothing"
      window.text = "Ruta 3"
      assert_equal [["Ruta 3", false]], ticked, "and the same text written again is said"
      window.text = nil
      ticked
      window.text = "Ruta 3"
      assert_equal [], ticked, "a window that lost its text keeps the last one said"
    end
  end

  test "leaves the screen's undeclared windows unread" do
    with_watch("SpecInfoScene", "bottom", :spec_bottom) do
      scene = opened(SpecInfoScene)
      scene.sprites["bottom"].text = "<ac>Ruta 3"
      scene.sprites["info"].text = "Registrados <r>12"
      assert_equal [["Ruta 3", false]], ticked
    end
  end

  test "stops reading the windows once the screen closes" do
    with_watch("SpecInfoScene", "bottom", :spec_bottom) do
      scene = opened(SpecInfoScene)
      scene.sprites["bottom"].text = "<ac>Ruta 3"
      assert_equal [["Ruta 3", false]], ticked, "while open"
      scene.pbEndScene
      scene.sprites["bottom"].text = "<ac>Pueblo Paleta"
      assert_equal [], ticked, "once closed"
    end
  end

  test "is driven by the frame poller, with nobody calling tick" do
    with_watch("SpecInfoScene", "bottom", :spec_bottom) do
      scene = opened(SpecInfoScene)
      scene.sprites["bottom"].text = "<ac>Ruta 3"
      SpeakCapture.clear
      PokeAccess::Frame.run_pollers
      assert_equal [["Ruta 3", false]], SpeakCapture.log
    end
  end

  test "binds a screen by the game's own openers, noting no missing hook for the default ones it lacks" do
    with_own_openers do |bound|
      assert_equal true, bound
      assert_equal [], PokeAccess::Hooks.missing.grep(/SpecOwnOpenerScene/)
    end
  end

  test "enters a screen by each of its own openers, queuing an interrupting window's first read at each" do
    with_own_openers do
      scene = SpecOwnOpenerScene.new
      scene.pbStartRentScene([])
      assert_equal [["Elige tres", false]], ticked, "the first opener"
      scene.pbStartSwapScene(nil, nil)
      assert_equal [["Elige uno", false]], ticked, "the second, which a first-match-wins bind would leave mute"
      scene.sprites["help"].text = "Elige dos"
      assert_equal [["Elige dos", true]], ticked, "a later change cuts in"
    end
  end

  test "takes no watch for a screen with no opener, and names it for the diagnostic" do
    iw = PokeAccess::InfoWindow
    unentered = iw.unentered.dup
    assert_equal false, iw.watch("SpecNoOpenerScene", "help", :spec_shut)
    assert_includes iw.unentered, "SpecNoOpenerScene"
  ensure
    iw.watches.reject! { |w| w[2] == :spec_shut }
    iw.unentered.replace(unentered)
  end

  test "takes no watch for a class the game lacks" do
    assert_equal false, PokeAccess::InfoWindow.watch("SpecMissingScene", "help", :spec_missing)
    assert_equal [], PokeAccess::InfoWindow.watches.select { |w| w[2] == :spec_missing }
  end

  test "leaves the readers of what a screen's opener paints speaking" do
    with_watch("SpecPaintScene", "help", :spec_paint) do
      SpeakCapture.clear
      SpecPaintScene.new.pbStartScene
      assert_equal [["Mejoras", false]], SpeakCapture.log
    end
  end

  test "leaves the readers of what a screen's close paints speaking" do
    with_watch("SpecPaintScene", "help", :spec_paint) do
      scene = opened(SpecPaintScene)
      SpeakCapture.clear
      scene.pbEndScene
      assert_equal [["Hasta pronto", false]], SpeakCapture.log
    end
  end

  test "enters a screen by the one opener it has, noting no missing hook for the openers and close it lacks" do
    with_watch("SpecOpenOnlyScene", "help", :spec_open_only) do
      opened(SpecOpenOnlyScene)
      assert_equal [["Ayuda", false]], ticked
      assert_equal [], PokeAccess::Hooks.missing.grep(/SpecOpenOnlyScene/), "the diagnostic's missing hooks"
    end
  end

  test "watches a screen run by start for as long as start runs" do
    scene = PokemonPhoneScene.new
    scene.nav = ["Ruta 3", "Ciudad Verde"]
    SpeakCapture.clear
    scene.start
    assert_equal [["Ruta 3", false], ["Registrados, 12", false], ["Ciudad Verde", false]], SpeakCapture.log,
                 "every contact the cursor walked over, and the totals, from inside start"
    scene.sprites["bottom"].text = "<ac>Pueblo Paleta"
    assert_equal [], ticked, "nothing once start returns"
  end

  test "queues an interrupting window on the frame its screen opens, and lets it cut in after" do
    iw = PokeAccess::InfoWindow
    iw.watch("SpecBuffScene", "title", :spec_buff_title)
    iw.watch("SpecBuffScene", "textbox", :spec_buff_box, :interrupt => true)
    scene = SpecBuffScene.new
    scene.pbStartScene
    assert_equal [["Mejoras (Sync)", false], ["Pulsa Enter.", false]], ticked, "both in the order they are declared"
    scene.sprites["textbox"].text = "Cuesta x1.5 creditos."
    assert_equal [["Cuesta x1.5 creditos.", true]], ticked
  ensure
    iw.watches.reject! { |w| w[2] == :spec_buff_title || w[2] == :spec_buff_box }
  end

  test "reads the gen-6 dex header's three windows as the list opens, each once" do
    scene = PokemonPokedexScene.new
    scene.pbStartScene
    scene.sprites["seen"].text = "Vistos: 42"
    scene.sprites["owned"].text = "Capturados: 40"
    scene.sprites["dexname"].text = "Pokédex de Kanto"
    assert_equal [["Vistos: 42", false], ["Capturados: 40", false], ["Pokédex de Kanto", false]], ticked
    assert_equal [], ticked, "a second frame, each window on its own dedup slot"
  end

  test "says a focused-row window from its reading's level up" do
    with_watch("SpecShopScene", "count", :spec_count, :reading => [:shop_item, :medium]) do
      opened(SpecShopScene)
      PokeAccess::Config.verbosity = :brief
      assert_equal [], ticked, "brief"
      PokeAccess::Config.verbosity = :medium
      assert_equal [["En la mochila: 2", false]], ticked, "medium"
    end
  end

  test "follows a focused-row window's own reading in a player's scheme" do
    with_watch("SpecShopScene", "count", :spec_count, :reading => [:shop_item, :medium]) do
      { [:brief, :full] => [], [:medium, :brief] => [["En la mochila: 2", false]] }.each do |(shop, others), said|
        got = with_scheme("Tienda", :shop_item => shop, :others => others) do
          opened(SpecShopScene)
          ticked
        end
        assert_equal said, got, "the shop's reading at #{shop}, the others at #{others}"
      end
    end
  end

  test "adds a focused-row window to the row the info key repeats whole, at any level" do
    with_watch("SpecShopScene", "count", :spec_count, :reading => [:shop_item, :medium]) do
      PokeAccess::Config.verbosity = :brief
      opened(SpecShopScene)
      PokeAccess::Info.set_info(:text, "Poción", "Poción, 300")
      ticked
      assert_equal "Poción, 300. En la mochila: 2", PokeAccess::Info.row_text
    end
  end

  test "leaves a hidden focused-row window out of the row" do
    with_watch("SpecShopScene", "count", :spec_count, :reading => [:shop_item, :medium]) do
      scene = opened(SpecShopScene)
      scene.sprites["count"] = Win.new("En la mochila: 2", false)
      PokeAccess::Info.set_info(:text, "Poción", "Poción, 300")
      assert_equal [], ticked, "nor is it said"
      assert_equal "Poción, 300", PokeAccess::Info.row_text
      scene.sprites["count"] = Win.new("En la mochila: 2", true)
      ticked
      assert_equal "Poción, 300. En la mochila: 2", PokeAccess::Info.row_text, "shown, it joins"
    end
  end

  test "leaves the painted dex header to the windows where the dex keeps them" do
    painted("Pokedex regional", "Vistos: 10")
    SpeakCapture.clear
    PokeAccess::InfoWindow.say_dex_header(PokemonPokedexScene.new)
    assert_nothing_spoken
  end

  test "says the painted dex header without an unseen species' question marks" do
    painted("Pokedex regional", "?????", "Vistos: 10")
    SpeakCapture.clear
    PokeAccess::InfoWindow.say_dex_header(World.stub_scene(:@sprites => {}))
    assert_equal [["Pokedex regional, Vistos: 10", false]], SpeakCapture.log
  end

  test "says nothing of a painted dex header that holds only the question marks" do
    painted("?????")
    SpeakCapture.clear
    PokeAccess::InfoWindow.say_dex_header(World.stub_scene(:@sprites => {}))
    assert_nothing_spoken
  end

  private

  # Runs the block with a window watch declared, the watch taken back out afterwards (the hooks it bound stay, as a
  # class binds once).
  def with_watch(cname, key, slot, opts = {})
    PokeAccess::InfoWindow.watch(cname, key, slot, opts)
    yield
  ensure
    PokeAccess::InfoWindow.watches.reject! { |w| w[2] == slot }
  end

  # Runs the block with the swap screen's interrupting help window declared on its two own openers, yielding whether
  # the declaration bound; the same options every time, as the first declaration on a class is the one that binds.
  def with_own_openers
    bound = PokeAccess::InfoWindow.watch("SpecOwnOpenerScene", "help", :spec_own, :interrupt => true,
                                         :open => ["pbStartRentScene", "pbStartSwapScene"])
    yield bound
  ensure
    PokeAccess::InfoWindow.watches.reject! { |w| w[2] == :spec_own }
  end

  # Runs the block with a player's scheme of these levels in use, the scheme forgotten afterwards.
  def with_scheme(name, levels)
    PokeAccess::VerbositySchemes.set(name, levels)
    PokeAccess::Config.verbosity = name.to_sym
    yield
  ensure
    PokeAccess::Config.verbosity = :full
    PokeAccess::VerbositySchemes.delete(name)
  end

  # A new screen of class cls, opened through its opener.
  def opened(cls)
    scene = cls.new
    scene.pbStartScene
    scene
  end

  # What one frame of the watch says, as [text, interrupt] pairs.
  def ticked
    SpeakCapture.clear
    PokeAccess::InfoWindow.tick
    SpeakCapture.log.dup
  end

  # The dex list's header, painted as these rows while its reader is armed.
  def painted(*rows)
    PokeAccess::PaintCapture.arm(:dex_header)
    rows.each { |r| PokeAccess::PaintCapture.note(r) }
  end
end
