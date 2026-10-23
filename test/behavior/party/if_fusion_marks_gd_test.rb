# Infinite Fusion's own marks: its shiny stars (both halves', black, Hoenn's blue) and a fusion's head and body on the
# first summary page, and in the PC the splicers' fuse mode and what the held Pokemon does with the slot it is over.
class IfFusionMarksGdTest < PokeAccessTest
  T = PokeAccess::I18n
  FILES = %w[fusion_marks storage_fusion].map { |n| File.join(Harness::ROOT, "games", "infinitefusion_common", "#{n}.rb") }.freeze
  OVERRIDDEN = [[PokeAccess::Party, :shiny_word], [PokeAccess::Party, :held_key],
                [PokeAccess::SummaryGameData, :info_text]].freeze
  FUSING = "PokemonStorageScene#setFusing"
  INSTALLED = {}
  NB = 501
  Species = Struct.new(:species)
  Halves = Struct.new(:get_head_species, :get_body_species)

  test "says both stars for a fusion whose head and body are both shiny" do
    with_fusion_marks { assert_equal T.t(:if_shiny_both), PokeAccess::Party.shiny_word(shiny_halves(true, true)) }
  end

  test "gives the info key both stars too" do
    pk = shiny_halves(true, true)
    glance = T.t(:pk_glance, :name => "Pikachar", :level => 25, :hp => 40, :tot => 40)
    with_fusion_marks { assert_equal "#{glance} #{T.t(:if_shiny_both)}. ♂.", PokeAccess::Info.pokemon_info(pk) }
  end

  test "says one star for a fusion with one shiny half, one half it can ask, or no halves to ask" do
    head_only = Poke.build(:shiny => true)
    head_only.define_singleton_method(:headShiny?) { true }
    body_only = Poke.build(:shiny => true)
    body_only.define_singleton_method(:bodyShiny?) { true }
    with_fusion_marks do
      { "one shiny half" => shiny_halves(true, false), "only the head to ask" => head_only, "only the body to ask" => body_only,
        "no halves to ask" => Poke.build(:shiny => true) }.each do |what, pk|
        assert_equal T.t(:pk_shiny), PokeAccess::Party.shiny_word(pk), what
      end
    end
  end

  test "says a star drawn black, a shiny not rolled naturally, for one star or two" do
    with_fusion_marks do
      { [true, false] => T.t(:pk_shiny), [true, true] => T.t(:if_shiny_both) }.each do |halves, word|
        pk = shiny_halves(*halves)
        pk.define_singleton_method(:debugShiny?) { true }
        assert_equal T.t(:if_shiny_unnatural, :shiny => word), PokeAccess::Party.shiny_word(pk), "halves #{halves.inspect}"
      end
    end
  end

  test "says Hoenn's radar shiny, whose star is drawn blue, as a plain star" do
    pk = shiny_halves(true, false)
    pk.define_singleton_method(:debugShiny?) { true }
    pk.define_singleton_method(:radarShiny?) { true }
    with_fusion_marks { assert_equal T.t(:pk_shiny), PokeAccess::Party.shiny_word(pk) }
  end

  test "closes a fusion's first summary page with its head and body" do
    pk = fusion
    with_species_names do
      page = PokeAccess::SummaryGameData.info_text(pk)
      halves = "#{T.t(:if_head, :n => 'Pikachu')} #{T.t(:if_body, :n => 'Charmander')}"
      with_fusion_marks { assert_equal "#{page} #{halves}", PokeAccess::SummaryGameData.info_text(pk) }
    end
  end

  test "names no halves for a Pokemon the game does not call a fusion, or whose halves it cannot name" do
    single = fusion
    single.define_singleton_method(:isFusion?) { false }
    unasked = fusion
    unasked.singleton_class.send(:remove_method, :isFusion?)
    with_species_names do
      { "no fusion" => Poke.build(:name => "Pika"), "isFusion? false" => single, "no isFusion? to ask" => unasked,
        "a half it cannot name" => fusion(:MISSINGNO) }.each do |what, pk|
        page = PokeAccess::SummaryGameData.info_text(pk)
        with_fusion_marks { assert_equal page, PokeAccess::SummaryGameData.info_text(pk), what }
      end
    end
  end

  test "with the splicers armed, the slot under the cursor is the one fused with" do
    with_dex_numbers do
      with_fusion_marks do
        assert_equal :if_pc_fuse, PokeAccess::Party.held_key(pc(true)), "no Pokemon given"
        assert_equal :if_pc_fuse, PokeAccess::Party.held_key(pc(true), Species.new(:PIKACHU)), "a single species"
        assert_equal :if_pc_fuse, PokeAccess::Party.held_key(pc(true), Species.new(:LAST)), "the last single species"
      end
    end
  end

  test "with the splicers armed, a slot already fused is said to be one, its icon hidden" do
    with_dex_numbers do
      with_fusion_marks { assert_equal :if_pc_fused, PokeAccess::Party.held_key(pc(true), Species.new(:B25H6)) }
    end
  end

  test "takes a slot whose dex number cannot be read as no fusion" do
    with_dex_numbers do
      with_fusion_marks { assert_equal :if_pc_fuse, PokeAccess::Party.held_key(pc(true), Species.new(:BROKEN)) }
    end
  end

  test "swaps with the slot while the splicers are put away, or with no screen to ask" do
    with_dex_numbers do
      with_fusion_marks do
        assert_equal :pc_swap, PokeAccess::Party.held_key(pc(false), Species.new(:B25H6)), "splicers put away"
        assert_equal :pc_swap, PokeAccess::Party.held_key(Object.new, Species.new(:B25H6)), "no screen"
      end
    end
  end

  test "says the splicers armed and put away in the PC, each change once, interrupting" do
    log = with_fusion_marks { fusing(PokemonStorageScene.new, [true, true, false]) }
    assert_equal [[T.t(:if_fuse_on), true], [T.t(:if_fuse_off), true]], log
  end

  test "counts a box never armed as off, and takes any true argument as on" do
    log = with_fusion_marks { fusing(PokemonStorageScene.new, [false, nil, 1, true]) }
    assert_equal [[T.t(:if_fuse_on), true]], log
  end

  private

  # A shiny fusion whose head and body answer whether each is shiny.
  def shiny_halves(head, body)
    pk = Poke.build(:name => "Pikachar", :shiny => true)
    pk.define_singleton_method(:headShiny?) { head }
    pk.define_singleton_method(:bodyShiny?) { body }
    pk
  end

  # A fusion of Pikachu's head on Charmander's body (body, if given, for the body's species).
  def fusion(body = :CHARMANDER)
    pk = Poke.build(:name => "Pikachar")
    halves = Halves.new(:PIKACHU, body)
    pk.define_singleton_method(:isFusion?) { true }
    pk.define_singleton_method(:species_data) { halves }
    pk
  end

  # A PC scene whose screen has the splicers armed or not.
  def pc(armed)
    screen = Object.new
    screen.define_singleton_method(:fusionMode) { armed }
    scene = Object.new
    scene.instance_variable_set(:@screen, screen)
    scene
  end

  # What scene says as setFusing is called with each argument in turn.
  def fusing(scene, args)
    SpeakCapture.clear
    args.each { |a| scene.setFusing(a) }
    SpeakCapture.log.dup
  end

  # Runs the block with the game's getPokemon naming Pikachu and Charmander (and failing for any other species).
  def with_species_names(&blk)
    names = { :PIKACHU => "Pikachu", :CHARMANDER => "Charmander" }
    GameFunctions.with(:getPokemon => lambda { |sp| Struct.new(:name).new(names.fetch(sp)) }, &blk)
  end

  # Runs the block with the game's NB_POKEMON and dexNum: a fusion's number past NB_POKEMON, LAST the last single
  # species, BROKEN one whose number cannot be read.
  def with_dex_numbers(&blk)
    made = !Object.const_defined?(:NB_POKEMON)
    Object.const_set(:NB_POKEMON, NB) if made
    numbers = lambda do |sp|
      raise "no number" if sp == :BROKEN
      { :B25H6 => 25 * NB + 6, :LAST => NB }.fetch(sp, 25)
    end
    GameFunctions.with(:dexNum => numbers, &blk)
  ensure
    Object.send(:remove_const, :NB_POKEMON) if made
  end

  # The block's value with the profile's overrides and its setFusing hook in place, the core's put back after. The
  # profile is evaluated once and what it installs kept, so a test never stacks a second hook.
  def with_fusion_marks
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    plain = OVERRIDDEN.map { |m, n| [m, n, m.method(n)] }
    aside = chains.delete(FUSING)
    stub = PokemonStorageScene.instance_method(:setFusing)
    install_profile(chains) if INSTALLED.empty?
    INSTALLED[:methods].each { |m, n, meth| m.define_singleton_method(n, meth) }
    chains[FUSING] = INSTALLED[:chain]
    PokemonStorageScene.send(:define_method, :setFusing, INSTALLED[:fusing])
    yield
  ensure
    plain.each { |m, n, meth| m.define_singleton_method(n, meth) }
    chains.delete(FUSING)
    chains[FUSING] = aside if aside
    PokemonStorageScene.send(:define_method, :setFusing, stub)
  end

  # Evaluates the profile's files as the harness loads one, keeps what they install, and takes the profile name back
  # out.
  def install_profile(chains)
    game = PokeAccess::Game
    profiles = game.profiles.dup
    name = game.instance_variable_get(:@profile_name)
    FILES.each { |f| eval(Harness.source(f), TOPLEVEL_BINDING, f) }
    INSTALLED[:methods] = OVERRIDDEN.map { |m, n| [m, n, m.method(n)] }
    INSTALLED[:chain] = chains[FUSING]
    INSTALLED[:fusing] = PokemonStorageScene.instance_method(:setFusing)
  ensure
    game.profiles.replace(profiles)
    game.instance_variable_set(:@profile_name, name)
  end
end
