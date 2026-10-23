# Infinite Fusion's fifth summary page runs the species' Pokedex entry inside its draw and steps back to the moves
# page: the readers inside that draw speak, then the page the scene is back on, not the vanilla fifth (ribbons).
class IfDexPageGdTest < PokeAccessTest
  T = PokeAccess::I18n
  PROFILE = File.join(Harness::ROOT, "games", "infinitefusion_common", "dex_page.rb")
  INSTALLED = {}
  Move = Struct.new(:id, :name, :pp, :total_pp, :type)

  test "says what the readers inside the Pokedex page's draw say, then the moves page it steps back to" do
    log = with_dex_page { dex_trip(pika) }
    assert_equal [[focused_move, true], [moves_page, true]], log
  end

  test "says a page drawn again unchanged once, as the core does" do
    log = with_dex_page do
      scene = started(pika)
      SpeakCapture.clear
      2.times { scene.drawPage(4) }
      SpeakCapture.log.dup
    end
    assert_equal [[moves_page, true]], log
  end

  test "reads pages one to four as the core does" do
    pk = pika
    walk = lambda do
      scene = started(pk)
      [2, 3, 4].each { |page| scene.drawPage(page) }
      SpeakCapture.log.dup
    end
    SpeakCapture.clear
    plain = walk.call
    SpeakCapture.clear
    assert_equal plain, with_dex_page { walk.call }
  end

  private

  # Pika at level 20, knowing two moves.
  def pika
    Poke.build(:name => "Pika", :level => 20, :moves => [Move.new(:TACKLE, "Placaje", 35, 35, :NORMAL),
                                                          Move.new(:THUNDERSHOCK, "Impactrueno", 30, 30, :ELECTRIC)])
  end

  # Pika's moves page: each move's painted name, its type as the engine names it ("Type<id>") and its PP.
  def moves_page
    T.t(:sm_moves, :list => "Placaje. #{T.t(:mv_type, :t => 'TypeNORMAL')}. #{T.t(:mv_pp, :pp => 35, :tot => 35)}, " \
                            "Impactrueno. #{T.t(:mv_type, :t => 'TypeELECTRIC')}. #{T.t(:mv_pp, :pp => 30, :tot => 30)}")
  end

  # The move reader's line for the bare id the Pokedex's list focuses: the id for its name, then what the engine's
  # data gives a move it cannot look up (type TYPE1, physical, power 40, accuracy 100, "desc").
  def focused_move
    ["THUNDERBOLT", T.t(:mv_type, :t => "TypeTYPE1"), T.t(:cat_physical), T.t(:mv_power, :p => 40), T.t(:mv_acc, :a => 100),
     "desc"].join(". ")
  end

  # A summary opened on pk alone, its first page drawn.
  def started(pk)
    scene = PokemonSummary_Scene.new
    scene.pbStartScene([pk], 0)
    scene
  end

  # What drawing the fifth page says after the moves page: the game's draw opens the Pokedex entry, whose moves list
  # focuses a move, and puts the scene back on page four.
  def dex_trip(pk)
    scene = started(pk)
    scene.drawPage(4)
    scene.on_draw = lambda do |page|
      next unless page == 5
      scene.drawSelectedMove(nil, :THUNDERBOLT)
      scene.instance_variable_set(:@page, 4)
    end
    SpeakCapture.clear
    scene.drawPage(5)
    SpeakCapture.log.dup
  end

  # The block's value with the profile's override of SummaryV21.speak_page in place, the core's put back after. The
  # profile is evaluated once and its override kept, so a test never stacks a second one.
  def with_dex_page
    plain = PokeAccess::SummaryV21.method(:speak_page)
    install_profile if INSTALLED.empty?
    PokeAccess::SummaryV21.define_singleton_method(:speak_page, INSTALLED[:speak_page])
    yield
  ensure
    PokeAccess::SummaryV21.define_singleton_method(:speak_page, plain)
  end

  # Evaluates the profile's file as the harness loads one, keeps the override it installs, and takes its profile name
  # back out.
  def install_profile
    game = PokeAccess::Game
    profiles = game.profiles.dup
    name = game.instance_variable_get(:@profile_name)
    eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
    INSTALLED[:speak_page] = PokeAccess::SummaryV21.method(:speak_page)
  ensure
    game.profiles.replace(profiles)
    game.instance_variable_set(:@profile_name, name)
  end
end
