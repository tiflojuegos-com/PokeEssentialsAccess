# The games' own screens with no Essentials window to read, each said from what it paints or keeps: Reminiscencia's
# notices, upgrade tree, help and blessings, Relict's starter, Realidea's vision, Awakening's cards and talismans, the
# gachapon, the ZUD raid database, Infinite Fusion's PC and wardrobe, Opalo's card, Armonia's DexNav and the starter
# selection plugin.

# The profile readers whose hooks would reach past these tests (a save screen, the key item ceremony, the games'
# own classes), each file's module alone, evaluated at its own lines: the tests call the readers as the hooks would.
%w[reminiscencia/info_screens relict/arcy realidea/system_scene awakening/fates_extra awakening/fates_screens
   infinitefusion_common/storage_fusion infinitefusion_common/outfits opalo/trainer_card].each do |rel|
  path = File.join(Harness::ROOT, "games", "#{rel}.rb")
  source = Harness.source(path)
  block = source.match(/^module PokeAccess\r?\n.*?^end\r?\n/m)
  eval(block[0], TOPLEVEL_BINDING, path, source[0, block.begin(0)].count("\n") + 1)
end

# Armonia's DexNav, down to what its hooks wrap: each page it loads, and its opening, which on a map with no encounter
# zones returns at once.
class DexNav
  def loadCurrentPage; :loaded; end
  def startUI; :opened; end
end
dexnav_path = File.join(Harness::ROOT, "games", "armonia", "dexnav.rb")
eval(Harness.source(dexnav_path), TOPLEVEL_BINDING, dexnav_path)

# Reminiscencia's upgrade tree, help screen and world map, down to what their hooks wrap: the tree's cursor, purchase
# and end; the help list's loop, two of its frames with the section the player opens between them when @opens, and
# the section, whose paragraph it paints on its "desc" panel; the map's place, painted on its "info" panel. Their
# constructors, which run the whole screen, are not used: the tests build them with allocate.
class ScrollTree
  def positionSelector; :moved; end
  def raiseStat; :raised; end
  def pbEndScene; :ended; end
end

class AyudasUI
  def update
    Input.update
    chosenOption if @opens
    Input.update
    :closed
  end

  def chosenOption
    drawTextEx(@sprites["desc"].bitmap, 16, 16, 480, 8, @paragraph)
    :shown
  end
end

class OpenWorldMap
  def drawInfo
    pbDrawTextPositions(@sprites["info"].bitmap, @rows)
    :drawn
  end
end
extras_path = File.join(Harness::ROOT, "games", "reminiscencia", "extras.rb")
eval(Harness.source(extras_path), TOPLEVEL_BINDING, extras_path)

# Reminiscencia's blessing chooser, down to what its hooks wrap: moving and re-rolling the cards, and the legend as the
# game paints it, the key pictures first, then the texts and the coins, at its coordinates.
class PickBlessing
  def updateCursor; :moved; end
  def swapCard; :swapped; end

  def drawMaintext
    pbDrawImagePositions(nil, [["Graphics/Pictures/Blessings/A", 400, 286, 0, 0, -1, -1],
                               ["Graphics/Pictures/Blessings/C", 304, 358, 0, 0, -1, -1],
                               ["Graphics/Pictures/Blessings/Z", 352, 322, 0, 0, -1, -1],
                               ["Graphics/Pictures/Blessings/coinBox", 474, 250, 0, 0, -1, -1]])
    pbDrawTextPositions(nil, [["Ver porcentajes", 448, 290, 0], ["Escoger bendición", 352, 362, 0],
                              ["Resetear cartas", 400, 326, 0], ["Monedas: 12", 614, 254, 1]])
  end
end
blessings_path = File.join(Harness::ROOT, "games", "reminiscencia", "blessings.rb")
eval(Harness.source(blessings_path), TOPLEVEL_BINDING, blessings_path)

# shiney570's starter selection, down to its input step: on C it runs pressBall, which fades in the starter's name and
# types and opens the Yes/No window inside it.
class PokemonStarterSelection
  attr_accessor :chooses

  def gettinginput
    pressBall if @chooses
    :input
  end

  def pressBall
    confirm = Window_DrawableCommand.new(["Sí", "No"])
    confirm.index = 0
    confirm.update
    :pressed
  end
end
starter_path = File.join(Harness::ROOT, "plugins", "starter_selection.rb")
eval(Harness.source(starter_path), TOPLEVEL_BINDING, starter_path)

# The ZUD plugin's Max Raid database, down to what its hooks wrap: the search panel's loop, the species grid's, a
# species page's loop and its paint, each running the block it is given as its frames. The harness's load of the
# plugin left its four hooks unbound, the class not being there yet: they alone are evaluated again, at their own
# lines, over this one; its paint wraps and its poller, bound then, are the ones that run.
class RaidDataScene
  def pbRaidData
    yield if block_given?
    :search_closed
  end

  def pbSpeciesSelect
    yield if block_given?
    :grid_closed
  end

  def pbSetSpeciesData(_pkmn)
    yield if block_given?
    :page_painted
  end

  def pbRaidDataBase(_pkmn)
    yield if block_given?
    :page_closed
  end
end
raid_path = File.join(Harness::ROOT, "plugins", "zud_raid_database.rb")
raid_source = Harness.source(raid_path)
raid_source.scan(/^PokeAccess::Hooks\.around_hook\("RaidDataScene".*?^end\r?\n/m) do
  hook = Regexp.last_match
  eval(hook[0], TOPLEVEL_BINDING, raid_path, raid_source[0, hook.begin(0)].count("\n") + 1)
end

class CustomScreensTest < PokeAccessTest
  # Awakening's relationship card as the trainer's list holds it.
  FatesCard = Struct.new(:nombre, :edad, :titulo, :cumpleanios, :aliados, :localidad, :signo, :exp, :exp_t,
                         :rango_visible, :citas_completadas, :index, :info)
  # The level bonuses PersonajesFates keeps per character: Lana's (0) at levels 1 and 3, none yet for Kai (1).
  BONUSES = { 0 => { 1 => { :titulo => "Confianza", :descripcion => "Sube el ataque." },
                     3 => { :titulo => "Lealtad", :descripcion => "Cura al final del combate." } },
              1 => {} }
  # The talisman the equip screen lists.
  SUN = { :id => 7, :name => "Talismán del Sol", :symbol => :sol, :description => "Sube el ataque.",
          :lore => "Forjado al alba." }
  # The raid database's search panel rows, the bitmaps it paints its values and its page stamp on, and a species page
  # as painted: the data column right of x 360, the four move lists at x 92 and 270, the lower two from y 212.
  RAID_ROWS = ["Show Pokemon", "Raid Level", "Type", "Habitat", "Region", "Exit"]
  RAID_OVERLAY = Object.new
  RAID_PAGES = Object.new
  RAID_PAGE = [["Pikachu", :positions, 434, 10], ["#025", :positions, 477, 46], ["Appears In:", :positions, 383, 217],
               ["Raid Lv. 1", :positions, 360, 245], ["Habitat:", :positions, 434, 318],
               ["Forest", :positions, 434, 344], ["Thunderbolt", :positions, 92, 24],
               ["Quick Attack", :positions, 92, 41], ["None Found", :positions, 270, 85],
               ["Discharge", :positions, 92, 212], ["Charm", :positions, 270, 212]]
  # Meowth's species page on its Alolan form's name, with none of its four move lists holding a move: each is painted
  # as None Found, where the plugin paints an empty list.
  MEOWTH_PAGE = [["Meowth", :positions, 434, 10], ["#052", :positions, 477, 46], ["Alolan Form", :positions, 434, 139],
                 ["None Found", :positions, 92, 85], ["None Found", :positions, 270, 85],
                 ["None Found", :positions, 92, 278], ["None Found", :positions, 270, 278]]
  # A species as the raid database's page knows it.
  RaidSpecies = Struct.new(:species, :id, :type1, :type2, :gmax) do
    def hasGmax?; gmax; end
  end
  # Opalo's badge names as its badge ceremony paints them (FANCY_BADGE_NAMES).
  OPALO_BADGES = ["Medalla Corriente", "Medalla Doma", "Medalla Ferro", "Medalla Presa", "Medalla Évoca",
                  "Medalla Descarga", "Medalla Géminis", "Medalla Témpano"]
  # The zones the DexNav's arrows move between, by the picture each page shows.
  DEXNAV_ZONES = [[0, "dexnavtierra"], [1, "dexnavsurf"], [2, "dexnavrio"]]
  # The bitmaps Reminiscencia's help panel and world map panel paint on.
  HELP_PANEL = Object.new
  MAP_PANEL = Object.new
  # The blessing the chooser deals: BLESSINGS_HASH's [category, rarity, _, description].
  BLESSINGS = { :B1 => [1, 2, nil, "Sube el ataque."] }

  test "says Reminiscencia's full-screen notice once it has painted, queued, its arrows as colons" do
    PokeAccess::PaintCapture.arm(:rem_info)
    pbDrawTextPositions(nil, [["Flechas => Moverse", 320, 40, 0], ["Z=>Correr", 320, 78, 0]])
    PokeAccess::ReminInfoScreens.poll
    PokeAccess::ReminInfoScreens.poll
    assert_equal [["Flechas: Moverse, Z: Correr", false]], SpeakCapture.log
  ensure
    PokeAccess::PaintCapture.take(:rem_info)
  end

  test "a Reminiscencia notice polled before it paints is still said once it does" do
    PokeAccess::PaintCapture.arm(:rem_info)
    PokeAccess::ReminInfoScreens.poll
    pbDrawTextPositions(nil, [["Z => Correr", 320, 78, 0]])
    PokeAccess::ReminInfoScreens.poll
    assert_equal [["Z: Correr", false]], SpeakCapture.log
  ensure
    PokeAccess::PaintCapture.take(:rem_info)
  end

  test "says Reminiscencia's save screen play time right after the save's first question" do
    PokeAccess::ReminInfoScreens.save_time(World.stub_scene(:@infowindow => window("Tiempo real jugado: 01:05")))
    PokeAccess.say_dialogue("¿Quieres guardar la partida?")
    assert_equal [["¿Quieres guardar la partida?", false], ["Tiempo real jugado: 01:05", false]], SpeakCapture.log
  end

  test "a save screen with no play time window adds nothing to its question" do
    PokeAccess::ReminInfoScreens.save_time(World.stub_scene)
    PokeAccess.say_dialogue("¿Guardar en el archivo 2?")
    assert_equal [["¿Guardar en el archivo 2?", false]], SpeakCapture.log
  end

  test "says Relict's starter presentation line, queued, as it waits" do
    PokeAccess::RelictArcy.starter(World.stub_scene(:@sprites => { "helpwindow" => window("Ah, Bulbasaur.") }))
    assert_equal [["Ah, Bulbasaur.", false]], SpeakCapture.log
  end

  test "a starter presentation with a blank help line says nothing" do
    PokeAccess::RelictArcy.starter(World.stub_scene(:@sprites => { "helpwindow" => window("") }))
    assert_nothing_spoken
  end

  test "says Realidea's vision wheel's first option, then the points it shows, as it opens" do
    $game_variables[50] = 340
    realidea(:MAIN) do |rs|
      rs.poll
      assert_equal [[t(:rl_sys_heal), true], [t(:rl_sys_points, :n => 340), false]], SpeakCapture.log
    end
  end

  test "says the wheel's points once, as it opens, and not as it turns" do
    $game_variables[50] = 340
    realidea(:MAIN) do |rs|
      rs.poll
      SpeakCapture.clear
      pressing(Input::RIGHT) { rs.poll }
      assert_equal [[t(:rl_sys_moves), true]], SpeakCapture.log
    end
  end

  test "the wheel wraps around at both ends" do
    realidea(:MAIN) do |rs|
      rs.poll
      SpeakCapture.clear
      pressing(Input::LEFT) { rs.poll }
      pressing(Input::RIGHT) { rs.poll }
      assert_equal [[t(:rl_sys_repel), true], [t(:rl_sys_heal), true]], SpeakCapture.log
    end
  end

  test "left steps the wheel back one option" do
    realidea(:MAIN) do |rs|
      rs.poll
      SpeakCapture.clear
      [Input::RIGHT, Input::RIGHT, Input::LEFT].each { |key| pressing(key) { rs.poll } }
      assert_equal [[t(:rl_sys_moves), true], [t(:rl_sys_levelup), true], [t(:rl_sys_moves), true]], SpeakCapture.log
    end
  end

  test "up and down leave the wheel where it is" do
    realidea(:MAIN) do |rs|
      rs.poll
      SpeakCapture.clear
      pressing(Input::UP) { rs.poll }
      pressing(Input::DOWN) { rs.poll }
      assert_nothing_spoken
    end
  end

  test "the cure grid steps by three rows and stops at its edges" do
    realidea(:CURE) do |rs|
      rs.poll
      SpeakCapture.clear
      [Input::DOWN, Input::DOWN, Input::RIGHT, Input::RIGHT, Input::RIGHT, Input::UP, Input::UP].each do |key|
        pressing(key) { rs.poll }
      end
      assert_equal [[t(:rl_cure_120), true], [t(:rl_cure_200), true], [t(:rl_cure_revive), true],
                    [t(:rl_cure_80), true]],
                   SpeakCapture.log
    end
  end

  test "left from a vision grid's first option reaches its dead position, said as no selection" do
    realidea(:CURE) do |rs|
      rs.poll
      SpeakCapture.clear
      [Input::LEFT, Input::LEFT, Input::RIGHT].each { |key| pressing(key) { rs.poll } }
      assert_equal [[t(:rl_sys_none), true], [t(:rl_cure_20), true]], SpeakCapture.log
    end
  end

  test "a vision ability is said by name while its icon is lit, and as unavailable while faded" do
    $game_switches[142] = true
    realidea(:MOVES) do |rs|
      rs.poll
      pressing(Input::RIGHT) { rs.poll }
      assert_equal [[t(:rl_mo_cut), true], ["#{t(:rl_mo_rocksmash)}, #{t(:opt_unavailable)}", true]], SpeakCapture.log
    end
  end

  test "each vision ability's icon is lit by its own switch" do
    { 1 => [142, :rl_mo_cut], 2 => [143, :rl_mo_rocksmash], 3 => [153, :rl_mo_flash], 4 => [144, :rl_mo_strength],
      5 => [86, :rl_mo_fly] }.each do |sel, (switch, key)|
      $game_switches.clear
      $game_switches[switch] = true
      realidea(:MOVES) { |rs| assert_equal t(key), rs.label(sel), "ability #{sel}, switch #{switch}" }
    end
  end

  test "a message's arrows do not move the wheel, which keeps quiet under it" do
    $game_variables[50] = 5
    realidea(:MAIN) do |rs|
      $game_temp.message_window_showing = true
      pressing(Input::RIGHT) { rs.poll }
      $game_temp.message_window_showing = nil
      rs.poll
      assert_equal [[t(:rl_sys_heal), true], [t(:rl_sys_points, :n => 5), false]], SpeakCapture.log
    end
  ensure
    $game_temp.message_window_showing = nil
  end

  test "a screen held over the wheel keeps it still, and its end says nothing" do
    realidea(:MAIN) do |rs|
      rs.poll
      SpeakCapture.clear
      rs.hold
      pressing(Input::RIGHT) { rs.poll }
      rs.unhold
      rs.poll
      pressing(Input::RIGHT) { rs.poll }
      assert_equal [[t(:rl_sys_moves), true]], SpeakCapture.log
    end
  end

  test "back from one of its own menus, the wheel says its option again" do
    realidea(:MAIN) do |rs|
      rs.poll
      rs.start(PokeAccess::RealideaSystem::MOVES)
      rs.stop
      SpeakCapture.clear
      rs.poll
      assert_equal [[t(:rl_sys_heal), true]], SpeakCapture.log
    end
  end

  test "with its menus closed, the vision says nothing" do
    realidea(:MAIN) do |rs|
      rs.stop
      rs.stop
      pressing(Input::RIGHT) { rs.poll }
      assert_nothing_spoken
    end
  end

  test "says an Awakening card's profile: its fields, the stars lit, the dates done, the one waiting and its keys" do
    with_fates([lana]) do |fx|
      assert_equal [lana_profile(4), t(:awk_prof_dates, :n => 2), t(:awk_prof_date_ready),
                    t(:awk_prof_keys)].join(". "),
                   fx.profile(0)
    end
  end

  test "says a card profile's keys from medium, as key hints are" do
    with_fates([lana]) do |fx|
      bare = [lana_profile(4), t(:awk_prof_dates, :n => 2), t(:awk_prof_date_ready)].join(". ")
      keyed = "#{bare}. #{t(:awk_prof_keys)}"
      assert_equal [bare, keyed, keyed], vb_levels { fx.profile(0) }
    end
  end

  test "a card profile with no date done and none unlocked says neither" do
    card = lana
    card.citas_completadas = nil
    with_fates([card], []) do |fx|
      assert_equal [lana_profile(3), t(:awk_prof_keys)].join(". "), fx.profile(0)
    end
  end

  test "a card's date unlocked but already done is not waiting" do
    with_fates([lana], [2], [2]) do |fx|
      assert_equal [lana_profile(4), t(:awk_prof_dates, :n => 2), t(:awk_prof_keys)].join(". "), fx.profile(0)
    end
  end

  test "a place in the list with no card has no profile" do
    with_fates([lana]) { |fx| assert_nil fx.profile(1) }
  end

  test "says a card's notes whole under their title, a blank one left out" do
    with_fates([lana]) do |fx|
      assert_equal [t(:awk_info_title), "Le gusta el té.", "Odia la lluvia."].join(". "), fx.more_info(0)
    end
  end

  test "a card with no notes says their title alone" do
    card = lana
    card.info = nil
    with_fates([card]) { |fx| assert_equal t(:awk_info_title), fx.more_info(0) }
  end

  test "opens a card's level bonuses on their title and first level" do
    with_fates([lana]) do |fx|
      fx.bonus_open(lana)
      assert_equal [["#{t(:awk_bonus_title, :name => 'Lana')}. #{bonus_row(1, 'Confianza')}", true]], SpeakCapture.log
    end
  end

  test "down and up move between the bonus levels, wrapping at both ends" do
    with_fates([lana]) do |fx|
      fx.bonus_open(lana)
      SpeakCapture.clear
      [Input::DOWN, Input::DOWN, Input::UP].each { |key| pressing(key) { fx.bonus_poll } }
      assert_equal [[bonus_row(3, "Lealtad"), true], [bonus_row(1, "Confianza"), true],
                    [bonus_row(3, "Lealtad"), true]],
                   SpeakCapture.log
    end
  end

  test "C shows the focused bonus level's description and hides it again" do
    with_fates([lana]) do |fx|
      fx.bonus_open(lana)
      SpeakCapture.clear
      2.times { pressing(Input::C) { fx.bonus_poll } }
      assert_equal [["Sube el ataque.", true], [bonus_row(1, "Confianza"), true]], SpeakCapture.log
    end
  end

  test "moving to another bonus level hides an open description" do
    with_fates([lana]) do |fx|
      fx.bonus_open(lana)
      SpeakCapture.clear
      [Input::C, Input::DOWN, Input::C].each { |key| pressing(key) { fx.bonus_poll } }
      assert_equal [["Sube el ataque.", true], [bonus_row(3, "Lealtad"), true], ["Cura al final del combate.", true]],
                   SpeakCapture.log
    end
  end

  test "the game's second confirm key shows a bonus level's description as C does" do
    with_fates([lana]) do |fx|
      fx.bonus_open(lana)
      SpeakCapture.clear
      with_consts({ :A2 => 91 }, Input) { pressing(Input::A2) { fx.bonus_poll } }
      assert_equal [["Sube el ataque.", true]], SpeakCapture.log
    end
  end

  test "a bonus level whose date is done is marked as done" do
    card = lana
    card.citas_completadas = { 3 => true }
    with_fates([card]) do |fx|
      fx.bonus_open(card)
      SpeakCapture.clear
      pressing(Input::DOWN) { fx.bonus_poll }
      assert_equal [["#{bonus_row(3, 'Lealtad')}, #{t(:awk_bonus_done)}", true]], SpeakCapture.log
    end
  end

  test "a character with no bonuses yet gets their title and that the list is empty" do
    with_fates([lana]) do |fx|
      fx.bonus_open(kai)
      assert_equal [["#{t(:awk_bonus_title, :name => 'Kai')}. #{t(:list_empty)}", true]], SpeakCapture.log
    end
  end

  test "with no bonus to move between, the keys say nothing" do
    with_fates([lana]) do |fx|
      fx.bonus_open(kai)
      SpeakCapture.clear
      [Input::DOWN, Input::C].each { |key| pressing(key) { fx.bonus_poll } }
      assert_nothing_spoken
    end
  end

  test "a character missing from the bonus table opens nothing" do
    stray = lana
    stray.index = 9
    with_fates([lana]) do |fx|
      fx.bonus_open(stray)
      pressing(Input::DOWN) { fx.bonus_poll }
      assert_nothing_spoken
    end
  end

  test "once the bonuses close, their keys say nothing" do
    with_fates([lana]) do |fx|
      fx.bonus_open(lana)
      fx.bonus_close
      SpeakCapture.clear
      pressing(Input::DOWN) { fx.bonus_poll }
      assert_nothing_spoken
    end
  end

  test "says the talisman screen's cursed energy and both slots as it opens, queued" do
    $game_variables[399] = 45
    $game_variables[397] = 7
    PokeAccess::AwakeningFates.equip_summary(equip_scene)
    assert_equal [[[t(:awk_energy, :n => 45), t(:awk_slot, :n => 1, :name => "Talismán del Sol"),
                    t(:awk_slot, :n => 2, :name => t(:awk_slot_empty))].join(". "), false]],
                 SpeakCapture.log
  end

  test "a talisman slot holding one still locked, or one the list lacks, is empty" do
    $game_variables[397] = 7
    $game_variables[398] = 9
    PokeAccess::AwakeningFates.equip_summary(equip_scene(false))
    empty = t(:awk_slot_empty)
    assert_equal [[[t(:awk_energy, :n => 0), t(:awk_slot, :n => 1, :name => empty),
                    t(:awk_slot, :n => 2, :name => empty)].join(". "), false]],
                 SpeakCapture.log
  end

  test "says the whole lore as its window opens" do
    opening_lore { PokeAccess::AwakeningFates.lore(lore_scene) }
    assert_equal [[(1..9).map { |i| "Linea #{i}." }.join(" "), true]], SpeakCapture.log
  end

  test "each lore scroll step says only the lines it brings into view" do
    scene = lore_scene
    opening_lore { PokeAccess::AwakeningFates.lore(scene) }
    SpeakCapture.clear
    [2, 0].each do |scroll|
      scene.instance_variable_set(:@info_scroll, scroll)
      PokeAccess::AwakeningFates.lore(scene)
    end
    assert_equal [["Linea 6. Linea 7.", true], ["Linea 1. Linea 2.", true]], SpeakCapture.log
  end

  test "a lore repaint at the same scroll says nothing" do
    scene = lore_scene
    opening_lore { PokeAccess::AwakeningFates.lore(scene) }
    SpeakCapture.clear
    PokeAccess::AwakeningFates.lore(scene)
    assert_nothing_spoken
  end

  test "a talisman with no lore is said by the game's placeholder" do
    scene = World.stub_scene(:@selected_index => 0, :@info_scroll => 0)
    scene.define_singleton_method(:selected_talisman) { { :name => "Talismán del Sol" } }
    opening_lore { PokeAccess::AwakeningFates.lore(scene) }
    assert_equal [["Sin información de lore.", true]], SpeakCapture.log
  end

  test "a lore window with no talisman behind it says nothing" do
    scene = World.stub_scene(:@selected_index => 0, :@info_scroll => 0)
    scene.define_singleton_method(:selected_talisman) { nil }
    opening_lore { PokeAccess::AwakeningFates.lore(scene) }
    assert_nothing_spoken
  end

  test "says a talisman's name, its place from medium and its effect in full" do
    scene = equip_scene
    rows = said_at_levels(scene, :awk_talisman) { PokeAccess::AwakeningFates.talisman(scene) }
    assert_equal ["Talismán del Sol", sun_placed, "#{sun_placed}. Sube el ataque."], rows
  end

  test "the info key keeps a talisman's effect while verbosity leaves it unsaid" do
    PokeAccess::Config.verbosity = :brief
    PokeAccess::AwakeningFates.talisman(equip_scene)
    assert_equal "Talismán del Sol. Sube el ataque.", PokeAccess::Info.info_text
  end

  test "a locked talisman says the screen's locked line, its requirement and its progress" do
    with_requirement(40) { PokeAccess::AwakeningFates.talisman(equip_scene(false)) }
    assert_equal [[([sun_placed] + locked_body(40)).join(". "), true]], SpeakCapture.log
  end

  test "a locked talisman at full progress says how to unlock it, from medium" do
    scene = equip_scene(false)
    rows = with_requirement(100) do
      said_at_levels(scene, :awk_talisman) { PokeAccess::AwakeningFates.talisman(scene) }
    end
    ready = ([sun_placed] + locked_body(100) + [t(:awk_talisman_ready)]).join(". ")
    assert_equal [(["Talismán del Sol"] + locked_body(100)).join(". "), ready, ready], rows
  end

  test "a locked talisman with no requirement listed says the locked line alone" do
    with_consts(:TALISMAN_REQUIREMENTS => {}) { PokeAccess::AwakeningFates.talisman(equip_scene(false)) }
    assert_equal [["#{sun_placed}. #{t(:awk_talisman_locked)}", true]], SpeakCapture.log
  end

  test "the gachapon's three-button copy counts the coins it spends" do
    global = Object.new
    def global.gachaCoins; 12; end
    with_globals(:$PokemonGlobal => global) do
      assert_equal [t(:gacha_coins, :n => 12)],
                   PokeAccess::MagicGachapon.counters(World.stub_scene(:@sprites => {}), [], 0)
    end
  end

  test "the gachapon's five-button copy counts the focused banner's pulls and both kinds of ticket" do
    global = Object.new
    global.define_singleton_method(:get_tiradas_banner) { |name| name == "Legendario" ? 4 : 0 }
    bag = Object.new
    bag.define_singleton_method(:quantity) { |item| { :TICKETGACHA => 2, :TICKETGACHAULTRA => 1 }[item] || 0 }
    banners = [Struct.new(:name).new("Normal"), Struct.new(:name).new("Legendario")]
    scene = World.stub_scene(:@sprites => { "button5" => Object.new })
    with_globals(:$PokemonGlobal => global, :$bag => bag) do
      assert_equal [t(:gacha_pulls, :n => 4), t(:gacha_tickets, :n => 2), t(:gacha_ultra, :n => 1)],
                   PokeAccess::MagicGachapon.counters(scene, banners, 1)
    end
  end

  test "says each gachapon prize by name and tier, interrupting the one before" do
    PokeAccess::MagicGachapon.reward("Pikachu", 3)
    PokeAccess::MagicGachapon.reward("Poción", 2, 5)
    assert_equal [[t(:gacha_prize, :name => "Pikachu", :n => 3), true],
                  [t(:gacha_prize_qty, :name => "Poción", :q => 5, :n => 2), true]],
                 SpeakCapture.log
  end

  test "a gachapon prize's amount of one is left unsaid" do
    PokeAccess::MagicGachapon.reward("Poción", 2, 1)
    assert_equal [[t(:gacha_prize, :name => "Poción", :n => 2), true]], SpeakCapture.log
  end

  test "a gachapon prize with no name says nothing" do
    ["", nil].each { |name| PokeAccess::MagicGachapon.reward(name, 3) }
    assert_nothing_spoken
  end

  test "names a gachapon item prize by its symbol as by its number" do
    { :POTION => "Pocion", 1 => "Pocion" }.each do |id, name|
      assert_equal name, PokeAccess::MagicGachapon.item_name(id), "for #{id.inspect}"
    end
  end

  test "a gachapon item prize that carries an amount, named by the game's message after it, says its tier alone" do
    PokeAccess::MagicGachapon.item_prize([:POTION, 5, 2])
    assert_equal [[t(:gacha_stars, :n => 2), true]], SpeakCapture.log
  end

  test "a gachapon item prize with no amount, which goes into the bag unnamed, is named" do
    PokeAccess::MagicGachapon.item_prize([:POTION, 3])
    assert_equal [[t(:gacha_prize, :name => "Pocion", :n => 3), true]], SpeakCapture.log
  end

  test "a gachapon reveal says its reward's tier" do
    PokeAccess::MagicGachapon.reveal(4)
    assert_equal [[t(:gacha_stars, :n => 4), true]], SpeakCapture.log
  end

  test "the gachapon reveal an item prize runs after it is said adds nothing, and the next one says its tier" do
    PokeAccess::MagicGachapon.reward_said
    PokeAccess::MagicGachapon.reveal(4)
    PokeAccess::MagicGachapon.reveal(5)
    assert_equal [[t(:gacha_stars, :n => 5), true]], SpeakCapture.log
  end

  test "the gachapon's Info button panel says the focused banner's description" do
    banners = [Struct.new(:description).new("Huevos."), Struct.new(:description).new("Objetos raros.")]
    PokeAccess::MagicGachapon.info(World.stub_scene(:@banner_sel => 1, :@banners => banners))
    assert_equal [["Objetos raros.", true]], SpeakCapture.log
  end

  test "the raid database opens on its title, queued" do
    raid_database { assert_equal [[t(:zud_raid_title), false]], SpeakCapture.log }
  end

  test "the raid database opens on its title even before its search panel's window exists" do
    PokeAccess::ZudRaidDatabase.open(World.stub_scene(:@sprites => {}))
    assert_equal [[t(:zud_raid_title), false]], SpeakCapture.log
  ensure
    PokeAccess::ZudRaidDatabase.close
  end

  test "while the raid database's search panel is hidden, no row is read" do
    raid_database do |rd, win|
      win.visible = false
      SpeakCapture.clear
      rd.poll
      assert_nothing_spoken
    end
  end

  test "the raid database claims its search panel's window from the generic reader" do
    raid_database { |_rd, win| assert_equal true, PokeAccess.dedicated?(win) }
  end

  test "the raid database says its focused search row, the first one queued and each move interrupting" do
    raid_database(1) do |rd, win|
      SpeakCapture.clear
      rd.poll
      win.index = 2
      rd.poll
      assert_equal [["Raid Level", false], ["Type", true]], SpeakCapture.log
    end
  end

  test "each raid filter's value is said beside its row, by the height it is painted at" do
    raid_database do |rd, win|
      { 143 => "[5]", 175 => "[Eléctrico]", 207 => "[Bosque]", 239 => "[Kanto]" }.each do |y, value|
        paint(RAID_OVERLAY, value, y)
      end
      pbDrawTextPositions(RAID_OVERLAY, [nil, ["[9]", 16, 150, 0]])
      said = (0..4).map do |i|
        win.index = i
        SpeakCapture.clear
        rd.poll
        SpeakCapture.last
      end
      assert_equal ["Show Pokemon", "Raid Level: 5", "Type: Eléctrico", "Habitat: Bosque", "Region: Kanto"], said
    end
  end

  test "the raid database says a filter's new count, queued, then the row the cursor returns to after it" do
    raid_database(1) do |rd, win|
      rd.poll
      SpeakCapture.clear
      paint(RAID_OVERLAY, "Available Pokemon: 12", 340)
      win.index = 0
      rd.poll
      assert_equal [["Available Pokemon: 12", false], ["Show Pokemon", false]], SpeakCapture.log
    end
  end

  test "a raid count painted again unchanged is not said again" do
    raid_database do
      SpeakCapture.clear
      2.times { paint(RAID_OVERLAY, "Available Pokemon: 12", 340) }
      assert_equal [["Available Pokemon: 12", false]], SpeakCapture.log
    end
  end

  test "a raid count painted as a paragraph is said as well" do
    raid_database do
      SpeakCapture.clear
      drawTextEx(RAID_OVERLAY, 16, 340, 300, 1, "Available Pokemon: 7", nil, nil)
      assert_equal [["Available Pokemon: 7", false]], SpeakCapture.log
    end
  end

  test "blank text, or text painted on a bitmap of another screen, is nothing the raid database reads" do
    raid_database do
      SpeakCapture.clear
      paint(RAID_OVERLAY, " ", 340)
      paint(Object.new, "Available Pokemon: 12", 340)
      assert_nothing_spoken
    end
  end

  test "with the raid species grid up, the line under the panel is the species under the cursor" do
    raid_database do |rd|
      rd.selecting(true)
      SpeakCapture.clear
      paint(RAID_OVERLAY, "Pikachu", 340)
      assert_equal [["Pikachu", true]], SpeakCapture.log
    end
  end

  test "while the raid species grid is up, the search panel's row is not read" do
    raid_database do |rd, win|
      rd.selecting(true)
      win.index = 3
      SpeakCapture.clear
      rd.poll
      assert_nothing_spoken
    end
  end

  test "the raid grid says a new species with the page it is on from medium, and alone in brief" do
    raid_database do |rd|
      paint(RAID_PAGES, "Page: 2/3", 0)
      said = vb_levels do
        rd.selecting(true)
        SpeakCapture.clear
        paint(RAID_OVERLAY, "Raichu", 340)
        SpeakCapture.last
      end
      assert_equal ["Raichu", "Raichu. Page: 2/3", "Raichu. Page: 2/3"], said
    end
  end

  test "a raid grid page already said is left out with the next species, until the page changes" do
    raid_database do |rd|
      paint(RAID_PAGES, "Page: 2/3", 0)
      rd.selecting(true)
      SpeakCapture.clear
      paint(RAID_OVERLAY, "Raichu", 340)
      paint(RAID_OVERLAY, "Pichu", 340)
      paint(RAID_PAGES, "Page: 3/3", 0)
      paint(RAID_OVERLAY, "Pikachu", 340)
      assert_equal ["Raichu. Page: 2/3", "Pichu", "Pikachu. Page: 3/3"], SpeakCapture.lines
    end
  end

  test "a raid grid stamp with no page numbers is not a page" do
    raid_database do |rd|
      paint(RAID_PAGES, "Pokémon", 0)
      rd.selecting(true)
      SpeakCapture.clear
      paint(RAID_OVERLAY, "Raichu", 340)
      assert_equal ["Raichu"], SpeakCapture.lines
    end
  end

  test "the same raid species painted again is not said again" do
    raid_database do |rd|
      rd.selecting(true)
      SpeakCapture.clear
      2.times { paint(RAID_OVERLAY, "Raichu", 340) }
      assert_equal ["Raichu"], SpeakCapture.lines
    end
  end

  test "back on the raid grid from a species page, says the species under the cursor again" do
    raid_database do |rd|
      rd.selecting(true)
      paint(RAID_OVERLAY, "Pikachu", 340)
      SpeakCapture.clear
      rd.back_on_grid
      assert_equal [["Pikachu", true]], SpeakCapture.log
    end
  end

  test "back on the raid grid before any species, says nothing" do
    raid_database do |rd|
      rd.selecting(true)
      SpeakCapture.clear
      rd.back_on_grid
      assert_nothing_spoken
    end
  end

  test "back from the raid grid, the search panel says its row again" do
    raid_database do |rd|
      rd.poll
      rd.selecting(true)
      rd.selecting(false)
      SpeakCapture.clear
      rd.poll
      assert_equal [["Show Pokemon", false]], SpeakCapture.log
    end
  end

  test "closed, the raid database says no species going back to the grid" do
    raid_database do |rd|
      rd.selecting(true)
      paint(RAID_OVERLAY, "Pikachu", 340)
      rd.close
      SpeakCapture.clear
      rd.back_on_grid
      assert_nothing_spoken
    end
  end

  test "closed, the raid database reads nothing painted and no row" do
    raid_database do |rd|
      rd.close
      SpeakCapture.clear
      paint(RAID_OVERLAY, "Available Pokemon: 3", 340)
      drawTextEx(RAID_OVERLAY, 16, 340, 300, 1, "Available Pokemon: 4", nil, nil)
      rd.poll
      assert_nothing_spoken
    end
  end

  test "the raid database claims its filter list from the generic reader only while the list is hidden" do
    filter = Struct.new(:visible).new(false)
    raid_database(0, filter) do |rd|
      rd.poll
      hidden = PokeAccess.dedicated?(filter)
      filter.visible = true
      rd.poll
      assert_equal [true, false], [hidden, PokeAccess.dedicated?(filter)]
    end
  end

  test "a raid filter list that cannot tell whether it shows stays claimed" do
    filter = Object.new
    def filter.visible; raise RuntimeError, "disposed window"; end
    raid_database(0, filter) do |rd|
      rd.poll
      assert_equal true, PokeAccess.dedicated?(filter)
    end
  end

  test "reads a raid species page's data column, its labels paired with their values, then the four move lists" do
    assert_equal (["Pikachu", "#025", "Appears In: Raid Lv. 1", "Habitat: Forest"] + raid_lists).join(". "),
                 PokeAccess::ZudRaidDatabase.page_text(RAID_PAGE, nil)
  end

  test "a row painted with one coordinate alone is left out of a raid species page" do
    page = RAID_PAGE + [["Shiny", :positions, nil, 120], ["Gigantamax", :positions, 92, nil]]
    assert_equal (["Pikachu", "#025", "Appears In: Raid Lv. 1", "Habitat: Forest"] + raid_lists).join(". "),
                 PokeAccess::ZudRaidDatabase.page_text(page, nil)
  end

  test "a raid species page places the G-Max mark and the types where it draws them, the raid levels kept together" do
    page = RAID_PAGE + [["Raid Lv. 2", :positions, 389, 265]]
    pikachu = RaidSpecies.new(:PIKACHU, :PIKACHU, :ELECTRIC, :ELECTRIC, true)
    assert_equal (["Pikachu", "#025", t(:dmax_factor), t(:zud_raid_types, :list => "ELECTRIC"),
                   "Appears In: Raid Lv. 1", "Raid Lv. 2", "Habitat: Forest"] + raid_lists).join(". "),
                 PokeAccess::ZudRaidDatabase.page_text(page, pikachu)
  end

  test "a raid species whose data knows nothing of G-Max gets no mark" do
    plain = Struct.new(:species, :id, :type1, :type2).new(:PIDGEY, :PIDGEY, :NORMAL, :NORMAL)
    assert_equal (["Pikachu", "#025", t(:zud_raid_types, :list => "NORMAL"), "Appears In: Raid Lv. 1",
                   "Habitat: Forest"] + raid_lists).join(". "),
                 PokeAccess::ZudRaidDatabase.page_text(RAID_PAGE, plain)
  end

  test "a raid species with no G-Max form has no mark, and each of two types is said" do
    pidgey = RaidSpecies.new(:PIDGEY, :PIDGEY, :NORMAL, :FLYING, false)
    assert_equal (["Pikachu", "#025", t(:zud_raid_types, :list => "NORMAL, FLYING"), "Appears In: Raid Lv. 1",
                   "Habitat: Forest"] + raid_lists).join(". "),
                 PokeAccess::ZudRaidDatabase.page_text(RAID_PAGE, pidgey)
  end

  test "says which of the species' raid forms the page shows, where its arrows are, from medium" do
    alolan = RaidSpecies.new(:MEOWTH, :MEOWTH_1, :DARK, :DARK, false)
    said = with_raid_forms { vb_levels { PokeAccess::ZudRaidDatabase.page_text(MEOWTH_PAGE, alolan) } }
    form = t(:zud_raid_form, :n => 2, :tot => 3)
    assert_equal [meowth_page(nil), meowth_page(form), meowth_page(form)], said
  end

  test "says no form's place for a species with one raid form, or a form not among them" do
    { :PIKACHU => RaidSpecies.new(:PIKACHU, :PIKACHU, :DARK, :DARK, false),
      :MEOWTH_9 => RaidSpecies.new(:MEOWTH, :MEOWTH_9, :DARK, :DARK, false) }.each do |id, sp|
      assert_equal meowth_page(nil), with_raid_forms { PokeAccess::ZudRaidDatabase.page_text(MEOWTH_PAGE, sp) }, id.to_s
    end
  end

  test "says a raid species page as it paints, its move lists whole from the scene" do
    scene = World.stub_scene(:@datamoves1 => [:THUNDERBOLT, :QUICKATTACK], :@datamoves2 => [],
                             :@datamoves3 => [:DISCHARGE], :@datamoves4 => [:CHARM])
    PokeAccess::ZudRaidDatabase.species_page(scene, :PIKACHU) do
      pbDrawTextPositions(RAID_OVERLAY, [["Pikachu", 434, 10, 0], ["#025", 477, 46, 0], ["Thunderbolt", 92, 24, 0]])
    end
    assert_equal [[["Pikachu", "#025", t(:zud_raid_primary, :list => "THUNDERBOLT, QUICKATTACK"),
                    t(:zud_raid_secondary, :list => "None Found"), t(:zud_raid_spread, :list => "DISCHARGE"),
                    t(:zud_raid_support, :list => "CHARM")].join(". "), true]],
                 SpeakCapture.log
  end

  test "a raid species page from a scene without its move lists says the moves painted" do
    PokeAccess::ZudRaidDatabase.species_page(World.stub_scene, :PIKACHU) do
      pbDrawTextPositions(RAID_OVERLAY, [["Pikachu", 434, 10, 0], ["Thunderbolt", 92, 24, 0], ["Growl", 270, 24, 0],
                                         ["Discharge", 92, 212, 0], ["Charm", 270, 212, 0]])
    end
    assert_equal [[["Pikachu", t(:zud_raid_primary, :list => "Thunderbolt"), t(:zud_raid_secondary, :list => "Growl"),
                    t(:zud_raid_spread, :list => "Discharge"), t(:zud_raid_support, :list => "Charm")].join(". "),
                   true]],
                 SpeakCapture.log
  end

  test "a raid species page hands back what the game's paint returns" do
    assert_equal :painted, PokeAccess::ZudRaidDatabase.species_page(World.stub_scene, :PIKACHU) { :painted }
  end

  test "the game's raid database opens on its title, reads what it paints while it runs, and nothing once it returns" do
    raid_scene.pbRaidData { paint(RAID_OVERLAY, "Available Pokemon: 12", 340) }
    paint(RAID_OVERLAY, "Available Pokemon: 3", 340)
    assert_equal [[t(:zud_raid_title), false], ["Available Pokemon: 12", false]], SpeakCapture.log
  end

  test "the game's raid database closes even when it raises, the error left to the game" do
    scene = raid_scene
    assert_raises(RuntimeError) { scene.pbRaidData { raise RuntimeError, "disposed bitmap" } }
    SpeakCapture.clear
    paint(RAID_OVERLAY, "Available Pokemon: 3", 340)
    assert_nothing_spoken
  end

  test "while the game's species grid runs, the line under the panel is its species; back from it, the row" do
    scene = raid_scene
    scene.pbRaidData do
      PokeAccess::ZudRaidDatabase.poll
      scene.pbSpeciesSelect do
        paint(RAID_OVERLAY, "Pikachu", 340)
        PokeAccess::ZudRaidDatabase.poll
      end
      PokeAccess::ZudRaidDatabase.poll
    end
    assert_equal [[t(:zud_raid_title), false], ["Show Pokemon", false], ["Pikachu", true], ["Show Pokemon", false]],
                 SpeakCapture.log
  end

  test "a species page the game paints is said with the data of the species it is painted for" do
    pikachu = RaidSpecies.new(:PIKACHU, :PIKACHU, :ELECTRIC, :ELECTRIC, true)
    with_species(:PIKACHU => pikachu) { raid_scene.pbSetSpeciesData(:PIKACHU) { paint_page(RAID_PAGE) } }
    assert_equal [[(["Pikachu", "#025", t(:dmax_factor), t(:zud_raid_types, :list => "ELECTRIC"),
                     "Appears In: Raid Lv. 1", "Habitat: Forest"] + raid_lists).join(". "), true]],
                 SpeakCapture.log
  end

  test "a species page whose species data raises says nothing and hands the game its paint's return" do
    broken = RaidSpecies.new(:PIKACHU, :PIKACHU, :ELECTRIC, :ELECTRIC, true)
    broken.define_singleton_method(:type2) { raise RuntimeError, "corrupt species data" }
    painted = with_species(:PIKACHU => broken) { raid_scene.pbSetSpeciesData(:PIKACHU) { paint_page(RAID_PAGE) } }
    assert_equal :page_painted, painted
    assert_nothing_spoken
  end

  test "back on the game's species grid from a species page, the species under the cursor is said again" do
    scene = raid_scene
    scene.pbRaidData do
      scene.pbSpeciesSelect do
        paint(RAID_OVERLAY, "Pikachu", 340)
        scene.pbRaidDataBase(:PIKACHU)
      end
    end
    assert_equal [[t(:zud_raid_title), false], ["Pikachu", true], ["Pikachu", true]], SpeakCapture.log
  end

  test "the raid database's hooked methods hand back what the game's own return" do
    scene = raid_scene
    returns = { :pbRaidData => [[], :search_closed], :pbSpeciesSelect => [[], :grid_closed],
                :pbSetSpeciesData => [[:PIKACHU], :page_painted], :pbRaidDataBase => [[:PIKACHU], :page_closed] }
    returns.each { |meth, (args, ret)| assert_equal ret, scene.send(meth, *args), "RaidDataScene##{meth}" }
  end

  test "says the PC's fusion mode on and off as it toggles, once each" do
    scene = Object.new
    [true, true, false].each { |on| PokeAccess::IFStorageFusion.toggle(scene, on) }
    assert_equal [[t(:if_fuse_on), true], [t(:if_fuse_off), true]], SpeakCapture.log
  end

  test "switching off a fusion mode never on says nothing" do
    PokeAccess::IFStorageFusion.toggle(Object.new, false)
    assert_nothing_spoken
  end

  test "the PC takes a Pokemon past the game's dex count for a fusion, one at it or below not" do
    with_consts(:NB_POKEMON => 501) do
      with_function(:dexNum, lambda { |species| species }) do
        { 600 => true, 501 => false, 25 => false }.each do |species, fused|
          pokemon = Struct.new(:species).new(species)
          assert_equal fused, PokeAccess::IFStorageFusion.fused?(pokemon), "species #{species}"
        end
        assert_equal false, PokeAccess::IFStorageFusion.fused?(nil), "an empty slot"
      end
    end
  end

  test "the wardrobe names the clothes and the hat by the names their outfit data gives them" do
    with_outfit_data do
      with_globals(:$Trainer => Struct.new(:clothes, :hat, :hair).new("casual", "cap_red", nil)) do
        assert_equal ["Ropa informal", "Gorra roja"], [:clothes, :hat].map { |kind| PokeAccess::IFOutfits.item(kind) }
      end
    end
  end

  test "an outfit the data does not know is said by its id" do
    with_outfit_data do
      with_globals(:$Trainer => Struct.new(:clothes, :hat, :hair).new("casual", "cap_blue", nil)) do
        assert_equal "cap_blue", PokeAccess::IFOutfits.item(:hat)
      end
    end
  end

  test "says none for an outfit not worn" do
    with_outfit_data do
      with_globals(:$Trainer => Struct.new(:clothes, :hat, :hair).new(nil, "", nil)) do
        assert_equal [t(:if_outfit_none)] * 3, [:clothes, :hat, :hair].map { |kind| PokeAccess::IFOutfits.item(kind) }
      end
    end
  end

  test "a hat dye shift is the first hat's, or the second's when the call says so" do
    with_globals(:$Trainer => Struct.new(:hat_color, :hat2_color).new(10, 40)) do
      { nil => 10, false => 10, true => 40 }.each do |second, hue|
        assert_equal hue, PokeAccess::IFOutfits.hat_hue(second), "second hat: #{second.inspect}"
      end
    end
  end

  test "Opalo's badges page names the badges earned, each anthem's key and the way back" do
    assert_equal [t(:tcard_badge_list, :list => "Corriente, Ferro"), anthem_keys("Q", "E"), to_card].join(". "),
                 badges_page([true, false, true])
  end

  test "the badges page names a badge as the game's ceremony paints it, accent and all" do
    assert_equal [t(:tcard_badge_list, :list => "Évoca"), anthem_keys("T"), to_card].join(". "),
                 badges_page([false, false, false, false, true])
  end

  test "the badges page names the sixth badge's key by its letter's word, which a synthesizer reads as a word" do
    assert_equal [t(:tcard_badge_list, :list => "Descarga"), anthem_keys(t(:key_letter_y)), to_card].join(". "),
                 badges_page([false] * 5 + [true])
  end

  test "a rebound R or Y button carries its badge's anthem to the bound key, while a key of its own stays" do
    { :r => [[false, false, true, true], "Ferro, Presa", ["E", "K"]],
      :y => [[false] * 5 + [true], "Descarga", ["K"]] }.each do |button, (badges, names, keys)|
      PokeAccess::Config.rebinds = { button => 0x4B }
      assert_equal [t(:tcard_badge_list, :list => names), anthem_keys(*keys), to_card].join(". "), badges_page(badges),
                   "#{button} rebound"
    end
  end

  test "the badges page says the anthem keys and the way back from medium, as key hints are" do
    whole = [t(:tcard_badge_list, :list => "Corriente"), anthem_keys("Q"), to_card].join(". ")
    assert_equal [t(:tcard_badge_list, :list => "Corriente"), whole, whole], vb_levels { badges_page([true]) }
  end

  test "the badges page with no badge earned says none and the way back" do
    assert_equal [t(:tr_badges, :n => 0), to_card].join(". "), badges_page([])
  end

  test "in brief, the badges page with no badge earned says just that" do
    PokeAccess::Config.verbosity = :brief
    assert_equal t(:tr_badges, :n => 0), badges_page([])
  end

  test "the badges page counts the badges earned when the game has no table to name them by, or names fewer" do
    want = [t(:tr_badges, :n => 2), anthem_keys("Q", "W"), to_card].join(". ")
    { "no table" => nil, "one name" => ["Medalla Corriente"] }.each do |what, names|
      assert_equal want, badges_page([true, true], names), what
    end
  end

  test "the badges page says only the eight badges the card shows" do
    names = OPALO_BADGES.map { |n| n.sub("Medalla ", "") }.join(", ")
    keys = anthem_keys("Q", "W", "E", "R", "T", t(:key_letter_y), "U", "I")
    assert_equal [t(:tcard_badge_list, :list => names), keys, to_card].join(". "),
                 badges_page([true] * 9, OPALO_BADGES + ["Medalla Extra"])
  end

  test "Opalo's data page says the name, money, Pokedex, play time, stars, start date and the key to the badges" do
    text = with_function(:pbGetMonthName, lambda { |month| month == 5 ? "mayo" : "?" }) do
      with_frame_count(40 * 3725) { data_page(3, nil, Time.local(2026, 5, 3)) }
    end
    started = t(:tcard_started, :date => t(:tcard_date, :d => 3, :m => "mayo", :y => 2026))
    tail = [t(:tr_playtime, :h => 1, :m => 2), t(:tcard_stars, :n => 3), started, to_badges]
    assert_equal (card_head + tail).join(", "), text
  end

  test "the data page says the stars the card draws as their count alone, and none it does not draw" do
    { 0 => nil, 1 => 1, 4 => 4, 5 => nil }.each do |stars, drawn|
      want = (card_head + [drawn && t(:tcard_stars, :n => drawn), to_badges]).compact.join(", ")
      assert_equal want, data_page(stars), "#{stars} stars"
    end
  end

  test "in brief the data page leaves out the key to the badges" do
    PokeAccess::Config.verbosity = :brief
    assert_equal card_head.join(", "), data_page(0)
  end

  test "the data page leaves out what the trainer does not keep, the Pokedex unless both its counts are kept" do
    want = [t(:tc_title), t(:tc_name, :name => "Rojo"), to_badges].join(", ")
    { "the name alone" => Struct.new(:name).new("Rojo"),
      "no Pokemon seen" => Struct.new(:name, :pokedexOwned).new("Rojo", 1) }.each do |what, trainer|
      assert_equal want, data_page(0, trainer), what
    end
  end

  test "a trainer whose badges cannot be read has earned none" do
    with_globals(:$Trainer => Struct.new(:name).new("Rojo")) do
      assert_equal [t(:tr_badges, :n => 0), to_card].join(". "), PokeAccess::OpaloCard.badges_text
    end
  end

  test "with no trainer the card has neither page" do
    with_globals(:$Trainer => nil) do
      assert_nil PokeAccess::OpaloCard.main_text, "the data page"
      assert_nil PokeAccess::OpaloCard.badges_text, "the badges page"
    end
  end

  test "Armonia's DexNav names each species as its icon shows it: caught, seen or unknown, the state from medium" do
    caught = "Especie1, #{t(:dex_caught)}"
    seen = "Especie2, #{t(:dex_seen)}"
    { 1 => ["Especie1", caught, caught], 2 => ["Especie2", seen, seen], 3 => [t(:dex_unknown)] * 3 }.each do |sp, want|
      assert_equal want, with_dex { vb_levels { PokeAccess::ArmoniaDexNav.species_label(sp) } }, "species #{sp}"
    end
  end

  test "the DexNav names a zone as its picture paints it" do
    { "dexnavtierra" => "Tierra", "dexnavsurf" => t(:dxn_zone_surf), "dexnavrio" => t(:dxn_zone_fish),
      "dexnavcueva" => t(:dxn_zone) }.each do |picture, name|
      scene = World.stub_scene(:@visibleZones => [[0, picture]], :@index => 0, :@num_enc => 1, :@encounterArray => [])
      assert_equal t(:dxn_none, :zone => name), PokeAccess::ArmoniaDexNav.encounters(scene), picture
    end
  end

  test "two DexNav zones are enough for the zone's place to be said" do
    said = with_dex { PokeAccess::ArmoniaDexNav.encounters(dexnav_zone(1, [3], 2)) }
    assert_equal surf_list(t(:list_entry, :name => t(:dxn_zone_surf), :n => 2, :tot => 2), 1, t(:dex_unknown)), said
  end

  test "the DexNav says the zone's place among the zones the arrows move between, from medium" do
    said = with_dex { vb_levels { PokeAccess::ArmoniaDexNav.encounters(dexnav_zone(1, [3])) } }
    assert_equal [surf_list(t(:dxn_zone_surf), 1, t(:dex_unknown)), surf_list(surf_place, 1, t(:dex_unknown)),
                  surf_list(surf_place, 1, t(:dex_unknown))],
                 said
  end

  test "a DexNav zone in brief names its species without their state, which the info key keeps whole" do
    PokeAccess::Config.verbosity = :brief
    said = with_dex { PokeAccess::ArmoniaDexNav.encounters(dexnav_zone(1, [1, 2])) }
    assert_equal [surf_list(t(:dxn_zone_surf), 2, "Especie1, Especie2"),
                  surf_list(surf_place, 2, "Especie1, #{t(:dex_caught)}, Especie2, #{t(:dex_seen)}")],
                 [said, PokeAccess::Info.info_text]
  end

  test "the DexNav's encounter page says the keys its picture paints, from medium" do
    said = with_dex { vb_levels { PokeAccess::ArmoniaDexNav.page(dexnav_zone(1, [3])) } }
    keyed = "#{surf_list(surf_place, 1, t(:dex_unknown))}. #{t(:dxn_keys_species)}"
    assert_equal [surf_list(t(:dxn_zone_surf), 1, t(:dex_unknown)), keyed, keyed], said
  end

  test "the DexNav's rewards page says its rewards, the rule it paints in full, and its keys from medium" do
    scene = World.stub_scene(:@visibleZones => DEXNAV_ZONES, :@index => 0, :@num_enc => 3, :@showPageRewards => true,
                             :@mapid => 3)
    said = with_dexnav_tables { vb_levels { PokeAccess::ArmoniaDexNav.page(scene) } }
    body = rewards_line(1, "Tierra: #{potion_reward}, #{t(:dxn_claimed)}, #{t(:dxn_zone_fish)}: #{repel_reward}",
                        "Caramelo Raro")
    assert_equal [body, "#{body}. #{t(:dxn_keys_rewards)}", "#{body}. #{t(:dxn_rewards_rule)} #{t(:dxn_keys_rewards)}"],
                 said
  end

  test "the DexNav names each reward under its zone as the zone pages do, the claimed one marked" do
    text = with_dexnav_tables { PokeAccess::ArmoniaDexNav.rewards_text(World.stub_scene(:@mapid => 3)) }
    assert_equal rewards_line(1, "Tierra: #{potion_reward}, #{t(:dxn_claimed)}, #{t(:dxn_zone_fish)}: #{repel_reward}",
                              "Caramelo Raro"),
                 text
  end

  test "the DexNav's prize for completing the map, once claimed, is marked" do
    text = with_dexnav_tables(nil, { -1 => true }) do
      PokeAccess::ArmoniaDexNav.rewards_text(World.stub_scene(:@mapid => 3))
    end
    assert_equal rewards_line(0, "Tierra: #{potion_reward}, #{t(:dxn_zone_fish)}: #{repel_reward}",
                              "Caramelo Raro, #{t(:dxn_claimed)}"),
                 text
  end

  test "a DexNav reward in a zone the table does not list is said without a zone" do
    text = with_dexnav_tables({ 3 => [[7, :POTION, 3], :RARECANDY] }, {}) do
      PokeAccess::ArmoniaDexNav.rewards_text(World.stub_scene(:@mapid => 3))
    end
    assert_equal t(:dxn_rewards, :taken => 0, :tot => 1, :list => potion_reward, :final => "Caramelo Raro"), text
  end

  test "a player with no record of DexNav rewards has none claimed" do
    text = with_consts(:DEXNAV_ZONES => dexnav_table_zones, :DEXNAV_REWARDS => dexnav_table_rewards) do
      with_globals(:$PokemonGlobal => Object.new) do
        PokeAccess::ArmoniaDexNav.rewards_text(World.stub_scene(:@mapid => 3))
      end
    end
    assert_equal rewards_line(0, "Tierra: #{potion_reward}, #{t(:dxn_zone_fish)}: #{repel_reward}", "Caramelo Raro"),
                 text
  end

  test "a DexNav reward the table gives by number is named all the same" do
    text = with_dexnav_tables({ 3 => [[0, 25, 1], 50] }, {}) do
      PokeAccess::ArmoniaDexNav.rewards_text(World.stub_scene(:@mapid => 3))
    end
    repel = t(:dxn_reward_line, :item => "Repel", :n => 1)
    assert_equal t(:dxn_rewards, :taken => 0, :tot => 1, :list => "Tierra: #{repel}", :final => "Caramelo Raro"), text
  end

  test "a DexNav reward its id lookup leaves nameless, with a blank name or no answer, is named by the item itself" do
    potion = "Tierra: #{potion_reward}"
    { "a blank name" => lambda { |sym| [sym, ""] }, "no answer" => lambda { |_sym| nil } }.each do |what, answer|
      text = with_dexnav_tables({ 3 => [[0, :POTION, 3], :RARECANDY] }, {}) do
        with_item_ids(answer) { PokeAccess::ArmoniaDexNav.rewards_text(World.stub_scene(:@mapid => 3)) }
      end
      assert_equal t(:dxn_rewards, :taken => 0, :tot => 1, :list => potion, :final => "Caramelo Raro"), text, what
    end
  end

  test "a map with no DexNav rewards, or with the completion prize alone, says it has none" do
    with_dexnav_tables({ 4 => [:RARECANDY] }, {}) do
      [3, 4].each do |map|
        assert_equal t(:dxn_rewards_none), PokeAccess::ArmoniaDexNav.rewards_text(World.stub_scene(:@mapid => map)),
                     "map #{map}"
      end
    end
  end

  test "flipped to the DexNav's rewards page, the info key keeps that page with the rule it paints" do
    with_dexnav_tables { PokeAccess::ArmoniaDexNav.rewards(World.stub_scene(:@mapid => 3)) }
    body = rewards_line(1, "Tierra: #{potion_reward}, #{t(:dxn_claimed)}, #{t(:dxn_zone_fish)}: #{repel_reward}",
                        "Caramelo Raro")
    assert_equal "#{body}. #{t(:dxn_rewards_rule)}", PokeAccess::Info.info_text
  end

  test "the DexNav says each page it loads, interrupting" do
    nav = screen(DexNav, :@visibleZones => [[0, "dexnavtierra"]], :@index => 0, :@num_enc => 1, :@encounterArray => [])
    nav.loadCurrentPage
    assert_equal [["#{t(:dxn_none, :zone => 'Tierra')}. #{t(:dxn_keys_species)}", true]], SpeakCapture.log
  end

  test "opening the DexNav on a map with no encounter zones says so" do
    screen(DexNav, :@num_enc => 0).startUI
    assert_equal [[t(:dxn_no_zones), true]], SpeakCapture.log
  end

  test "opening the DexNav on a map with encounter zones adds nothing to it" do
    screen(DexNav, :@num_enc => 2).startUI
    assert_nothing_spoken
  end

  test "Reminiscencia's upgrade tree says the stat, its next cost, the coins as it opens, and the bonus from medium" do
    tree = screen(ScrollTree, :@selec => 0)
    rows = with_tree([[500, 10], [800, 5]], 600) { said_at_levels(tree, :rem_tree) { tree.positionSelector } }
    whole = tree_row(:rem_st_atk, 10, 500, coins(600))
    assert_equal [[t(:rem_st_atk), t(:rem_tree_cost, :cost => 500), coins(600)].join(", "), whole, whole], rows
  end

  test "the info key keeps the tree's whole row, its bonus included in brief" do
    PokeAccess::Config.verbosity = :brief
    with_tree([[500, 10]], 600) { screen(ScrollTree, :@selec => 0).positionSelector }
    assert_equal tree_row(:rem_st_atk, 10, 500, coins(600)), PokeAccess::Info.info_text
  end

  test "the tree's row leaves the info key as the tree closes" do
    tree = screen(ScrollTree, :@selec => 0)
    with_tree([[500, 10]], 600) { tree.positionSelector }
    tree.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "a move on the upgrade tree says no coins, and marks a price above them as the game's red cost does" do
    tree = screen(ScrollTree, :@selec => 0)
    with_tree([[500, 10], [800, 5]], 600) do
      tree.positionSelector
      tree.instance_variable_set(:@selec, 1)
      SpeakCapture.clear
      tree.positionSelector
    end
    assert_equal [[tree_row(:rem_st_spatk, 5, 800, t(:rem_tree_short)), true]], SpeakCapture.log
  end

  test "an upgrade price the coins just cover is not marked short" do
    with_tree([[600, 10]], 600) { screen(ScrollTree, :@selec => 0).positionSelector }
    assert_equal [[tree_row(:rem_st_atk, 10, 600, coins(600)), true]], SpeakCapture.log
  end

  test "an upgrade purchase says the stat again with the coins left" do
    tree = screen(ScrollTree, :@selec => 1)
    with_tree([[500, 10], [800, 5]], 600) do |bag|
      tree.positionSelector
      bag.instance_variable_set(:@coins, 100)
      $Trainer.buffStatFriend[1] = [900, 8]
      SpeakCapture.clear
      tree.raiseStat
    end
    assert_equal [[tree_row(:rem_st_spatk, 8, 900, t(:rem_tree_short), coins(100)), true]], SpeakCapture.log
  end

  test "each of the five stats is named in the tree's order, alone while it has no row" do
    said = with_tree([], 0) do
      (0..4).map do |i|
        screen(ScrollTree, :@selec => i).positionSelector
        SpeakCapture.last
      end
    end
    assert_equal [t(:rem_st_atk), t(:rem_st_spatk), t(:rem_st_def), t(:rem_st_spdef), t(:rem_st_speed)], said
  end

  test "an upgrade tree selection outside the five stats says nothing" do
    with_tree([[500, 10]], 600) do
      [5, -1, nil].each { |i| screen(ScrollTree, :@selec => i).positionSelector }
    end
    assert_nothing_spoken
  end

  test "the help list says an unlocked section by its name and place" do
    with_help(%w[controles pokemon]) do
      assert_equal [[t(:list_entry, :name => t(:rem_help_pokemon), :n => 2, :tot => 10), true]], help_line(1)
    end
  end

  test "a help section past the unlocked ones, painted as question marks, is said as unknown and locked" do
    with_help(%w[controles pokemon]) do
      unknown = "#{t(:rem_help_unknown)}, #{t(:rem_help_locked)}"
      assert_equal [[t(:list_entry, :name => unknown, :n => 3, :tot => 10), true]], help_line(2)
    end
  end

  test "a trainer with no record of the help sections unlocked has every section open and named" do
    with_globals(:$Trainer => Struct.new(:name).new("Rojo")) do
      assert_equal [[t(:list_entry, :name => t(:rem_help_catching), :n => 4, :tot => 10), true]], help_line(3)
    end
  end

  test "a help section painted by name whose tag is not unlocked is said locked" do
    with_help(%w[controles pokemon capturas]) do
      locked = "#{t(:rem_help_items)}, #{t(:rem_help_locked)}"
      assert_equal [[t(:list_entry, :name => locked, :n => 3, :tot => 10), true]], help_line(2)
    end
  end

  test "the help sections say the words their buttons paint" do
    with_help(%w[controles pokemon objetos capturas phione ubicaciones auxilio alarmado cartas]) do
      { 6 => ["Combates con refuerzos", 7], 8 => ["Cartas", 9] }.each do |i, (word, n)|
        assert_equal [[t(:list_entry, :name => word, :n => n, :tot => 10), true]], help_line(i), "section #{i}"
      end
    end
  end

  test "a help section's place counts the game's own number of help options" do
    said = with_function(:numeroOpcionesAyudas, lambda { 12 }) { with_help(%w[controles]) { help_line(0) } }
    assert_equal [[t(:list_entry, :name => t(:rem_help_controls), :n => 1, :tot => 12), true]], said
  end

  test "an index outside the help's ten sections says nothing" do
    with_help(%w[controles]) do
      [10, -1, nil].each { |i| PokeAccess::ReminExtras.help_section(World.stub_scene(:@index => i)) }
    end
    assert_nothing_spoken
  end

  test "while the help list's loop runs, its frames read the focused section, once" do
    with_help(%w[controles pokemon]) { screen(AyudasUI, :@index => 1).update }
    assert_equal [[t(:list_entry, :name => t(:rem_help_pokemon), :n => 2, :tot => 10), true]], SpeakCapture.log
  end

  test "once the help list's loop ends, the frames after it read nothing" do
    help = screen(AyudasUI, :@index => 1)
    with_help(%w[controles pokemon]) do
      help.update
      help.instance_variable_set(:@index, 0)
      SpeakCapture.clear
      Input.update
    end
    assert_nothing_spoken
  end

  test "back from a section opened from the help list, the list says its focus again" do
    help = help_section_shown("Pulsa Z para correr.")
    help.instance_variable_set(:@index, 1)
    help.instance_variable_set(:@opens, true)
    with_help(%w[controles pokemon]) { help.update }
    entry = t(:list_entry, :name => t(:rem_help_pokemon), :n => 2, :tot => 10)
    assert_equal [[entry, true], ["Pulsa Z para correr.", false], [entry, true]], SpeakCapture.log
  end

  test "a help section says the paragraph it paints on its own panel as it opens, queued" do
    help_section_shown("Pulsa Z para correr.").chosenOption
    assert_equal [["Pulsa Z para correr.", false]], SpeakCapture.log
  end

  test "a prompt drawn through the help's paragraph function elsewhere is not read" do
    with_panel("desc", HELP_PANEL) { drawTextEx(Object.new, 16, 16, 480, 1, "¿Nombre?") }
    assert_nothing_spoken
  end

  test "a blank help paragraph says nothing" do
    help_section_shown("  ").chosenOption
    assert_nothing_spoken
  end

  test "the world map's place never visited, painted as question marks, is said as a word" do
    world_map([["???", 324, 228, 2]]).drawInfo
    assert_equal [[t(:rem_map_unvisited), true]], SpeakCapture.log
  end

  test "a visited place on the world map is said by its name, the panel's rows in paint order, blank ones left out" do
    world_map([["Pueblo Brizo", 324, 228, 2], [" ", 324, 244, 2], "suelto", ["Ruta 3", 324, 260, 2]]).drawInfo
    assert_equal [["Pueblo Brizo. Ruta 3", true]], SpeakCapture.log
  end

  test "what is painted beside the world map's panel, or on no bitmap, is not read" do
    with_panel("info", MAP_PANEL) do
      [Object.new, nil].each { |bitmap| pbDrawTextPositions(bitmap, [["Pueblo Brizo", 324, 228, 2]]) }
    end
    assert_nothing_spoken
  end

  test "a world map panel painted with nothing but blanks says nothing" do
    world_map([[" ", 324, 228, 2], ["", 324, 260, 2]]).drawInfo
    assert_nothing_spoken
  end

  test "the same world map place painted again is not said again until the panel is drawn anew" do
    rows = [["Pueblo Brizo", 324, 228, 2]]
    map = world_map(rows)
    begin
      PokeAccess::ReminExtras.help_on(map)
      2.times { pbDrawTextPositions(MAP_PANEL, rows) }
    ensure
      PokeAccess::ReminExtras.help_off
    end
    map.drawInfo
    assert_equal [["Pueblo Brizo", true], ["Pueblo Brizo", true]], SpeakCapture.log
  end

  test "a help screen whose panels are already disposed reads nothing painted" do
    disposed = Object.new
    def disposed.bitmap; raise RuntimeError, "disposed sprite"; end
    PokeAccess::ReminExtras.help_on(World.stub_scene(:@sprites => { "desc" => disposed, "info" => disposed }))
    drawTextEx(HELP_PANEL, 16, 16, 480, 8, "Pulsa Z para correr.")
    pbDrawTextPositions(MAP_PANEL, [["Pueblo Brizo", 324, 228, 2]])
    assert_nothing_spoken
  ensure
    PokeAccess::ReminExtras.help_off
  end

  test "once a help section or the world map is drawn, what is painted after on their panels is not read" do
    help_section_shown("Pulsa Z para correr.").chosenOption
    world_map([["Pueblo Brizo", 324, 228, 2]]).drawInfo
    SpeakCapture.clear
    drawTextEx(HELP_PANEL, 16, 16, 480, 8, "Pulsa X para salir.")
    pbDrawTextPositions(MAP_PANEL, [["Ruta 3", 324, 228, 2]])
    assert_nothing_spoken
  end

  test "a blessing says what it does, its rarity from medium and its category in full" do
    rows = with_blessings do
      scene = chooser
      said_at_levels(scene, :bless) { scene.updateCursor }
    end
    assert_equal ["Sube el ataque.", "#{rarity(3)}. Sube el ataque.", blessing_card], rows
  end

  test "each blessing category is named as the game's own comments name it" do
    table = { :I => [0, 0, nil, "Efecto."], :P => [1, 0, nil, "Efecto."], :M => [2, 0, nil, "Efecto."],
              :H => [3, 0, nil, "Efecto."], :X => [4, 0, nil, "Efecto."] }
    said = with_blessings(table) do
      table.keys.map do |card|
        chooser([card]).updateCursor
        SpeakCapture.last
      end
    end
    assert_equal ["#{t(:rem_bless_item)}. #{rarity(1)}. Efecto.", "#{t(:rem_bless_power)}. #{rarity(1)}. Efecto.",
                  "#{t(:rem_bless_mechanic)}. #{rarity(1)}. Efecto.", "#{t(:rem_bless_heal)}. #{rarity(1)}. Efecto.",
                  "#{rarity(1)}. Efecto."],
                 said
  end

  test "the info key keeps the whole blessing card" do
    PokeAccess::Config.verbosity = :brief
    with_blessings { chooser.updateCursor }
    assert_equal blessing_card, PokeAccess::Info.info_text
  end

  test "the same blessing card read again says nothing" do
    with_blessings do
      scene = chooser
      2.times { scene.updateCursor }
    end
    assert_equal [[blessing_card, true]], SpeakCapture.log
  end

  test "a blessing with no rarity says none" do
    with_blessings(:N => [1, nil, nil, "Efecto."]) { chooser([:N]).updateCursor }
    assert_equal [["#{t(:rem_bless_power)}. Efecto.", true]], SpeakCapture.log
  end

  test "a card the blessing table does not know says nothing" do
    with_blessings { chooser([:ZZ]).updateCursor }
    assert_nothing_spoken
  end

  test "the blessing legend painted before the first card waits for it, then follows it, queued" do
    with_blessings do
      scene = chooser
      scene.drawMaintext
      scene.swapCard
    end
    assert_equal [[blessing_card, true], [legend, false]], SpeakCapture.log
  end

  test "a blessing legend repainted after the cards, as a re-roll does, is said at once, queued" do
    with_blessings do
      scene = chooser
      scene.swapCard
      SpeakCapture.clear
      scene.drawMaintext
    end
    assert_equal [[legend, false]], SpeakCapture.log
  end

  test "without key hints, the blessing legend says the coins alone" do
    PokeAccess::Config.verbosity = :brief
    with_blessings do
      scene = chooser
      scene.swapCard
      SpeakCapture.clear
      scene.drawMaintext
    end
    assert_equal [["Monedas: 12", false]], SpeakCapture.log
  end

  test "the starter selection says the starter under the cursor by name alone, at every level" do
    scene = selection
    assert_equal ["Bulbasaur"] * 3, said_at_levels(scene, :starter_sel) { scene.gettinginput }
  end

  test "the same starter is not said again until the cursor moves" do
    scene = selection
    2.times { scene.gettinginput }
    assert_equal [["Bulbasaur", true]], SpeakCapture.log
  end

  test "a ball with no starter behind it says nothing" do
    scene = selection
    scene.instance_variable_set(:@select, 2)
    scene.gettinginput
    assert_nothing_spoken
  end

  test "Ctrl+T has the starter's name alone while the screen hides its types" do
    selection.gettinginput
    assert_equal "Bulbasaur", PokeAccess::Info.row_text
  end

  test "choosing a starter says the types pressBall fades in, queued, then the confirm window's first option" do
    chosen_selection
    assert_equal [["Tipo12/Tipo3", false], ["Sí", false]], SpeakCapture.log
  end

  test "after choosing a starter, Ctrl+T has the name with the types" do
    chosen_selection
    assert_equal "Bulbasaur, Tipo12/Tipo3", PokeAccess::Info.row_text
  end

  test "in brief, choosing a starter leaves the types out but not the window" do
    PokeAccess::Config.verbosity = :brief
    chosen_selection
    assert_equal [["Sí", false]], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A window whose text is text.
  def window(text)
    Struct.new(:text).new(text)
  end

  # A sprite showing bitmap.
  def sprite(bitmap)
    Struct.new(:bitmap).new(bitmap)
  end

  # An instance of a game's screen class built without its constructor, which runs the whole screen, holding ivars.
  def screen(klass, ivars = {})
    scene = klass.allocate
    ivars.each { |name, value| scene.instance_variable_set(name, value) }
    scene
  end

  # What the block makes the reader say last at each verbosity level, [brief, medium, full], the cursor slot of
  # holder reset before each so that every level reads afresh.
  def said_at_levels(holder, slot)
    vb_levels do
      PokeAccess::Cursor.reset(holder, slot)
      SpeakCapture.clear
      yield
      SpeakCapture.last
    end
  end

  # Runs the block with Input.trigger? true for keys alone.
  def pressing(*keys)
    was = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |key| keys.include?(key) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, was)
  end

  # Runs the block with the given globals ({ :$Trainer => value }) set, each put back after.
  def with_globals(vars)
    saved = {}
    vars.each do |name, value|
      saved[name] = eval(name.to_s)
      eval("#{name} = value")
    end
    yield
  ensure
    saved.each { |name, value| eval("#{name} = value") }
  end

  # Runs the block with the constants of owner set to the given values (nil: absent), whatever was there put back.
  def with_consts(values, owner = Object)
    saved = {}
    values.each do |name, value|
      saved[name] = owner.const_defined?(name, false) ? [owner.const_get(name)] : nil
      owner.send(:remove_const, name) if saved[name]
      owner.const_set(name, value) unless value.nil?
    end
    yield
  ensure
    saved.each do |name, was|
      owner.send(:remove_const, name) if owner.const_defined?(name, false)
      owner.const_set(name, was[0]) if was
    end
  end

  # Runs the block with the game's top-level function name answering through impl, the one before put back.
  def with_function(name, impl)
    kept = :"pa_test_was_#{name}"
    had = Object.private_method_defined?(name) || Object.method_defined?(name)
    Object.send(:alias_method, kept, name) if had
    Object.send(:define_method, name, &impl)
    Object.send(:private, name)
    yield
  ensure
    if had
      Object.send(:alias_method, name, kept)
      Object.send(:remove_method, kept)
    else
      Object.send(:remove_method, name)
    end
  end

  # Runs the block with Graphics counting frames played.
  def with_frame_count(frames)
    meta = Graphics.singleton_class
    was = meta.method_defined?(:frame_count) ? Graphics.method(:frame_count) : nil
    Graphics.define_singleton_method(:frame_count) { frames }
    yield
  ensure
    was ? Graphics.define_singleton_method(:frame_count, was) : meta.send(:remove_method, :frame_count)
  end

  # Yields Realidea's vision tracking the named menu list from its first option, its tracking dropped after.
  def realidea(list)
    rs = PokeAccess::RealideaSystem
    rs.start(rs.const_get(list))
    yield rs
  ensure
    { :@active => nil, :@list => nil, :@sel => 1, :@last => nil, :@stack => [] }.each do |ivar, value|
      rs.instance_variable_set(ivar, value)
    end
  end

  # Lana's card: three stars shown, the dates of ranks 0 and 5 done, two notes and a blank one.
  def lana
    FatesCard.new("Lana", 17, "Reina", "5 de mayo", ["Guerrera", "Maga"], "Alba", "Leo", 30, 100, 3,
                  { 0 => true, 5 => true }, 0, ["Le gusta el té.", "", "Odia la lluvia."])
  end

  # Kai's card, whose character has no level bonus yet.
  def kai
    card = lana
    card.nombre = "Kai"
    card.index = 1
    card
  end

  # Lana's profile fields with stars lit.
  def lana_profile(stars)
    t(:awk_prof, :name => "Lana", :age => 17, :title => "Reina", :bday => "5 de mayo", :cls => "Guerrera, Maga",
      :loc => "Alba", :sign => "Leo", :exp => 30, :tot => 100, :stars => stars)
  end

  # A bonus level's row as painted.
  def bonus_row(level, title)
    t(:awk_bonus_row, :n => level, :title => title)
  end

  # Yields Awakening's card reader with the game's two tables and a trainer holding cards: FatesCartas unlocks the
  # dates of the ranks in unlocked and has those in done completed, PersonajesFates keeps BONUSES.
  def with_fates(cards, unlocked = [2], done = [])
    cartas = Module.new
    cartas.define_singleton_method(:j_citaDesbloqueada?) { |_id, rank| unlocked.include?(rank) }
    cartas.define_singleton_method(:j_citaCompletada?) { |_id, rank| done.include?(rank) }
    personajes = Module.new
    personajes.define_singleton_method(:resumen_niveles) { BONUSES }
    with_consts(:FatesCartas => cartas, :PersonajesFates => personajes) do
      with_globals(:$Trainer => Struct.new(:lista_cartas).new(cards)) { yield PokeAccess::AwakeningFatesExtra }
    end
  ensure
    PokeAccess::AwakeningFatesExtra.bonus_close
  end

  # The talisman screen listing SUN, focused, as unlocked or locked.
  def equip_scene(unlocked = true)
    scene = World.stub_scene(:@talismans => [SUN], :@selected_index => 0)
    scene.define_singleton_method(:unlocked?) { |_symbol| unlocked }
    scene
  end

  # SUN as the first of one, while positions are said.
  def sun_placed
    t(:list_entry, :name => "Talismán del Sol", :n => 1, :tot => 1)
  end

  # Runs the block with the game's TALISMAN_REQUIREMENTS asking SUN for ten wins, at progress per cent.
  def with_requirement(progress, &blk)
    requirement = { :description => "Gana 10 combates", :progress => lambda { progress } }
    with_consts(:TALISMAN_REQUIREMENTS => { :sol => requirement }, &blk)
  end

  # The locked line with_requirement's talisman says at progress per cent.
  def locked_body(progress)
    [t(:awk_talisman_locked), t(:awk_talisman_req, :req => "Gana 10 combates"),
     t(:awk_talisman_progress, :n => progress)]
  end

  # The lore window over nine wrapped lines, five of them shown, at the top.
  def lore_scene
    lines = (1..9).map { |i| "Linea #{i}." }
    bar = Struct.new(:bitmap).new(Struct.new(:width).new(300))
    scene = World.stub_scene(:@selected_index => 0, :@info_scroll => 0, :@info_window_height => 110,
                             :@sprites => { "info_window" => bar })
    scene.define_singleton_method(:selected_talisman) { { :lore => lines.join(" ") } }
    scene.define_singleton_method(:wrap_text) { |_bitmap, _text, _width| lines }
    scene
  end

  # Runs the block as the lore window opens.
  def opening_lore
    PokeAccess::AwakeningFates.lore_opening(true)
    yield
  ensure
    PokeAccess::AwakeningFates.lore_opening(false)
  end

  # Yields the raid database open on its search panel (on row index, with the filter list when given) and the
  # panel's window; closed after.
  def raid_database(index = 0, filter = nil)
    win = raid_panel(index)
    sprites = { "settings" => win }
    sprites["filter"] = filter if filter
    PokeAccess::ZudRaidDatabase.open(World.stub_scene(:@sprites => sprites, :@overlay => RAID_OVERLAY,
                                                      :@pagetext => RAID_PAGES))
    yield PokeAccess::ZudRaidDatabase, win
  ensure
    PokeAccess::ZudRaidDatabase.close
  end

  # The raid database's search panel window, on row index.
  def raid_panel(index = 0)
    Struct.new(:visible, :index, :commands).new(true, index, RAID_ROWS)
  end

  # The game's raid database, its search panel on the first row, painting on RAID_OVERLAY and RAID_PAGES.
  def raid_scene
    screen(RaidDataScene, :@sprites => { "settings" => raid_panel }, :@overlay => RAID_OVERLAY,
                          :@pagetext => RAID_PAGES)
  end

  # Paints text on bitmap at height y, as the raid database's screens do.
  def paint(bitmap, text, y)
    pbDrawTextPositions(bitmap, [[text, 16, y, 0]])
  end

  # Paints a species page's rows, given as RAID_PAGE holds them, on an overlay of the page's own.
  def paint_page(rows)
    pbDrawTextPositions(Object.new, rows.map { |text, _kind, x, y| [text, x, y, 0] })
  end

  # Runs the block with the game's species data knowing table's species ({ id => RaidSpecies }) and no other.
  def with_species(table, &blk)
    species = Module.new
    species.define_singleton_method(:get) { |id| table.fetch(id) }
    game_data = Module.new
    game_data.const_set(:Species, species)
    with_consts({ :GameData => game_data }, &blk)
  end

  # The four move lists RAID_PAGE paints, under their headings.
  def raid_lists
    [t(:zud_raid_primary, :list => "Thunderbolt, Quick Attack"), t(:zud_raid_secondary, :list => "None Found"),
     t(:zud_raid_spread, :list => "Discharge"), t(:zud_raid_support, :list => "Charm")]
  end

  # MEOWTH_PAGE as said with its Dark type, the form's place (or none) under its number, and its four lists, none
  # found.
  def meowth_page(form)
    lists = [:zud_raid_primary, :zud_raid_secondary, :zud_raid_spread, :zud_raid_support].map do |k|
      t(k, :list => "None Found")
    end
    (["Meowth", "#052", form, "Alolan Form", t(:zud_raid_types, :list => "DARK")].compact + lists).join(". ")
  end

  # Runs the block with the ZUD plugin's list of raid forms: Meowth's three, one for any other species.
  def with_raid_forms(&blk)
    forms = lambda { |base| base == :MEOWTH ? [:MEOWTH, :MEOWTH_1, :MEOWTH_2] : [base] }
    with_function(:pbGetAvailableRaidForms, forms, &blk)
  end

  # Runs the block with the game's outfit data: a red cap and casual clothes.
  def with_outfit_data(&blk)
    named = Struct.new(:name)
    with_function(:get_hat_by_id, lambda { |id| id == "cap_red" ? named.new("Gorra roja") : nil }) do
      with_function(:get_clothes_by_id, lambda { |id| id == "casual" ? named.new("Ropa informal") : nil }, &blk)
    end
  end

  # Opalo's badges page for a trainer holding badges, the game naming them by names (nil: no such table).
  def badges_page(badges, names = OPALO_BADGES)
    with_consts(:FANCY_BADGE_NAMES => names) do
      with_globals(:$Trainer => Struct.new(:badges).new(badges)) { PokeAccess::OpaloCard.badges_text }
    end
  end

  # The anthem keys line for the keys named.
  def anthem_keys(*keys)
    t(:tcard_anthem_keys, :keys => keys.map { |k| t(:key_other, :n => k) }.join(", "))
  end

  # The data page's head for data_page's default trainer: the title, the name, the money and the Pokedex.
  def card_head
    [t(:tc_title), t(:tc_name, :name => "Rojo"), t(:tc_money, :n => 100), t(:tc_pokedex, :owned => 1, :seen => 2)]
  end

  # The way from the data page to the badges.
  def to_badges
    t(:tcard_to_badges, :key => "C")
  end

  # The way back from the badges page to the card.
  def to_card
    t(:tcard_to_main, :key => "C")
  end

  # Opalo's data page for trainer (Rojo, 100 coins, 1 caught of 2 seen by default) with stars in the card's variable,
  # the game's global record holding the day the game started when given.
  def data_page(stars, trainer = nil, started = nil)
    trainer ||= Struct.new(:name, :money, :pokedexOwned, :pokedexSeen).new("Rojo", 100, 1, 2)
    $game_variables[250] = stars
    global = Object.new
    global.define_singleton_method(:startTime) { started } if started
    with_globals(:$Trainer => trainer, :$PokemonGlobal => global) { PokeAccess::OpaloCard.main_text }
  end

  # Runs the block with a player whose Pokedex has species 1 caught, 2 only seen and 3 never seen.
  def with_dex(&blk)
    player = Struct.new(:seen, :owned).new([false, true, true, false], [false, true, false, false])
    with_globals(:$player => nil, :$Trainer => player, &blk)
  end

  # The DexNav on zone index of DEXNAV_ZONES, count of them shown, listing the species encountered.
  def dexnav_zone(index, encounters, count = 3)
    World.stub_scene(:@visibleZones => DEXNAV_ZONES, :@index => index, :@num_enc => count,
                     :@encounterArray => encounters)
  end

  # The surf zone's encounter line under the zone's name as said, for n species named names.
  def surf_list(zone, n, names)
    t(:dxn_list, :zone => zone, :n => n, :names => names)
  end

  # The surf zone as the second of the three, from medium.
  def surf_place
    t(:list_entry, :name => t(:dxn_zone_surf), :n => 2, :tot => 3)
  end

  # Armonia's DEXNAV_ZONES: the land, surf and fishing zones by their EncounterTypes values.
  def dexnav_table_zones
    [[0, "dexnavtierra", "BaseTierra"], [2, "dexnavsurf", "BaseSurf"], [5, "dexnavrio", "BasePesca"]]
  end

  # Armonia's DEXNAV_REWARDS for map 3: three potions on land, two repels fishing, a rare candy for completing it.
  def dexnav_table_rewards
    { 3 => [[0, :POTION, 3], [5, :REPEL, 2], :RARECANDY] }
  end

  # Runs the block with the DexNav's tables (rewards, the default map 3's when nil) and the player's record of the
  # rewards claimed.
  def with_dexnav_tables(rewards = nil, claimed = { 0 => true }, &blk)
    global = Object.new
    global.define_singleton_method(:getDexNavRewards) { |_map| claimed }
    with_consts(:DEXNAV_ZONES => dexnav_table_zones, :DEXNAV_REWARDS => rewards || dexnav_table_rewards) do
      with_globals(:$PokemonGlobal => global, &blk)
    end
  end

  # Runs the block with an item table whose id lookup answers what answer gives for the item (a blank name, as a gen-6
  # message table without the item's entry does, or nothing), and that names the item when asked by the item itself.
  def with_item_ids(answer, &blk)
    table = Object.new
    table.define_singleton_method(:item_id) { |sym| answer.call(sym) }
    table.define_singleton_method(:item_name) { |item| { :POTION => "Pocion", :RARECANDY => "Caramelo Raro" }[item] }
    Harness.with_provider(table, &blk)
  end

  # The land reward and the fishing one as the rewards page lists them.
  def potion_reward
    t(:dxn_reward_line, :item => "Pocion", :n => 3)
  end

  def repel_reward
    t(:dxn_reward_line, :item => "Repel", :n => 2)
  end

  # The rewards page with taken of the two zone rewards claimed.
  def rewards_line(taken, list, final)
    t(:dxn_rewards, :taken => taken, :tot => 2, :list => list, :final => final)
  end

  # Yields the coin bag with the friend's upgrade rows (buffStatFriend: [cost, percent] per stat) and coins in it.
  def with_tree(rows, coins)
    bag = Object.new
    bag.instance_variable_set(:@coins, coins)
    def bag.pbQuantity(item); item == :COIN ? @coins : 0; end
    with_globals(:$Trainer => Struct.new(:buffStatFriend).new(rows), :$PokemonBag => bag) { yield bag }
  end

  # An upgrade tree row as full says it: the stat, its bonus, its next cost, then tail.
  def tree_row(stat, pct, cost, *tail)
    ([t(stat), t(:rem_tree_bonus, :pct => pct), t(:rem_tree_cost, :cost => cost)] + tail).join(", ")
  end

  def coins(n)
    t(:rem_coins, :n => n)
  end

  # Runs the block with the help sections whose tags are unlocked (ayudasUI).
  def with_help(tags, &blk)
    with_globals(:$Trainer => Struct.new(:ayudasUI).new(tags), &blk)
  end

  # What the help list says of the section at index, alone.
  def help_line(index)
    SpeakCapture.clear
    PokeAccess::ReminExtras.help_section(World.stub_scene(:@index => index))
    SpeakCapture.log
  end

  # Yields a held help screen whose sprite name paints on bitmap; let go after.
  def with_panel(name, bitmap)
    scene = World.stub_scene(:@sprites => { name => sprite(bitmap) })
    PokeAccess::ReminExtras.help_on(scene)
    yield scene
  ensure
    PokeAccess::ReminExtras.help_off
  end

  # The help screen on a section whose paragraph, text, it paints on its "desc" panel.
  def help_section_shown(text)
    screen(AyudasUI, :@sprites => { "desc" => sprite(HELP_PANEL) }, :@paragraph => text)
  end

  # The world map on a place whose "info" panel it paints with rows.
  def world_map(rows)
    screen(OpenWorldMap, :@sprites => { "info" => sprite(MAP_PANEL) }, :@rows => rows)
  end

  # Runs the block with BLESSINGS_HASH holding table.
  def with_blessings(table = BLESSINGS, &blk)
    with_consts(:BLESSINGS_HASH => table, &blk)
  end

  # The blessing chooser dealing cards, on the first.
  def chooser(cards = [:B1])
    scene = PickBlessing.new
    scene.instance_variable_set(:@blessings, cards)
    scene.instance_variable_set(:@index, 0)
    scene
  end

  def rarity(n)
    t(:bless_rarity, :n => n)
  end

  # BLESSINGS' card as full says it.
  def blessing_card
    "#{t(:rem_bless_power)}. #{rarity(3)}. Sube el ataque."
  end

  # The chooser's legend: the coins, then each action beside its key, top to bottom.
  def legend
    keys = [["A", "Ver porcentajes"], ["Z", "Resetear cartas"], ["C", "Escoger bendición"]].map do |key, action|
      t(:rem_key_action, :key => key, :action => action)
    end
    (["Monedas: 12"] + keys).join(". ")
  end

  # A starter with two types, as the gen-6 data reads them off the Pokemon.
  def starter
    pk = Poke.build(:name => "Bulbasaur", :species => 1)
    pk.define_singleton_method(:type1) { 12 }
    pk.define_singleton_method(:type2) { 3 }
    pk
  end

  # The selection screen on its first ball, which holds pk.
  def selection(pk = starter)
    scene = PokemonStarterSelection.new
    scene.instance_variable_set(:@data, { "pkmn_1" => pk })
    scene.instance_variable_set(:@select, 1)
    scene
  end

  # The selection screen after C on its first ball: the cursor settled on it, then pressBall run for it.
  def chosen_selection
    pk = starter
    scene = selection(pk)
    scene.instance_variable_set(:@pokemon, pk)
    scene.gettinginput
    scene.chooses = true
    SpeakCapture.clear
    scene.gettinginput
    scene
  end
end
