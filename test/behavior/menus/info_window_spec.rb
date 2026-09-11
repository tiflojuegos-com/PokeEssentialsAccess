# Standing information windows: the sprite a screen writes with text= and repaints as the cursor moves,
# holding what the list rows never say. Where a phone contact lives, how many are registered, how many
# species the dex has seen, whether the list on screen is a search result.
#
# Eight of them went unread across the surveyed games, all for the same reason: the global listeners on
# Window_AdvancedTextPokemon#text= are narrowed to the two command-help variants on purpose, because one
# that spoke every assignment would talk over dialogue and over battle text. So the fix is to NAME each
# window rather than widen the listener, and that is what a watch is.
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
    iw.watches.reject! { |w| w[0] == "SpecInfoScene" }
    iw.enter(prev)
  end
end

# The two screens core declares. What matters is that they are declared at all: each name is one screen
# whose standing window had never been spoken in any game.
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

# The scene's OPEN, which is the half of a watch nobody sees fail. A window is declared, the class is there,
# the sprite is there -- and if the mod never learns that the screen started, the watch points at nothing and
# not a single line is ever spoken. Fire Ash's swap screen is exactly that: two openers of its own,
# pbStartRentScene and pbStartSwapScene, and no pbStartScene anywhere.
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

# The `start` shape of the lifecycle, which is how ELEVEN of the fifteen games open the phone: one method
# that builds the windows, runs the whole screen and returns when it is over. No pbStartScene, no
# pbEndScene. Until now both stubs gave the phone the SPLIT shape, so the fallback that covers those eleven
# could be deleted with the whole suite still green and nobody the wiser.
Suite.define("info window: a screen that opens with start is watched for as long as start runs") do
  iw = PokeAccess::InfoWindow
  prev = iw.live
  begin
    scene = PokemonPhoneScene.new
    scene.nav = ["Ruta 3", "Ciudad Verde"]

    SpeakCapture.clear
    scene.start
    eq "every contact the cursor walked over was spoken, from inside start, and the standing totals with them",
       SpeakCapture.lines, ["Ruta 3", "Registrados , 12", "Ciudad Verde"]

    falsy "and the watch ends with start, which is the only close this shape has", iw.live

    SpeakCapture.clear
    scene.sprites["bottom"].text = "<ac>Pueblo Paleta"
    iw.tick
    silent "so a window written after the screen closed is nobody's business"
  ensure
    iw.enter(prev)
  end
end

# The frame a screen OPENS, every one of its windows is new at once -- so an interrupting one has nothing of
# its own screen to cut except a sibling. Fire Ash's buff screen paints its title ("Enemy Buffs (Sync
# Challenge)") and its textbox in the same breath; the textbox cut the title, and because the dedup then
# held that title as already said, the player never learned which challenge the buffs applied to for the
# whole time that screen was open.
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

    # Later, answering a keypress, it interrupts as declared.
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
