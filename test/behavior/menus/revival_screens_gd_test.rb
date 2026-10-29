# Revival's own screens (games/revival/), gamedata pass: the preparation menu's wheel, the PHS character switch, the
# world map item and the title's credit pictures, over stand-ins shaped as the game's scripts.

# The preparation menu's painter, as each of the three menus has its own copy: show_image paints the wheel
# (menufases1 unlit, 2 to 5 with a way lit) and close_menu disposes it.
module RevivalWheelStandIn
  def show_image(filename); @picture = filename; end
  def close_menu; @picture = nil; end
end

class MenuFases; include RevivalWheelStandIn; end
class MenuFases2; include RevivalWheelStandIn; end
class MenuFases3; include RevivalWheelStandIn; end

# The PHS as the game runs it: startScene takes the current character and the selectable ones, then runs update until
# it answers -1; each update takes the next press queued (:none for a frame without one, :use to keep the lit one).
class CharacterSelecion
  def initialize(current, able, presses)
    @current = current
    @able_list = able
    @presses = presses
  end

  def startScene
    @select = @current
    @able = @able_list
    loop { break if update == -1 }
    :closed
  end

  def update
    press = @presses.shift
    return -1 if press.nil? || press == :use
    step = { :up => -1, :down => 1 }[press]
    @select = @able[(@able.index(@select) + step) % @able.size] if step
    0
  end
end

# The names the PHS banners paint, by character.
CHARACTER_NAMES = ["Cira", "Vezo", "Milenka", "Rufio", "Tunia", "Gawain"]

# The title's scene before its title is built (@screen nil until ModularTitleScreen is made), and the stock intro
# whose splash list the plugin's cyclePics reads.
class RevivalIntroStandIn
  attr_accessor :screen
end

module RevivalSplashListStandIn
  SPLASH_IMAGES = ["splash1", "splash2"]
end

%w[constants phase_menu character_select].each do |name|
  path = File.join(Harness::ROOT, "games", "revival", "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class RevivalScreensGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  WORLD_MAP = File.join(Harness::ROOT, "games", "revival", "world_map.rb")
  SPLASHES = File.join(Harness::ROOT, "games", "revival", "splashes.rb")
  CARDS = File.join(Harness::ROOT, "games", "revival", "cards.rb")
  SPLASH1 = "Pokémon Revival. Creado por Rors. LA BASE DE SKY. Creada por Skyflyer y DPertierra"
  SPLASH2 = "Pokémon Essentials. 2011-2023 Maruno. 2007-2010 Peter O. Based on work by Flameguru. mkxp-z. Roza. " \
            "Based on mkxp by Ancurio et al."
  SPANISH_LANDS = ["Tensei", "Sibarnia", "Galran", "Imperio de Kurev", "Tierras Mercantes", "Híspera", "Órnica", "Zahlen",
                   "Nostalia"]

  test "the preparation menu says its ways and the key that goes on, queued, as it opens" do
    MenuFases.new.show_image("menufases1")
    ways = way_list([["Pokémon", :dir_up], ["PC", :dir_right], ["Mochila", :dir_down], ["PHS", :dir_left]])
    assert_equal [["#{I18n.t(:rv_prep_title)}. #{ways}. #{PokeAccess::TitleScreen.hint}", false]], SpeakCapture.log
  end

  test "a lit way says nothing, and back from it the menu says its name at once, once" do
    menu = MenuFases.new
    menu.show_image("menufases1")
    SpeakCapture.clear
    menu.show_image("menufases2")
    assert_nothing_spoken
    2.times { menu.show_image("menufases1") }
    assert_equal [[I18n.t(:rv_prep_title), true]], SpeakCapture.log
  end

  test "the other two menus say only the ways they take" do
    MenuFases2.new.show_image("menufases1")
    MenuFases3.new.show_image("menufases1")
    three = way_list([["Pokémon", :dir_up], ["PC", :dir_right], ["Mochila", :dir_down]])
    two = way_list([["Pokémon", :dir_up], ["Mochila", :dir_down]])
    hint = PokeAccess::TitleScreen.hint
    assert_equal ["#{I18n.t(:rv_prep_title)}. #{three}. #{hint}", "#{I18n.t(:rv_prep_title)}. #{two}. #{hint}"],
                 SpeakCapture.lines
  end

  test "in English the wheel's words are those its English pictures paint" do
    in_language(1) { MenuFases3.new.show_image("menufases1") }
    menu = "#{I18n.t(:rv_prep_title)}. #{way_list([["Pokemon", :dir_up], ["Bag", :dir_down]])}"
    assert_equal ["#{menu}. #{PokeAccess::TitleScreen.hint}"], SpeakCapture.lines
  end

  test "the info key keeps the menu while it is up and lets it go as it closes" do
    menu = MenuFases.new
    menu.show_image("menufases1")
    ways = way_list([["Pokémon", :dir_up], ["PC", :dir_right], ["Mochila", :dir_down], ["PHS", :dir_left]])
    assert_equal "#{I18n.t(:rv_prep_title)}. #{ways}", PokeAccess::Info.info_text
    menu.close_menu
    assert_nil PokeAccess::Info.info_text
  end

  test "in brief the menu is said without the key that goes on" do
    PokeAccess::Config.verbosity = :brief
    MenuFases3.new.show_image("menufases1")
    two = way_list([["Pokémon", :dir_up], ["Mochila", :dir_down]])
    assert_equal [["#{I18n.t(:rv_prep_title)}. #{two}", false]], SpeakCapture.log
  end

  test "the PHS says its name and how to choose and the lit character, queued, then each move at once" do
    assert_equal :closed, CharacterSelecion.new(0, [0, 2, 4], [:none, :down, :up, :use]).startScene
    opening = "#{I18n.t(:rv_phs_title)}. #{I18n.t(:rv_phs_hint)}"
    assert_equal [[opening, false], [entry("Cira", 1, 3), false], [entry("Milenka", 2, 3), true],
                  [entry("Cira", 1, 3), true]], SpeakCapture.log
  end

  test "a move past either end comes round to the other among the characters the story allows" do
    CharacterSelecion.new(4, [0, 2, 4], [:none, :down, :up, :up]).startScene
    assert_equal [entry("Tunia", 3, 3), entry("Cira", 1, 3), entry("Tunia", 3, 3), entry("Milenka", 2, 3)],
                 SpeakCapture.lines.drop(1)
  end

  test "in brief the PHS names itself without the keys and the characters without their places" do
    PokeAccess::Config.verbosity = :brief
    CharacterSelecion.new(0, [0, 1], [:none, :down, :use]).startScene
    assert_equal [[I18n.t(:rv_phs_title), false], ["Cira", false], ["Vezo", true]], SpeakCapture.log
  end

  test "the info key keeps the lit character's name until the PHS closes" do
    scene = CharacterSelecion.new(0, [0, 2], [])
    scene.instance_variable_set(:@select, 2)
    scene.instance_variable_set(:@able, [0, 2])
    assert_equal entry("Milenka", 2, 2), PokeAccess::RevivalPHS.entry(scene)
    assert_equal "Milenka", PokeAccess::Info.info_text
    CharacterSelecion.new(0, [0, 2], [:none, :use]).startScene
    assert_nil PokeAccess::Info.info_text
  end

  test "the PHS's end tells the menu that opened it that the player is back" do
    listeners = PokeAccess::MenuReturn.instance_variable_get(:@listeners)
    fired = []
    probe = lambda { fired.push(:back) }
    listeners.push(probe)
    PokeAccess::MenuReturn.reset_nesting
    CharacterSelecion.new(0, [0], [:use]).startScene
    assert_equal [:back], fired
  ensure
    listeners.delete(probe) if listeners
  end

  test "the world map says its labels and the keys that close it, queued, as its use opens it" do
    with_world_map { ItemHandlers.triggerUseFromBag(:MAPAMUNDI) }
    regions = %w[Morrigan Aurora Floresta Almia Albion Kalos Hisui Sinnoh Paldea Teselia Mandalia Cleyra Cosmo Aura
                 Johto Kanto Alola Hoenn]
    assert_equal [["#{world_map(SPANISH_LANDS, regions, ["Albion", "Paldea", "Teselia"])}. #{I18n.t(:rv_map_hint)}",
                   false]], SpeakCapture.log
  end

  test "the world map names the island among the regions, and among those in colour, once its switch is on" do
    $game_switches[256] = true
    with_world_map { ItemHandlers.triggerUseFromBag(:MAPAMUNDI) }
    assert_spoken(/Almia, Isla Espejismo, Albion,/)
    assert_spoken(/#{I18n.t(:rv_map_colour, :list => "Isla Espejismo, Albion, Paldea, Teselia")}/)
  end

  test "in English the world map's labels are those its English picture paints" do
    in_language(1) do
      with_world_map { ItemHandlers.triggerUseFromBag(:MAPAMUNDI) }
    end
    lands = ["Tensei", "Sibarnia", "Galran", "Kurev Empire", "Merchant Lands", "Hispera", "Ornica", "Zahlen", "Nostalia"]
    regions = %w[Morrigan Aurora Fiore Almia Albion Kalos Hisui Sinnoh Paldea Unova Mandalia Cleyra Cosmo Orre Johto
                 Kanto Alola Hoenn]
    assert_spoken(/\A#{Regexp.escape(world_map(lands, regions, ["Albion", "Paldea", "Unova"]))}\./)
  end

  test "the world map's labels stay on the info key while it is up and go as it closes" do
    seen = with_world_map { ItemHandlers.triggerUseFromBag(:MAPAMUNDI) }
    assert_match(/\A#{Regexp.escape(PokeAccess::Data.item_name(:MAPAMUNDI))}\. /, seen.first.to_s)
    assert_nil PokeAccess::Info.info_text
  end

  test "any other item used from the bag says nothing, and the bag's handler answers as the game's" do
    result = nil
    with_world_map { result = ItemHandlers.triggerUseFromBag(:POTION) }
    assert_equal 1, result
    assert_nothing_spoken
  end

  test "in brief the world map is said without the keys that close it" do
    PokeAccess::Config.verbosity = :brief
    with_world_map { ItemHandlers.triggerUseFromBag(:MAPAMUNDI) }
    refute_spoken(/#{Regexp.escape(I18n.t(:rv_map_hint))}/)
    assert_spoken(/#{Regexp.escape(I18n.t(:rv_map_lands, :list => SPANISH_LANDS.join(", ")))}/)
  end

  test "the title's credit pictures are said from their transcriptions, queued, once while the title is not up" do
    with_title do
      $scene = Scene_Intro.new
      2.times { PokeAccess::Frame.run_pollers }
    end
    assert_equal [[SPLASH1, false], [SPLASH2, false]], SpeakCapture.log
  end

  test "the credit pictures are not said once the title is built, nor on another scene" do
    with_title do
      $scene = Scene_Intro.new
      $scene.screen = Object.new
      PokeAccess::Frame.run_pollers
      $scene = Scene_Map.new
      PokeAccess::Frame.run_pollers
    end
    refute_spoken(/Rors|Maruno/)
  end

  test "a chapter card is said as painted, at once, as it shows" do
    with_cards do
      Game_Picture.new(1).show("CAPITULO02")
      Game_Picture.new(1).erase
      Game_Picture.new(1).show("CAPITULO03finen")
    end
    assert_equal [["Capítulo 2. ENCRUCIJADA", true], ["Chapter 3. THE MISERABLE", true]], SpeakCapture.log
  end

  test "the defeat banner is said whole as its second half comes up, and a poster as painted" do
    with_cards do
      Game_Picture.new(1).show("victoriapokemon")
      Game_Picture.new(2).show("victoriapokemon2")
      Game_Picture.new(3).show("wantedofix1")
    end
    assert_equal [["POKÉMON IMPARABLE. ¡DERROTADO!", true], ["WANTED. Kurev Ranger Dppt.", true]], SpeakCapture.log
  end

  test "a name card is said after the banner shown over it, and the banner alone says nothing" do
    with_cards do
      banner = Game_Picture.new(2).show("Tomaelcontrol_en")
      on_screen([nil, nil, banner]) { Game_Picture.new(3).show("NombreGalg") }
    end
    assert_equal [["Takes control. Galg Kir", true]], SpeakCapture.log
  end

  test "a name card with no banner on screen says the name alone" do
    with_cards { on_screen([nil]) { Game_Picture.new(3).show("NombreSirfetchd") } }
    assert_equal [["Sirfetch'd", true]], SpeakCapture.log
  end

  private

  # The menu's ways as it says them: each word with its direction, in order.
  def way_list(pairs)
    pairs.map { |name, dir| I18n.t(:rv_prep_way, :name => name, :dir => I18n.t(dir)) }.join("; ")
  end

  # A character as the PHS says it, with its place among the selectable ones.
  def entry(name, n, tot)
    I18n.t(:list_entry, :name => name, :n => n, :tot => tot)
  end

  # The world map as it is said, before its keys: the item's name, then the labels the picture paints.
  def world_map(lands, regions, coloured)
    [PokeAccess::Data.item_name(:MAPAMUNDI), I18n.t(:rv_map_lands, :list => lands.join(", ")),
     I18n.t(:rv_map_regions, :list => regions.join(", ")), I18n.t(:rv_map_colour, :list => coloured.join(", "))].join(". ")
  end

  # Runs the block with the game's language set as $PokemonSystem holds it (0 Spanish, 1 English), put back after.
  def in_language(index)
    was = $PokemonSystem
    $PokemonSystem = Struct.new(:language).new(index)
    yield
  ensure
    $PokemonSystem = was
  end

  # Runs the block with world_map.rb bound to a bag handler made for it (answering 1 and noting the info key's text
  # as the game's handler runs); its bodies and the handler go after. Answers what the handler noted.
  def with_world_map
    seen = []
    made = !Object.const_defined?(:ItemHandlers)
    if made
      Object.const_set(:ItemHandlers, Module.new)
      ItemHandlers.define_singleton_method(:triggerUseFromBag) { |_item| seen.push(PokeAccess::Info.info_text); 1 }
    end
    bodies = {}
    PokeAccess::Hooks.fn_bodies.each { |k, v| bodies[k] = v.length }
    quiet { eval(Harness.source(WORLD_MAP), TOPLEVEL_BINDING, WORLD_MAP) }
    yield
    seen
  ensure
    PokeAccess::Hooks.fn_bodies.each { |k, v| v.slice!((bodies[k] || 0)..-1) } if bodies
    Object.send(:remove_const, :ItemHandlers) if made && Object.const_defined?(:ItemHandlers)
  end

  # Runs the block with cards.rb evaluated, its transcriptions and its picture handler taken back after.
  def with_cards
    texts = PokeAccess::PictureCues::TEXTS.dup
    handlers = PokeAccess::PictureCues::HANDLERS.length
    PokeAccess::PictureCues.reset_last
    quiet { eval(Harness.source(CARDS), TOPLEVEL_BINDING, CARDS) }
    yield
  ensure
    PokeAccess::PictureCues::TEXTS.replace(texts) if texts
    PokeAccess::PictureCues::HANDLERS.slice!(handlers..-1) if handlers
    PokeAccess::PictureCues.reset_last
  end

  # Runs the block with $game_screen holding these pictures, by slot, put back after.
  def on_screen(pictures)
    was = $game_screen
    $game_screen = Struct.new(:pictures).new(pictures)
    yield
  ensure
    $game_screen = was
  end

  # Runs the block with Ruby's warnings off, as a profile file evaluated again redefines its constants.
  def quiet
    verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = verbose
  end

  # Runs the block with the title's scene and splash list under the game's names and splashes.rb evaluated; its
  # transcriptions, its poller, the scene and the names are put back after.
  def with_title
    texts = PokeAccess::PictureCues::TEXTS.dup
    pollers = PokeAccess::Frame.instance_variable_get(:@pollers)
    count = pollers.length
    scene = $scene
    named = { :Scene_Intro => Class.new(RevivalIntroStandIn), :IntroEventScene => RevivalSplashListStandIn }
    kept = named.keys.map { |n| [n, Object.const_defined?(n, false) ? Object.const_get(n, false) : nil] }
    named.each do |n, k|
      Object.send(:remove_const, n) if Object.const_defined?(n, false)
      Object.const_set(n, k)
    end
    eval(Harness.source(SPLASHES), TOPLEVEL_BINDING, SPLASHES)
    yield
  ensure
    PokeAccess::PictureCues::TEXTS.replace(texts) if texts
    pollers.slice!(count..-1) if pollers
    $scene = scene if kept
    (kept || []).each do |n, k|
      Object.send(:remove_const, n) if Object.const_defined?(n, false)
      Object.const_set(n, k) if k
    end
  end
end
