# Infinite Fusion's alternative sprites page (games/infinitefusion_common/sprites_page.rb): each sprite as which of how
# many, its artist, whether in use or blacklisted, read on arrival, on left and right, on a toggle and in the chooser.

# The Pokedex entry's sprites page, reduced to what the profile hooks: the sprite in use, update_displayed repainting
# the sprite in the middle as drawPage does, the chooser's loop ending (a pick that closes the entry sets @endscene,
# as select_sprite does) and the toggle that puts the selected sprite in or out of its species' blacklist.
class PokemonPokedexInfo_Scene
  def is_main_sprite
    @selected_index == @in_use
  end

  def update_displayed
    @paint.call if @paint
  end

  def pbChooseAlt(_brief = false)
    @endscene = true if @pick_closes
    nil
  end

  def toggle_sprite_blacklist
    letters = $PokemonSystem.sprites_blacklist[getSpecies(@species).species]
    letter = @available[@selected_index].alt_letter
    letters.include?(letter) ? letters.delete(letter) : letters.push(letter)
  end
end

class IfSpritesPageGdTest < PokeAccessTest
  PDX = PokeAccess::PokedexInfoV21
  META = PDX.singleton_class
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "sprites_page.rb")
  CHAINS = PokeAccess::Hooks.instance_variable_get(:@chains)
  DRAW_PAGE = "PokemonPokedexInfo_Scene#drawPage"
  # A sprite as the page keeps it: its alt letter ("" for the base one).
  Sprite = Struct.new(:alt_letter)
  # The game's options, holding Hoenn's sprites blacklist (alt letters by species number).
  Options = Struct.new(:sprites_blacklist)
  # The species data getSpecies gives: its species number.
  SpeciesData = Struct.new(:species)

  # Evaluates the profile file once, as boot does, and answers what it puts on the shared entry reader: its page_id and
  # its drawPage hook. Both are taken back out, so the other tests of the process keep the shared reader as it is
  # (with_sprites_page puts them in); its hooks on the page's own controls stay bound to the stand-in above.
  def self.load_profile
    core = META.instance_method(:page_id)
    chain = CHAINS[DRAW_PAGE]
    shared = chain.length
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    begin
      eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
      [META.instance_method(:page_id), chain.slice!(shared..-1)]
    ensure
      META.send(:define_method, :page_id, core)
      chain.slice!(shared..-1)
      PokeAccess::Game.profiles.replace(profiles)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
    end
  end
  CORE_PAGE_ID = META.instance_method(:page_id)
  IF_PAGE_ID, IF_DRAW_PAGE = load_profile

  test "page 3 is this page, which the shared entry reader leaves to it" do
    pages = with_sprites_page { [3, 2, 1].map { |page| PDX.page_id(Object.new, page) } }
    assert_equal [:page_other, :page_area, :page_info], pages
  end

  test "arriving on the page reads its sprite: which of how many, the artist painted and that it is in use" do
    scene = entry(["", "a"], 0, ["Artista#1", "Otro"])
    with_sprites_page { scene.drawPage(3) }
    assert_equal [["#{pos(1, 2)}, Artista#1, #{in_use}", true]], SpeakCapture.log
  end

  test "drawing the page keeps its return" do
    assert_equal 3, with_sprites_page { entry(["", "a"], 0, ["Artista#1"]).drawPage(3) }
  end

  test "the page drawn again where it was says the same sprite no more" do
    scene = entry(["", "a"], 0, ["Artista#1"])
    with_sprites_page do
      scene.drawPage(3)
      SpeakCapture.clear
      scene.drawPage(3)
    end
    assert_nothing_spoken
  end

  test "a new species on the page reads its sprite again, even the same line" do
    scene = entry(["", "a"], 0, ["Artista#1"])
    with_sprites_page do
      scene.drawPage(3)
      SpeakCapture.clear
      scene.instance_variable_set(:@species, 172)
      scene.drawPage(3)
    end
    assert_equal ["#{pos(1, 2)}, Artista#1, #{in_use}"], SpeakCapture.lines
  end

  test "the page the entry was on before is said again on the way back from this one" do
    scene = entry(["", "a"], 0, ["Artista#1"])
    with_sprites_page do
      scene.drawPage(1)
      said = SpeakCapture.log.dup
      assert_equal 1, said.length, "the page the entry opened on was said"
      scene.drawPage(3)
      SpeakCapture.clear
      scene.drawPage(1)
      assert_equal said, SpeakCapture.log
    end
  end

  test "leaving the page drops the sprite the info key held" do
    scene = entry(["", "a"], 0, ["Artista#1"])
    with_sprites_page do
      scene.drawPage(3)
      scene.drawPage(2)
    end
    assert_nil PokeAccess::Info.info_text
  end

  test "arriving on a page with no sprite to show leaves the info key as it was" do
    scene = entry([], 0, [])
    with_sprites_page do
      PokeAccess::Info.set_info(:text, "Ruta 101")
      scene.drawPage(3)
    end
    assert_equal "Ruta 101", PokeAccess::Info.info_text
  end

  test "another page drawn again where it was leaves the info key as it was" do
    scene = entry(["", "a"], 0, ["Artista#1"])
    with_sprites_page do
      scene.drawPage(2)
      PokeAccess::Info.set_info(:text, "Ruta 101")
      scene.drawPage(2)
    end
    assert_equal "Ruta 101", PokeAccess::Info.info_text
  end

  test "left and right on the page read the sprite they bring up" do
    scene = entry(["", "a", "b"], 0, ["Artista#1", "Otro"])
    with_sprites_page do
      scene.drawPage(3)
      SpeakCapture.clear
      scene.instance_variable_set(:@selected_index, 1)
      scene.update_displayed
    end
    assert_equal [["#{pos(2, 3)}, Otro", true]], SpeakCapture.log
  end

  test "a sprite reads which of how many, its painted artist and, for the one in use, that it is" do
    scene = entry(["", "a", "b"], 1, [])
    { [1, ["Artista#1234"]] => "#{pos(2, 3)}, Artista#1234",
      [0, ["Otro"]] => "#{pos(1, 3)}, Otro, #{in_use}",
      [0, []] => "#{pos(1, 3)}, #{in_use}" }.each do |(selected, painted), line|
      scene.instance_variable_set(:@selected_index, selected)
      assert_equal line, PokeAccess::IFSpritesPage.text(scene, painted), painted.inspect
    end
  end

  test "a sprite at the reading's levels: which one and whether in use, then of how many, then its artist" do
    scene = entry(["", "a", "b"], 0, [])
    rows = vb_levels { PokeAccess::IFSpritesPage.text(scene, ["Otro"]) }
    assert_equal ["#{t(:if_sprite_n, :n => 1)}, #{in_use}", "#{pos(1, 3)}, #{in_use}", "#{pos(1, 3)}, Otro, #{in_use}"],
                 rows
  end

  test "the info key keeps the whole sprite at any level" do
    PokeAccess::Config.verbosity = :brief
    PokeAccess::IFSpritesPage.text(entry(["", "a", "b"], 0, []), ["Otro"])
    assert_equal "#{pos(1, 3)}, Otro, #{in_use}", PokeAccess::Info.info_text
  end

  test "a page that cannot tell which sprite is in use marks none" do
    scene = Object.new
    scene.instance_variable_set(:@available, [Sprite.new(""), Sprite.new("a")])
    scene.instance_variable_set(:@selected_index, 0)
    assert_equal "#{pos(1, 2)}, Otro", PokeAccess::IFSpritesPage.text(scene, ["Otro"])
  end

  test "a page with no sprite to show has no line" do
    [[[], 0], [nil, 0], [["", "a"], nil]].each do |list, selected|
      scene = PokemonPokedexInfo_Scene.new
      scene.instance_variable_set(:@available, list)
      scene.instance_variable_set(:@selected_index, selected)
      assert_nil PokeAccess::IFSpritesPage.text(scene, ["Otro"]), [list, selected].inspect
    end
  end

  test "a sprite on its species' blacklist is said to be out of the random pick" do
    scene = entry(["", "a"], 1, [])
    with_blacklist(["a"]) do
      assert_equal "#{pos(2, 2)}, #{t(:if_sprite_excluded)}", PokeAccess::IFSpritesPage.text(scene, [])
    end
  end

  test "a sprite another species blacklists, or a game with no blacklist, says nothing of it" do
    scene = entry(["", "a"], 1, [])
    scene.instance_variable_set(:@species, 172)
    assert_equal pos(2, 2), with_blacklist(["a"]) { PokeAccess::IFSpritesPage.text(scene, []) }, "another species"
    scene.instance_variable_set(:@species, 25)
    assert_equal pos(2, 2), PokeAccess::IFSpritesPage.text(scene, []), "no blacklist"
  end

  test "the blacklist toggle says the state the sprite's icon now shows" do
    scene = entry(["", "a"], 1, [])
    with_blacklist([]) do
      scene.toggle_sprite_blacklist
      scene.toggle_sprite_blacklist
    end
    assert_equal [[t(:if_sprite_excluded), true], [t(:if_sprite_allowed), true]], SpeakCapture.log
  end

  test "a toggle with no sprite selected says nothing" do
    [[[], 0], [["", "a"], 2], [["", "a"], nil]].each do |list, selected|
      scene = PokemonPokedexInfo_Scene.new
      scene.instance_variable_set(:@available, list)
      scene.instance_variable_set(:@selected_index, selected)
      PokeAccess::IFSpritesPage.toggled(scene)
    end
    assert_nothing_spoken
  end

  test "the sprite chooser says that left and right now change the sprite, and on leaving that the entry is back" do
    PokemonPokedexInfo_Scene.new.pbChooseAlt
    assert_equal [[t(:if_sprite_choosing), true], [t(:if_sprite_chosen), false]], SpeakCapture.log
  end

  test "a pick that closes the whole entry leaves no entry to go back to" do
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@pick_closes, true)
    scene.pbChooseAlt
    assert_equal [[t(:if_sprite_choosing), true]], SpeakCapture.log
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # "Sprite n of m", as the line leads.
  def pos(n, m)
    t(:if_sprite_pos, :n => n, :m => m)
  end

  def in_use
    t(:if_sprite_main)
  end

  # Pikachu's entry on the sprites page: its sprites by alt letter, the one selected, the first in use, and the artist
  # the page paints for each (none past the list, as for a generated sprite).
  def entry(letters, selected, artists)
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@species, 25)
    scene.instance_variable_set(:@available, letters.map { |l| Sprite.new(l) })
    scene.instance_variable_set(:@selected_index, selected)
    scene.instance_variable_set(:@in_use, 0)
    scene.instance_variable_set(:@paint, lambda do
      artist = artists[scene.instance_variable_get(:@selected_index)]
      pbDrawTextPositions(nil, [[artist, 181, 324, 0, nil, nil]]) if artist
    end)
    scene
  end

  # Runs the block with the profile's page_id and drawPage hook on the shared entry reader, taken back out afterwards.
  def with_sprites_page
    META.send(:define_method, :page_id, IF_PAGE_ID)
    CHAINS[DRAW_PAGE].concat(IF_DRAW_PAGE)
    yield
  ensure
    CHAINS[DRAW_PAGE].reject! { |hook| IF_DRAW_PAGE.any? { |mine| mine.equal?(hook) } }
    META.send(:define_method, :page_id, CORE_PAGE_ID)
  end

  # Runs the block in Hoenn, Pikachu's (species 25) blacklist holding letters: the game's options and its getSpecies,
  # both taken back afterwards.
  def with_blacklist(letters)
    was = $PokemonSystem
    $PokemonSystem = Options.new({ 25 => letters })
    GameFunctions.with(:getSpecies => lambda { |species| SpeciesData.new(species == 25 ? 25 : nil) }) { yield }
  ensure
    $PokemonSystem = was
  end
end
