# InfoWindow: a window a screen writes with text= (holding what its rows never say), named by a watch, is spoken when
# it changes, and only while its scene is up.
Suite.define("info window: a watched window speaks when it changes, and only inside its own scene") do
  scene_class = Class.new do
    attr_reader :sprites
    def initialize; @sprites = { "bottom" => FakeTextWin.new, "info" => FakeTextWin.new }; end
  end
  Object.const_set(:SpecInfoScene, scene_class) unless defined?(SpecInfoScene)
  iw = PokeAccess::InfoWindow
  prev = iw.live
  begin
    iw.watch("SpecInfoScene", "bottom", :spec_bottom)
    scene = SpecInfoScene.new

    SpeakCapture.clear
    iw.tick
    silent "with no scene entered, nothing is watched"

    iw.enter(scene)
    scene.sprites["bottom"].text = "<ac>Ruta 3"
    SpeakCapture.clear
    iw.tick
    eq "the window's text is spoken, its markup flattened", SpeakCapture.lines, ["Ruta 3"]

    SpeakCapture.clear
    iw.tick
    silent "and a frame where it did not change says nothing"

    scene.sprites["bottom"].text = "<ac>Ciudad Verde"
    SpeakCapture.clear
    iw.tick
    eq "a rewrite speaks the new text", SpeakCapture.lines, ["Ciudad Verde"]

    SpeakCapture.clear
    scene.sprites["info"].text = "Registrados <r>12"
    iw.tick
    silent "a window nobody declared is not read, however much it changes"

    iw.leave
    scene.sprites["bottom"].text = "<ac>Pueblo Paleta"
    SpeakCapture.clear
    iw.tick
    silent "and once the scene closes its windows are nobody's business"
  ensure
    iw.watches.reject! { |w| w[0].to_s == "SpecInfoScene" }
    iw.enter(prev)
  end
end

# The windows core declares, the phone's and the gen-6 dex header's, each on its own dedup slot.
Suite.define("info window: the phone and the pokedex header are declared, each window on its own slot") do
  rows = PokeAccess::InfoWindow.watches
  phone = rows.select { |r| r[0].to_s =~ /Phone/ }
  eq "the phone declares where the contact is and the totals", phone.map { |r| r[1] }.sort.uniq, ["bottom", "info"]
  dex = rows.select { |r| r[0].to_s =~ /Pokedex/ }
  eq "the gen-6 dex declares seen, owned and the list name, which it really keeps as windows",
     dex.map { |r| r[1] }.sort.uniq, ["dexname", "owned", "seen"]
  slots = rows.map { |r| r[2] }
  eq "and no two windows share a dedup slot, which would make one hide the other",
     slots.length, slots.uniq.length
  falsy "neither group is left unbound",
        PokeAccess::Hooks.unbound.any? { |u| u =~ /phone_info|dex_header/ }
  eq "and no declared window is missing from the scene that declares it",
     PokeAccess::InfoWindow.silent, []
end

# A scene is entered by each opener it declares (Fire Ash's swap screen has two and no pbStartScene); a scene with no
# opener takes no watch and is named in unentered.
Suite.define("info window: a scene is entered by its own opener, and one with none is reported") do
  own = Class.new do
    attr_reader :sprites
    def initialize; @sprites = { "help" => FakeTextWin.new }; end
    def pbStartRentScene(_a); @sprites["help"].text = "Elige tres"; end
    def pbStartSwapScene(_a, _b); @sprites["help"].text = "Elige uno"; end
    def pbEndScene; end
  end
  Object.const_set(:SpecOwnOpenerScene, own) unless defined?(SpecOwnOpenerScene)
  shut = Class.new do
    attr_reader :sprites
    def initialize; @sprites = { "help" => FakeTextWin.new }; end
    def pbEndScene; end
  end
  Object.const_set(:SpecNoOpenerScene, shut) unless defined?(SpecNoOpenerScene)

  iw = PokeAccess::InfoWindow
  prev = iw.live
  unentered = iw.unentered.dup
  begin
    truthy "declaring the game's own openers binds the scene",
           iw.watch("SpecOwnOpenerScene", "help", :spec_own, :open => ["pbStartRentScene", "pbStartSwapScene"])
    scene = SpecOwnOpenerScene.new

    SpeakCapture.clear
    scene.pbStartRentScene([])
    iw.tick
    eq "the first opener enters the scene and its window is read", SpeakCapture.lines, ["Elige tres"]

    SpeakCapture.clear
    scene.pbStartSwapScene(nil, nil)
    iw.tick
    eq "and so does the SECOND, which is the one a first-match-wins bind would have left mute",
       SpeakCapture.lines, ["Elige uno"]

    scene.pbEndScene
    scene.sprites["help"].text = "Ya no"
    SpeakCapture.clear
    iw.tick
    silent "the scene's own close ends the watch, as it does for the engine's"

    falsy "a scene with no opener at all takes nothing",
          iw.watch("SpecNoOpenerScene", "help", :spec_shut)
    truthy "and is named, because a watch that is never entered leaves no other trace",
           iw.unentered.include?("SpecNoOpenerScene")
  ensure
    iw.watches.reject! { |w| w[2] == :spec_own || w[2] == :spec_shut }
    iw.unentered.replace(unentered)
    iw.enter(prev)
  end
end

# The start shape of the lifecycle (the phone's in most games): one method runs the screen, watched while it runs.
Suite.define("info window: a screen that opens with start is watched for as long as start runs") do
  iw = PokeAccess::InfoWindow
  prev = iw.live
  begin
    scene = PokemonPhoneScene.new
    scene.nav = ["Ruta 3", "Ciudad Verde"]

    SpeakCapture.clear
    scene.start
    eq "every contact the cursor walked over was spoken, from inside start, and the standing totals with them",
       SpeakCapture.lines, ["Ruta 3", "Registrados, 12", "Ciudad Verde"]

    falsy "and the watch ends with start, which is the only close this shape has", iw.live

    SpeakCapture.clear
    scene.sprites["bottom"].text = "<ac>Pueblo Paleta"
    iw.tick
    silent "so a window written after the screen closed is nobody's business"
  ensure
    iw.enter(prev)
  end
end

# On the frame a screen opens an interrupting window queues behind its siblings; later changes interrupt as declared.
Suite.define("info window: an interrupting window waits its turn on the frame the screen opens") do
  scene_class = Class.new do
    attr_reader :sprites
    def initialize; @sprites = { "title" => FakeTextWin.new, "textbox" => FakeTextWin.new }; end
    def pbStartScene; @sprites["title"].text = "Mejoras (Sync)"; @sprites["textbox"].text = "Pulsa Enter."; end
    def pbEndScene; end
  end
  Object.const_set(:SpecBuffScene, scene_class) unless defined?(SpecBuffScene)
  iw = PokeAccess::InfoWindow
  prev = iw.live
  begin
    iw.watch("SpecBuffScene", "title", :spec_buff_title)
    iw.watch("SpecBuffScene", "textbox", :spec_buff_box, :interrupt => true)
    scene = SpecBuffScene.new

    SpeakCapture.clear
    scene.pbStartScene
    iw.tick
    eq "both are spoken, in the order the screen paints them",
       SpeakCapture.lines, ["Mejoras (Sync)", "Pulsa Enter."]
    eq "and neither of them cuts the other", SpeakCapture.log.map { |_t, int| int }, [false, false]

    scene.sprites["textbox"].text = "Cuesta x1.5 creditos."
    SpeakCapture.clear
    iw.tick
    eq "once the screen is up, that window does cut what is playing",
       SpeakCapture.log.map { |_t, int| int }, [true]
  ensure
    iw.watches.reject! { |w| w[2] == :spec_buff_title || w[2] == :spec_buff_box }
    iw.enter(prev)
  end
end

# The painted header of the dex list: an unseen species is painted there as a run of question marks, which the
# list reader has just said as a word ("not discovered"), so the header leaves them out.
Suite.define("info window: the dex header leaves out an unseen species' question marks") do
  pc = PokeAccess::PaintCapture
  pc.arm(:dex_header)
  pc.note("Pokedex regional")
  pc.note("?????")
  pc.note("Vistos: 10")
  SpeakCapture.clear
  PokeAccess::InfoWindow.say_dex_header(World.stub_scene(:@sprites => {}))
  spoke "the header is said", /Vistos: 10/
  not_spoke "without the placeholder the list reader has already worded", /\?/
end
