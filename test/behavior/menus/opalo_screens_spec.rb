# Opalo's own screens, from this repo's profile files: the clue notes and credits drawn as pictures, the starter
# selector, the look choice and the look put on, the photographs used from the bag, and the psychic gym's lights.
# Each file is evaluated whole, as the loader does, and what it binds (picture observers, overrides of the mod's
# functions, function-wrap bodies) is taken back afterwards, so the profile does not outlive its suite.
module OpaloSpec
  # Evaluates a whole profile file, as the loader does.
  def self.eval_file(file)
    path = File.join(Harness::ROOT, "games", "opalo", file)
    eval(File.read(path), TOPLEVEL_BINDING, path)
  end

  # Evaluates a whole profile file for the block, then puts back the named module functions it overrides
  # ([module, name] pairs) and drops the function-wrap bodies and picture observers it added.
  def self.with_profile(file, singletons = [])
    saved = singletons.map { |mod, name| [mod, name, mod.method(name)] }
    bodies = {}
    PokeAccess::Hooks.fn_bodies.each { |k, v| bodies[k] = v.length }
    overrides = PokeAccess::Hooks.overrides.length
    with_observers do
      eval_file(file)
      yield
    end
  ensure
    (saved || []).each { |mod, name, fn| mod.define_singleton_method(name, fn) }
    PokeAccess::Hooks.fn_bodies.each { |k, v| v.slice!((bodies[k] || 0)..-1) } if bodies
    PokeAccess::Hooks.overrides.slice!(overrides..-1) if overrides
  end

  # Runs the block with the picture observers it registers removed afterwards.
  def self.with_observers
    handlers = PokeAccess::PictureCues::HANDLERS.length
    yield
  ensure
    extra = PokeAccess::PictureCues::HANDLERS.length - handlers
    PokeAccess::PictureCues::HANDLERS.slice!(handlers, extra) if extra > 0
  end

  # The show arguments of a picture at (x, y).
  def self.show(name, x = 0, y = 0)
    PokeAccess::PictureCues.on_picture(name, [name, 0, x, y, 100, 100, 255, 0])
  end

  # Sets constants on a module for the block, removing the ones it added.
  def self.with_consts(mod, table)
    added = table.keys.reject { |k| mod.const_defined?(k, false) }
    added.each { |k| mod.const_set(k, table[k]) }
    yield
  ensure
    (added || []).each { |k| mod.send(:remove_const, k) if mod.const_defined?(k, false) }
  end
end

Suite.define("opalo: the clue notes say their digits, and the credits queue as they are shown") do
  t = PokeAccess::I18n
  OpaloSpec.with_observers do
    OpaloSpec.eval_file("painted_pictures.rb")
    SpeakCapture.clear
    OpaloSpec.show("pista1")
    eq "the first note, its two digits", SpeakCapture.lines, [t.t(:op_clue, :digits => "2 6")]
    eq "said at once, as the player just asked to look", SpeakCapture.log.last[1], true
    SpeakCapture.clear
    OpaloSpec.show("pista2")
    OpaloSpec.show("pista3")
    eq "and the other two, which with the first make the chest's code", SpeakCapture.lines,
       [t.t(:op_clue, :digits => "0 2"), t.t(:op_clue, :digits => "2 1")]
    SpeakCapture.clear
    OpaloSpec.show("cred1")
    OpaloSpec.show("cred2")
    eq "two credits on screen together are both said", SpeakCapture.lines,
       ["Arte: Mr. Almagrís, Rinkuu, Dewy, ChekaArt, Therusan", "Sprites: Don Flowers, Gamid, Scept"]
    truthy "queued, so the second does not cut the first", SpeakCapture.log.all? { |e| e[1] == false }
    SpeakCapture.clear
    OpaloSpec.show("fin")
    eq "the ending's last picture", SpeakCapture.lines, ["Fin"]
    SpeakCapture.clear
    OpaloSpec.show("fondoNegro")
    silent "any other picture says nothing"
  end
end

# The starter's name comes from the game's species table; its type in the confirmation's own words, since the
# game's type table holds English names (here the stubs' Tipo<n>, which must not be what is said).
Suite.define("opalo: the starter selector says its prompt, the starter lit with its type, and the keys") do
  t = PokeAccess::I18n
  OpaloSpec.with_consts(PBSpecies, :SNAMPERY => 25, :FLASINGE => 26, :SWOLPHIN => 27) do
    OpaloSpec.with_observers do
      OpaloSpec.eval_file("starters.rb")
      PokeAccess::OpaloStarters.reset
      snampery = t.t(:op_starter, :name => "Especie25", :type => "Planta")
      flasinge = t.t(:op_starter, :name => "Especie26", :type => "Fuego")
      swolphin = t.t(:op_starter, :name => "Especie27", :type => "Agua")
      keys = t.t(:op_starter_keys, :key => PokeAccess::KeyHints.key(:c, "C"))
      SpeakCapture.clear
      OpaloSpec.show("iniciales2")
      eq "opening: the painted prompt, the starter lit, and how to move", SpeakCapture.lines,
         ["Elige a tu Pokémon inicial. #{flasinge}. #{keys}"]
      eq "queued behind the message before it", SpeakCapture.log.last[1], false
      SpeakCapture.clear
      OpaloSpec.show("iniciales1")
      OpaloSpec.show("iniciales3")
      eq "a move says the starter now lit, by the game's name and the type its confirmation names",
         SpeakCapture.lines, [snampery, swolphin]
      eq "cutting the previous one", SpeakCapture.log.last[1], true
      SpeakCapture.clear
      OpaloSpec.show("fondoNegro")
      silent "any other picture says nothing"
      PokeAccess::OpaloStarters.reset
      PokeAccess::Config.verbosity = :brief
      SpeakCapture.clear
      OpaloSpec.show("iniciales2")
      eq "in brief the keys are left out", SpeakCapture.lines, ["Elige a tu Pokémon inicial. #{flasinge}"]
    end
  end
end

# Map001's look choice: the three portraits stand at y 70 (x 0, 125, 250), the one picked is shown again alone at
# (256, 178) and pbChangePlayer puts it on; the mode screen (Map156) puts on look 0 first, over the -1 of a new game,
# and Map302's waters put on the other sex's look in play. Driven through the game's own entry points: Game_Picture's
# show, the choice window's focused text and pbChangePlayer. The trainer types stand in for the game's metadata.
Suite.define("opalo: the look choice names each portrait's skin, and the look put on is its sex and skin") do
  t = PokeAccess::I18n
  ap = PokeAccess::Appearance
  saved = [:trainer_type, :gender_word].map { |m| [m, ap.method(m)] }
  ap.define_singleton_method(:trainer_type) { |id| 100 + id.to_i }
  ap.define_singleton_method(:gender_word) { |id| t.t(id.to_i.even? ? :ap_boy : :ap_girl) }
  show = lambda { |name, x, y| Game_Picture.new.show(name, 1, x, y) }
  row = lambda { |sex, names| names.each_with_index { |n, i| show.call("#{sex}#{n}", i * 125, 70) } }
  win = Window_DrawableCommand.new(["Izquierda", "Medio", "Derecha"])
  option = lambda { |i| win.index = i; PokeAccess::Menus.focused_text(win) }
  $PokemonGlobal.playerID = -1
  begin
    OpaloSpec.with_consts(PBTrainers, :POKEMONTRAINER_HombreMulato => 100, :POKEMONTRAINER_MujerMulata => 101,
                                      :POKEMONTRAINER_HombreArio => 102) do
      OpaloSpec.with_profile("looks.rb", [[ap, :announce], [PokeAccess::Menus, :focused_text]]) do
        lk = PokeAccess::OpaloLooks
        lk.reset
        SpeakCapture.clear
        pbChangePlayer(0)
        silent "the mode screen's reset, the first look a new game puts on, says nothing"
        eq "nor is an option dressed with no portraits shown", option.call(0), "Izquierda"
        row.call("hombre", %w[Ario Mulato Negro])
        eq "each option carries the skin of the portrait on its side", (0..2).map { |i| option.call(i) },
           ["Izquierda, #{t.t(:op_skin_light)}", "Medio, #{t.t(:op_skin_medium)}", "Derecha, #{t.t(:op_skin_dark)}"]
        eq "a window of another size is left as it is",
           PokeAccess::Menus.focused_text(Window_DrawableCommand.new(["Sí", "No"])), "Sí"
        SpeakCapture.clear
        show.call("hombreArio", 256, 178)
        eq "the portrait picked, shown alone, is said as the sex and skin it shows", SpeakCapture.lines,
           ["#{t.t(:ap_boy)}, #{t.t(:op_skin_light)}"]
        eq "once one is picked the options are plain again", option.call(0), "Izquierda"
        SpeakCapture.clear
        pbChangePlayer(2)
        silent "and pbChangePlayer putting it on does not say it twice, nor as a number"
        lk.reset
        $PokemonGlobal.playerID = 0
        row.call("hombre", %w[Ario Mulato Negro])
        SpeakCapture.clear
        show.call("hombreMulato", 256, 178)
        pbChangePlayer(0)
        eq "the middle one, the look the mode screen already put on, is said by its portrait all the same",
           SpeakCapture.lines, ["#{t.t(:ap_boy)}, #{t.t(:op_skin_medium)}"]
        SpeakCapture.clear
        show.call("hombreNegro", 256, 178)
        silent "a portrait shown alone with no row before it is no pick"
        lk.reset
        SpeakCapture.clear
        pbChangePlayer(1)
        eq "in play (the waters of the Arbol Secreto), the new look as sex and skin, never a number",
           SpeakCapture.lines, ["#{t.t(:ap_girl)}, #{t.t(:op_skin_medium)}"]
      end
    end
  ensure
    saved.each { |m, fn| ap.define_singleton_method(m, fn) }
    $PokemonGlobal.playerID = 0
    PokeAccess::OpaloLooks.reset if defined?(PokeAccess::OpaloLooks)
  end
end

# The photographs go through the bag's own entry point, ItemHandlers.triggerUseFromBag, made here when the stubs lack
# it and taken away afterwards.
Suite.define("opalo: a photograph from the bag says what it shows and the key that goes on") do
  t = PokeAccess::I18n
  made = !Object.const_defined?(:ItemHandlers)
  if made
    Object.const_set(:ItemHandlers, Module.new)
    ItemHandlers.define_singleton_method(:triggerUseFromBag) { |_item| 1 }
  end
  begin
    OpaloSpec.with_consts(PBItems, :Guardapelo => 568, :FOTOGATLING => 613, :FOTOGATLING2 => 614) do
      OpaloSpec.with_profile("photos.rb") do
        key = t.t(:title_press, :key => PokeAccess::KeyHints.key(:c, "C"))
        SpeakCapture.clear
        eq "the bag's handler still runs as the game's", ItemHandlers.triggerUseFromBag(614), 1
        eq "the whole photo: what it shows, then the key", SpeakCapture.lines, ["#{t.t(:op_photo_whole)} #{key}"]
        eq "said at once, as the bag hands over to it", SpeakCapture.log.last[1], true
        SpeakCapture.clear
        ItemHandlers.triggerUseFromBag(568)
        ItemHandlers.triggerUseFromBag(613)
        eq "the locket and the torn photo too", SpeakCapture.lines,
           ["#{t.t(:op_photo_locket)} #{key}", "#{t.t(:op_photo_torn)} #{key}"]
        SpeakCapture.clear
        ItemHandlers.triggerUseFromBag(PBItems::POTION)
        silent "any other item used from the bag says nothing"
        PokeAccess::Config.verbosity = :brief
        SpeakCapture.clear
        ItemHandlers.triggerUseFromBag(613)
        eq "in brief the key is left out", SpeakCapture.lines, [t.t(:op_photo_torn)]
      end
    end
  ensure
    Object.send(:remove_const, :ItemHandlers) if made && Object.const_defined?(:ItemHandlers)
  end
end

Suite.define("opalo: the psychic gym says the traps' rule on entering, and its path lights as they go on and off") do
  t = PokeAccess::I18n
  pf = PokeAccess::Pathfinder
  rules = (pf.instance_variable_get(:@arrival_rules) || []).length
  label = PokeAccess::Terrain.method(:label)
  overrides = PokeAccess::Hooks.overrides.length
  pollers = (PokeAccess::Keys.instance_variable_get(:@frame_pollers) || []).length
  OpaloSpec.eval_file("floor_traps.rb")
  traps = PokeAccess::OpaloTraps
  was = $game_map.map_id
  begin
    $game_switches[313] = false
    $game_switches[314] = false
    $game_map.map_id = 35
    traps.poll
    $game_map.map_id = 36
    SpeakCapture.clear
    traps.poll
    eq "entering the gym, the traps' rule, queued", SpeakCapture.log, [[t.t(:op_traps_hint), false]]
    SpeakCapture.clear
    $game_switches[313] = true
    traps.poll
    eq "a sensor lights the path", SpeakCapture.lines, ["#{t.t(:op_lights)}: #{t.t(:op_lights_on)}"]
    SpeakCapture.clear
    $game_switches[313] = false
    traps.poll
    eq "and the next step puts it out", SpeakCapture.lines, ["#{t.t(:op_lights)}: #{t.t(:op_lights_off)}"]
    SpeakCapture.clear
    $game_switches[314] = true
    traps.poll
    $game_switches[314] = false
    traps.poll
    eq "the northern field's sensor lights its own path, which its light walks and then puts out", SpeakCapture.lines,
       ["#{t.t(:op_lights_north)}: #{t.t(:op_lights_on)}", "#{t.t(:op_lights_north)}: #{t.t(:op_lights_off)}"]
    SpeakCapture.clear
    traps.poll
    silent "and nothing while the lights stay as they are"
  ensure
    $game_map.map_id = 35
    traps.poll
    $game_map.map_id = was
    (pf.instance_variable_get(:@arrival_rules) || []).slice!(rules..-1)
    PokeAccess::Terrain.define_singleton_method(:label, label)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    (PokeAccess::Keys.instance_variable_get(:@frame_pollers) || []).slice!(pollers..-1)
  end
end

Suite.define("opalo: the splash image before the title is said by its transcription, queued") do
  cues = PokeAccess::PictureCues
  texts = cues::TEXTS.dup
  numbers = PokeAccess::Config.gender_numbers
  begin
    OpaloSpec.with_observers { OpaloSpec.eval_file("picture_cues.rb") }
    SpeakCapture.clear
    PokeAccess::TitleScreen.splash(["intro1"])
    eq "the credits the splash paints", SpeakCapture.lines,
       ["Pokémon Ópalo by Eric Lostie. Pokémon Essentials: 2011-2014 Maruno, 2007-2010 Peter O. " \
        "Based on work by Flameguru. Title Screen by Luka S.J."]
    eq "queued behind whatever the game started with", SpeakCapture.log.last[1], false
    SpeakCapture.clear
    PokeAccess::TitleScreen.splash(["intro2"])
    silent "an image with no transcription stays silent"
  ensure
    cues::TEXTS.clear
    cues::TEXTS.merge!(texts)
    PokeAccess::Config.gender_numbers = numbers
  end
end
