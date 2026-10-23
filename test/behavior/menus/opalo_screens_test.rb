# Opalo's own screens, read by its profile: clue notes and credits drawn as pictures, the starter selector, the looks,
# the photographs used from the bag, the gyms' machines and lights, the new-game selector and the title splash.
class OpaloScreensTest < PokeAccessTest
  # The player's trainer types the looks are named after, standing in for the game's (appearance n is type 100 + n).
  TRAINERS = { :POKEMONTRAINER_HombreMulato => 100, :POKEMONTRAINER_MujerMulata => 101,
               :POKEMONTRAINER_HombreArio => 102 }
  OPTIONS = ["Izquierda", "Medio", "Derecha"]
  # What the title's splash and the new-game selector's mode screen paint.
  SPLASH = "Pokémon Ópalo by Eric Lostie. Pokémon Essentials: 2011-2014 Maruno, 2007-2010 Peter O. " \
           "Based on work by Flameguru. Title Screen by Luka S.J."
  NORMAL_MODE = "Modo Normal. Juega a Pokemon de forma tradicional, sin reglas adicionales."
  NUZLOCKE_MODE = "Modo Nuzlocke. Los Pokemon debilitados pueden morir permanentemente. " \
                  "Hay varios modos de dificultad."

  test "a clue note says its two digits, at once" do
    with_profile("painted_pictures.rb") do
      { "pista1" => "2 6", "pista2" => "0 2", "pista3" => "2 1" }.each do |note, digits|
        SpeakCapture.clear
        show(note)
        assert_equal [[t(:op_clue, :digits => digits), true]], SpeakCapture.log, note
      end
    end
  end

  test "the credits are said queued as they are shown, so two on screen together are both heard" do
    with_profile("painted_pictures.rb") do
      ["cred1", "cred2", "fin"].each { |name| show(name) }
      assert_equal [["Arte: Mr. Almagrís, Rinkuu, Dewy, ChekaArt, Therusan", false],
                    ["Sprites: Don Flowers, Gamid, Scept", false], ["Fin", false]], SpeakCapture.log
    end
  end

  test "a picture that is no clue nor credit says nothing" do
    with_profile("painted_pictures.rb") do
      show("fondoNegro")
      assert_nothing_spoken
    end
  end

  test "the starter selector opens on its prompt, the starter lit with its type and the keys, queued" do
    with_starters do
      show("iniciales2")
      keys = t(:op_starter_keys, :key => "C")
      assert_equal [["Elige a tu Pokémon inicial. #{starter(26, "Fuego")}. #{keys}", false]], SpeakCapture.log
    end
  end

  test "a move on the starter selector says the starter now lit, interrupting" do
    with_starters do
      show("iniciales2")
      SpeakCapture.clear
      show("iniciales1")
      show("iniciales3")
      assert_equal [[starter(25, "Planta"), true], [starter(27, "Agua"), true]], SpeakCapture.log
    end
  end

  test "in brief the starter selector opens without the keys" do
    with_starters do
      PokeAccess::Config.verbosity = :brief
      show("iniciales2")
      assert_equal [["Elige a tu Pokémon inicial. #{starter(26, "Fuego")}", false]], SpeakCapture.log
    end
  end

  test "a map change closes the starter selector, so the next one opens on its prompt again" do
    with_starters do
      show("iniciales2")
      PokeAccess::Caches.reset_all
      SpeakCapture.clear
      show("iniciales1")
      keys = t(:op_starter_keys, :key => "C")
      assert_equal [["Elige a tu Pokémon inicial. #{starter(25, "Planta")}. #{keys}", false]], SpeakCapture.log
    end
  end

  test "a picture that is no starter says nothing" do
    with_starters do
      show("fondoNegro")
      assert_nothing_spoken
    end
  end

  test "a new game's first look, put on by the mode screen, says nothing" do
    with_looks(-1) do
      pbChangePlayer(0)
      assert_nothing_spoken
    end
  end

  test "with no portraits in a row, the look choice's options are plain" do
    with_looks(0) do
      assert_equal OPTIONS, options
    end
  end

  test "each option of the look choice carries the skin of the portrait on its side" do
    with_looks(0) do
      portraits("hombre", %w[Ario Mulato Negro])
      assert_equal ["Izquierda, #{t(:op_skin_light)}", "Medio, #{t(:op_skin_medium)}", "Derecha, #{t(:op_skin_dark)}"],
                   options
    end
  end

  test "the portraits go to the options by their place on screen, whatever order they are shown in" do
    with_looks(0) do
      [["mujerNegra", 250], ["mujerAria", 0], ["mujerMulata", 125]].each { |name, x| picture(name, x, 70) }
      assert_equal ["Izquierda, #{t(:op_skin_light)}", "Medio, #{t(:op_skin_medium)}", "Derecha, #{t(:op_skin_dark)}"],
                   options
    end
  end

  test "a choice window of another size is left as it is" do
    with_looks(0) do
      portraits("hombre", %w[Ario Mulato Negro])
      assert_equal "Sí", PokeAccess::Menus.focused_text(Window_DrawableCommand.new(["Sí", "No"]))
    end
  end

  test "the portrait picked, shown alone, is said as its sex and skin, interrupting" do
    with_looks(0) do
      { "hombreArio" => "#{t(:ap_boy)}, #{t(:op_skin_light)}", "mujerMulata" => "#{t(:ap_girl)}, #{t(:op_skin_medium)}",
        "mujerNegra" => "#{t(:ap_girl)}, #{t(:op_skin_dark)}" }.each do |name, said|
        portraits(name[/\A(hombre|mujer)/], %w[Ario Mulato Negro])
        SpeakCapture.clear
        picture(name, 256, 178)
        assert_equal [[said, true]], SpeakCapture.log, name
      end
    end
  end

  test "once a portrait is picked the options are plain again" do
    with_looks(0) do
      portraits("hombre", %w[Ario Mulato Negro])
      picture("hombreArio", 256, 178)
      assert_equal OPTIONS, options
    end
  end

  test "putting on the look just picked does not say it again" do
    with_looks(0) do
      portraits("hombre", %w[Ario Mulato Negro])
      picture("hombreArio", 256, 178)
      SpeakCapture.clear
      pbChangePlayer(2)
      assert_nothing_spoken
    end
  end

  test "once the look just picked is put on, the next change is said again" do
    with_looks(0) do
      portraits("hombre", %w[Ario Mulato Negro])
      picture("hombreArio", 256, 178)
      pbChangePlayer(2)
      SpeakCapture.clear
      pbChangePlayer(1)
      assert_equal [["#{t(:ap_girl)}, #{t(:op_skin_medium)}", true]], SpeakCapture.log
    end
  end

  test "a map change drops a pick not yet put on, so the next change is said" do
    with_looks(0) do
      portraits("hombre", %w[Ario Mulato Negro])
      picture("hombreArio", 256, 178)
      PokeAccess::Caches.reset_all
      SpeakCapture.clear
      pbChangePlayer(1)
      assert_equal [["#{t(:ap_girl)}, #{t(:op_skin_medium)}", true]], SpeakCapture.log
    end
  end

  test "picking the look already on still says its portrait, and putting it on adds nothing" do
    with_looks(0) do
      portraits("hombre", %w[Ario Mulato Negro])
      picture("hombreMulato", 256, 178)
      pbChangePlayer(0)
      assert_equal [["#{t(:ap_boy)}, #{t(:op_skin_medium)}", true]], SpeakCapture.log
    end
  end

  test "a portrait shown alone with no row before it is no pick" do
    with_looks(0) do
      picture("hombreNegro", 256, 178)
      assert_nothing_spoken
    end
  end

  test "a picture that is no portrait, or a portrait with no skin, leaves the row as it is" do
    with_looks(0) do
      portraits("hombre", %w[Ario Mulato Negro])
      SpeakCapture.clear
      ["fondoNegro", "hombre"].each { |name| picture(name, 256, 178) }
      assert_equal ["Izquierda, #{t(:op_skin_light)}", "Medio, #{t(:op_skin_medium)}", "Derecha, #{t(:op_skin_dark)}"],
                   options
      assert_nothing_spoken
    end
  end

  test "in play, the look put on is said as its sex and skin, interrupting, never as a number" do
    with_looks(0) do
      pbChangePlayer(1)
      assert_equal [["#{t(:ap_girl)}, #{t(:op_skin_medium)}", true]], SpeakCapture.log
    end
  end

  test "in play, a look whose trainer type names no skin is said by its sex alone" do
    with_looks(0) do
      pbChangePlayer(5)
      assert_equal [[t(:ap_girl), true]], SpeakCapture.log
    end
  end

  test "a photograph used from the bag says what it shows and the key that goes on, at once" do
    with_photos do
      key = t(:title_press, :key => "C")
      { 614 => :op_photo_whole, 568 => :op_photo_locket, 613 => :op_photo_torn }.each do |item, shows|
        SpeakCapture.clear
        ItemHandlers.triggerUseFromBag(item)
        assert_equal [["#{t(shows)} #{key}", true]], SpeakCapture.log, "item #{item}"
      end
    end
  end

  test "the bag's handler still runs as the game's" do
    with_photos do
      assert_equal 1, ItemHandlers.triggerUseFromBag(614)
    end
  end

  test "any other item used from the bag says nothing" do
    with_photos do
      ItemHandlers.triggerUseFromBag(PBItems::POTION)
      assert_nothing_spoken
    end
  end

  test "in brief a photograph is said without its key" do
    with_photos do
      PokeAccess::Config.verbosity = :brief
      ItemHandlers.triggerUseFromBag(613)
      assert_equal [[t(:op_photo_torn), true]], SpeakCapture.log
    end
  end

  test "entering the psychic gym says the traps' rule, queued" do
    on_map(36) do
      PokeAccess::Puzzles.tick
      assert_equal [[t(:op_traps_hint), false]], SpeakCapture.log
    end
  end

  test "entering the psychic gym again after a map change says the traps' rule again" do
    on_map(36) do
      PokeAccess::Puzzles.tick
      PokeAccess::Caches.reset_all
      SpeakCapture.clear
      PokeAccess::Puzzles.tick
      assert_equal [[t(:op_traps_hint), false]], SpeakCapture.log
    end
  end

  test "in brief, which leaves descriptions out, entering the psychic gym says nothing" do
    on_map(36) do
      PokeAccess::Config.verbosity = :brief
      PokeAccess::Puzzles.tick
      assert_nothing_spoken
    end
  end

  test "a sensor lights the psychic gym's path for a step, then puts it out" do
    on_map(36) do
      PokeAccess::Puzzles.tick
      [true, false].each do |on|
        SpeakCapture.clear
        $game_switches[313] = on
        PokeAccess::Puzzles.tick
        assert_equal [[light(:op_lights, on), false]], SpeakCapture.log, on ? "lit" : "put out"
      end
    end
  end

  test "the northern field's sensor lights its own path" do
    on_map(36) do
      PokeAccess::Puzzles.tick
      SpeakCapture.clear
      $game_switches[314] = true
      PokeAccess::Puzzles.tick
      $game_switches[314] = false
      PokeAccess::Puzzles.tick
      assert_equal [[light(:op_lights_north, true), false], [light(:op_lights_north, false), false]], SpeakCapture.log
    end
  end

  test "nothing is said while the psychic gym's lights stay as they are" do
    on_map(36) do
      PokeAccess::Puzzles.tick
      SpeakCapture.clear
      PokeAccess::Puzzles.tick
      assert_nothing_spoken
    end
  end

  test "the info key in the psychic gym says both lights and the traps' rule" do
    on_map(36) do
      PokeAccess::Puzzles.tick
      PokeAccess::Locator.refresh_info
      SpeakCapture.clear
      PokeAccess::Keys.info_key
      rule = PokeAccess::I18n.t(:op_traps_hint)
      assert_equal ["#{light(:op_lights, false)}. #{light(:op_lights_north, false)}. #{rule}"], SpeakCapture.lines
    end
  end

  test "the machine room says each machine and lever as it turns on" do
    on_map(46) do
      PokeAccess::Puzzles.tick
      { 174 => :op_machine, 178 => :op_machine2, 175 => :op_lever1, 177 => :op_lever2 }.each do |switch, label|
        SpeakCapture.clear
        $game_switches[switch] = true
        PokeAccess::Puzzles.tick
        assert_equal [["#{t(label)}: #{t(:op_on)}", false]], SpeakCapture.log, "switch #{switch}"
      end
    end
  end

  test "the machine room lists each machine once, on the middle of its three tiles, and each lever" do
    on_map(46) do
      machine_room
      listed = PokeAccess::Puzzles.category_targets.map { |tg| [tg.name, tg.x, tg.y] }
      want = [[t(:op_machine), 6, 9], [t(:op_machine), 37, 8], [t(:op_lever1), 6, 47], [t(:op_lever2), 39, 46]]
      assert_equal want.sort, listed.sort
    end
  end

  test "a machine put to use leaves the machine room's list with all three of its tiles" do
    on_map(46) do
      machine_room(243)
      machines = PokeAccess::Puzzles.category_targets.select { |tg| tg.name == t(:op_machine) }
      assert_equal [[37, 8]], machines.map { |tg| [tg.x, tg.y] }
    end
  end

  test "in the machine room, a steam jet's jump is the info key's line while the player stands where it left them" do
    on_map(46) do
      machine_room
      PokeAccess::Puzzles.tick
      jump = forced_to(41, 15, [8, 8, 8, 8, 8, 8])
      assert_equal [jump], info_key_lines, "where the jump left the player"
      $game_player.y = 16
      room = [:op_machine, :op_machine2, :op_lever1, :op_lever2].map { |k| "#{t(k)}: #{t(:op_off)}" }.join(". ")
      assert_equal [room], info_key_lines, "a step off it, the machine room's line again"
    end
  end

  test "the title's splash image is said by its transcription, queued" do
    with_profile("picture_cues.rb") do
      PokeAccess::TitleScreen.splash(["intro1"])
      assert_equal [[SPLASH, false]], SpeakCapture.log
    end
  end

  test "a splash image with no transcription stays silent" do
    with_profile("picture_cues.rb") do
      PokeAccess::TitleScreen.splash(["intro2"])
      assert_nothing_spoken
    end
  end

  test "the mode selector says the mode the pointer is on, interrupting" do
    with_profile("picture_cues.rb") do
      picture("MenuNuzNormalClaro", 0, 0)
      { 100 => NORMAL_MODE, 150 => NUZLOCKE_MODE }.each do |y, mode|
        SpeakCapture.clear
        picture("MenuNuzPuntero", 0, y)
        assert_equal [[mode, true]], SpeakCapture.log, "the pointer at y #{y}"
      end
    end
  end

  test "the pointer is on Normal above y 120 and on Nuzlocke from it" do
    with_profile("picture_cues.rb") do
      picture("MenuNuzNormalClaro", 0, 0)
      picture("MenuNuzPuntero", 0, 119)
      picture("MenuNuzPuntero", 0, 120)
      assert_equal [[NORMAL_MODE, true], [NUZLOCKE_MODE, true]], SpeakCapture.log
    end
  end

  test "the pointer kept on a mode says it once" do
    with_profile("picture_cues.rb") do
      picture("MenuNuzNuzOsc", 0, 0)
      picture("MenuNuzPuntero", 0, 100)
      SpeakCapture.clear
      picture("MenuNuzPuntero", 0, 110)
      assert_nothing_spoken
    end
  end

  test "on the difficulty screen the pointer says nothing, each difficulty being said by its own picture" do
    with_profile("picture_cues.rb") do
      PokeAccess::PictureCues.reset_last
      picture("MenuNuzNormalDif1Claro", 0, 0)
      picture("MenuNuzPuntero", 0, 100)
      assert_equal [["Maestro. Los Pokemon debilitados mueren permanentemente; si pierdes un combate pierdes el reto.",
                     true]], SpeakCapture.log
    end
  end

  test "a map change drops the mode selector, so a pointer seen afterwards is no mode until it opens again" do
    with_profile("picture_cues.rb") do
      picture("MenuNuzNormalClaro", 0, 0)
      PokeAccess::Caches.reset_all
      picture("MenuNuzPuntero", 0, 100)
      assert_nothing_spoken
    end
  end

  test "a later visit to the mode selector says its mode afresh, the same one included" do
    with_profile("picture_cues.rb") do
      picture("MenuNuzNormalClaro", 0, 0)
      picture("MenuNuzPuntero", 0, 100)
      PokeAccess::Caches.reset_all
      SpeakCapture.clear
      picture("MenuNuzNormalClaro", 0, 0)
      picture("MenuNuzPuntero", 0, 100)
      assert_equal [[NORMAL_MODE, true]], SpeakCapture.log
    end
  end

  test "the sex portraits count the other way round from core: the first is the girl" do
    with_profile("picture_cues.rb") do
      with_player_id(-1) do
        { "pantallaGenero1" => :ap_girl, "pantallaGenero2" => :ap_boy }.each do |name, sex|
          SpeakCapture.clear
          picture(name, 0, 0)
          assert_equal [[t(sex), true]], SpeakCapture.log, name
        end
      end
    end
  end

  private

  # The mod's line for an i18n key.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Evaluates games/opalo/<file> whole, as the loader does, for the block, the spoken log cleared; then puts back the
  # module functions it overrides ([module, name] pairs), the picture texts and sex numbering it sets, and drops the
  # function-wrap bodies, overrides and picture observers it added.
  def with_profile(file, singletons = [])
    saved = singletons.map { |mod, name| [mod, name, mod.method(name)] }
    bodies = {}
    PokeAccess::Hooks.fn_bodies.each { |k, v| bodies[k] = v.length }
    overrides = PokeAccess::Hooks.overrides.length
    handlers = PokeAccess::PictureCues::HANDLERS.length
    texts = PokeAccess::PictureCues::TEXTS.dup
    numbers = PokeAccess::Config.gender_numbers
    path = File.join(Harness::ROOT, "games", "opalo", file)
    quiet { eval(Harness.source(path), TOPLEVEL_BINDING, path) }
    SpeakCapture.clear
    yield
  ensure
    (saved || []).each { |mod, name, fn| mod.define_singleton_method(name, fn) }
    PokeAccess::Hooks.fn_bodies.each { |k, v| v.slice!((bodies[k] || 0)..-1) } if bodies
    PokeAccess::Hooks.overrides.slice!(overrides..-1) if overrides
    PokeAccess::PictureCues::HANDLERS.slice!(handlers..-1) if handlers
    if texts
      PokeAccess::PictureCues::TEXTS.clear
      PokeAccess::PictureCues::TEXTS.merge!(texts)
    end
    PokeAccess::Config.gender_numbers = numbers if numbers
    PokeAccess::PictureCues.reset_last
  end

  # Runs the block with Ruby's warnings off, as a profile evaluated again redefines its constants.
  def quiet
    verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = verbose
  end

  # Sets constants on a module for the block, removing the ones it added.
  def with_consts(mod, table)
    added = table.keys.reject { |k| mod.const_defined?(k, false) }
    added.each { |k| mod.const_set(k, table[k]) }
    yield
  ensure
    (added || []).each { |k| mod.send(:remove_const, k) if mod.const_defined?(k, false) }
  end

  # A picture shown, as the game's event shows it, at (x, y).
  def picture(name, x, y)
    Game_Picture.new.show(name, 1, x, y)
  end

  # A full-screen picture shown at the corner, as the clue notes, credits and selectors are.
  def show(name)
    picture(name, 0, 0)
  end

  # The starter selector's line for a species and its type in the confirmation's words.
  def starter(species, type)
    t(:op_starter, :name => "Especie#{species}", :type => type)
  end

  # Runs the block with the starter selector bound and its three starters in the game's species table.
  def with_starters
    with_consts(PBSpecies, :SNAMPERY => 25, :FLASINGE => 26, :SWOLPHIN => 27) do
      with_profile("starters.rb") { yield }
    end
  end

  # Runs the block with the look choice bound, the appearance in use set to id (-1 while a new game has none), and
  # the trainer types standing in for the game's metadata: appearance id n is trainer type 100 + n, a boy when even.
  def with_looks(id)
    ap = PokeAccess::Appearance
    saved = [:trainer_type, :gender_word].map { |m| [m, ap.method(m)] }
    ap.define_singleton_method(:trainer_type) { |n| 100 + n.to_i }
    ap.define_singleton_method(:gender_word) { |n| PokeAccess::I18n.t(n.to_i.even? ? :ap_boy : :ap_girl) }
    with_player_id(id) do
      with_consts(PBTrainers, TRAINERS) do
        with_profile("looks.rb", [[ap, :announce], [PokeAccess::Menus, :focused_text]]) do
          PokeAccess::OpaloLooks.reset
          yield
        end
      end
    end
  ensure
    saved.each { |m, fn| ap.define_singleton_method(m, fn) } if saved
  end

  # Runs the block with the appearance in use set to id (-1 while a new game has put none on), the one before put
  # back after.
  def with_player_id(id)
    was = $PokemonGlobal.playerID
    $PokemonGlobal.playerID = id
    yield
  ensure
    $PokemonGlobal.playerID = was
  end

  # Shows the three portraits of a sex in a row, as the look choice stands them, with the given skin endings.
  def portraits(sex, skins)
    skins.each_with_index { |skin, i| picture("#{sex}#{skin}", i * 125, 70) }
  end

  # The look choice's three options as the menu reader says each.
  def options
    window = Window_DrawableCommand.new(OPTIONS)
    (0..2).map do |i|
      window.index = i
      PokeAccess::Menus.focused_text(window)
    end
  end

  # Runs the block with the photographs bound to the bag's handler, ItemHandlers made when the stubs lack it (its
  # handler answering 1) and taken away after, and the three photographs in the item table.
  def with_photos
    made = !Object.const_defined?(:ItemHandlers)
    if made
      Object.const_set(:ItemHandlers, Module.new)
      ItemHandlers.define_singleton_method(:triggerUseFromBag) { |_item| 1 }
    end
    with_consts(PBItems, :Guardapelo => 568, :FOTOGATLING => 613, :FOTOGATLING2 => 614) do
      with_profile("photos.rb") { yield }
    end
  ensure
    Object.send(:remove_const, :ItemHandlers) if made && Object.const_defined?(:ItemHandlers)
  end

  # Places map 46's machines and levers as the game's map has them: a machine is three events in a row whose first
  # page sets 174, or 178 once 174 is on, and the machine's own switch (243 west, 244 east), and whose second page, on
  # that switch, is empty; a lever, a page that sets its switch. used: the machines' switches already on.
  def machine_room(*used)
    [[243, [[54, 5, 9], [7, 6, 9], [11, 7, 9]]], [244, [[55, 36, 8], [56, 37, 8], [57, 38, 8]]]].each do |own, tiles|
      tiles.each do |id, x, y|
        start = TestPage.new(:list => machine_script(own))
        spent = TestPage.new(:condition => { :switch1_valid => true, :switch1_id => own })
        place(id, x, y, [start, spent], used.include?(own) ? spent : start)
      end
    end
    [[8, 6, 47, 175], [10, 39, 46, 177]].each do |id, x, y, switch|
      pull = TestPage.new(:sprite => "palancas", :list => [TestCmd.new(121, [switch, switch, 0])])
      place(id, x, y, [pull], pull)
    end
    World.next_frame
  end

  # A machine's first page: with 174 on it sets 178, else 174, and the machine's own switch either way.
  def machine_script(own)
    [TestCmd.new(111, [0, 174, 0]), TestCmd.new(121, [178, 178, 0], 1), TestCmd.new(121, [own, own, 0], 1),
     TestCmd.new(411), TestCmd.new(121, [174, 174, 0], 1), TestCmd.new(121, [own, own, 0], 1), TestCmd.new(412)]
  end

  # Puts an event with these pages on the map, on the active one.
  def place(id, x, y, pages, active)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages, :active_page => active)
  end

  # Runs the block on map id with Opalo's gym puzzles declared and every switch off; the map and the puzzle function
  # the profile overrides put back after.
  def on_map(id)
    was = $game_map.map_id
    with_profile("puzzles.rb", [[PokeAccess::Puzzles, :control_targets]]) do
      $game_map.map_id = id
      PokeAccess::Caches.reset_all
      yield
    end
  ensure
    $game_map.map_id = was
    PokeAccess::Caches.reset_all
  end

  # What the info key says on the map, the map's frame having handed it the key.
  def info_key_lines
    PokeAccess::Locator.refresh_info
    SpeakCapture.clear
    PokeAccess::Keys.info_key
    SpeakCapture.lines
  end

  # Leaves the player on (x, y) as a forced move that went the given ways (direction codes) does, its line kept for
  # the info key; answers that line.
  def forced_to(x, y, ways)
    line = PokeAccess::Routes::Text.moved_path(ways, false)
    $game_player.x = x
    $game_player.y = y
    PokeAccess::ForcedMove.instance_variable_set(:@line, line)
    PokeAccess::ForcedMove.instance_variable_set(:@at, [x, y, $game_map.map_id])
    line
  end

  # A light's line: its label and whether it is on.
  def light(key, on)
    "#{t(key)}: #{t(on ? :op_lights_on : :op_lights_off)}"
  end
end
