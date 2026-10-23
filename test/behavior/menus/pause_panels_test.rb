# The panels pause menus paint beside their options (PausePanel: said after the focused option, then only what changed)
# and the menu readers of the profiles that feed it, each profile's module evaluated without its hooks.

# Two subscreens a pause menu opens bare, each showing one dialogue: one the menu comes back from, one it always
# closes after. Every outermost return is counted.
class PausePanelSubscreens
  class << self
    attr_accessor :returns
  end
  self.returns = 0

  def back; dialogue; end
  def closing; dialogue; end

  private

  def dialogue
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.leave!
  end
end

PokeAccess::MenuReturn.bare("PausePanelSubscreens", :back)
PokeAccess::MenuReturn.bare("PausePanelSubscreens", :closing, :closes => true)
PokeAccess::MenuReturn.on_return { PausePanelSubscreens.returns += 1 }

class PausePanelsTest < PokeAccessTest
  # A text sprite as the menus hold one: Awakening reads its vtxt, Realidea and Reminiscencia its text.
  TextSprite = Struct.new(:text) do
    def vtxt; text; end
  end
  # A sprite as the readers check it: shown or not, with a picture or blank.
  Sprite = Struct.new(:visible, :bitmap)
  # A picture strip's frame, by its source rectangle.
  Strip = Struct.new(:src_rect)
  SrcRect = Struct.new(:x, :y)

  # The profile modules this file reads, as [game, file, module].
  PROFILES = [["relict", "pausemenu.rb", :RelictMenu], ["armonia", "pause_menu.rb", :ArmoniaPanel],
              ["awakening", "pausemenu.rb", :AwakeningPause], ["royal", "menu_parrilla.rb", :RoyalGridMenu],
              ["reminiscencia", "menus.rb", :ReminMenu], ["reminiscencia", "bag.rb", :ReminBag],
              ["realidea", "pause_overlay.rb", :ReaPauseOverlay]].freeze

  # The state the menus keep between openings, which each test gets back as it found it: module => ivars.
  KEPT = { :PausePanel => [:@last], :MenuReturn => [:@depth], :SpriteButtonMenu => [:@depth, :@last],
           :DPMenu => [:@menu], :PaintCapture => [:@tag, :@rows], :RelictMenu => [:@scene],
           :AwakeningPause => [:@depth, :@last, :@menu], :RoyalGridMenu => [:@open, :@last, :@menu],
           :ReminMenu => [:@stack], :ReminBag => [:@scene, :@last] }.freeze

  # Awakening's top bar as painted: counters, map, name and money.
  FATES_BAR = ["Cap:   3   Clases:  2", "Pueblo Alba", "Lana", "$ 1500"].freeze

  # Royal's grid entries, [icon, label, method], and the texts its background paints (clock, money).
  GRID_ITEMS = [["pokeball", "Equipo", "openParty"], ["bag", "Mochila", "openBag"]].freeze
  GRID_TEXTS = ["10:42", "1.500$"].freeze

  # Reminiscencia's objectives window as the dating sim writes it, its tasks coloured by state.
  OBJECTIVES = "<ac><c3=FAFAFA,7E5F5F>Objetivos:\n<c3=008000,B89880>Regar las flores\n" \
               "<c3=d00606,B89880>Pescar</ac>".freeze

  # The names Reminiscencia's getIslaName gives the maps the world map asks it about.
  ISLAND_NAMES = { 8 => "Isla Brizo", 67 => "Isla Pontos", 69 => "Isla Glauco", 82 => "Isla Talasa" }.freeze

  def setup
    super
    PROFILES.each { |game, file, name| load_profile(game, file, name) }
    @kept = kept_state
    PokeAccess::PausePanel.instance_variable_set(:@last, [])
    PokeAccess::MenuReturn.reset_nesting
  end

  def teardown
    @kept.each { |mod, ivar, value| mod.instance_variable_set(ivar, value) }
    super
  end

  test "a first opening says every line of the panel as one queued run of sentences" do
    PokeAccess::PausePanel.say(["Nivel máx. actual: 20", "Vidas: 3"])
    assert_equal [["Nivel máx. actual: 20. Vidas: 3", false]], SpeakCapture.log
  end

  test "an opening with the panel unchanged says nothing" do
    PokeAccess::PausePanel.say(["Nivel máx. actual: 20", "Vidas: 3"])
    SpeakCapture.clear
    PokeAccess::PausePanel.say(["Nivel máx. actual: 20", "Vidas: 3"])
    assert_nothing_spoken
  end

  test "an opening says only the lines that changed since the one before" do
    PokeAccess::PausePanel.say(["Nivel máx. actual: 20", "Vidas: 3"])
    SpeakCapture.clear
    PokeAccess::PausePanel.say(["Nivel máx. actual: 20", "Vidas: 2"])
    assert_equal [["Vidas: 2", false]], SpeakCapture.log
  end

  test "a line back from two openings ago is said again" do
    PokeAccess::PausePanel.say(["Dinero: 900", "Vidas: 3"])
    PokeAccess::PausePanel.say(["Dinero: 900", "Vidas: 2"])
    SpeakCapture.clear
    PokeAccess::PausePanel.say(["Dinero: 900", "Vidas: 3"])
    assert_equal [["Vidas: 3", false]], SpeakCapture.log
  end

  test "an empty panel says nothing" do
    [nil, "", [], ["", "   "], ["\\c[2]"]].each do |panel|
      PokeAccess::PausePanel.say(panel)
      assert_nothing_spoken "for #{panel.inspect}"
    end
  end

  test "a single string is a panel of one line" do
    PokeAccess::PausePanel.say("Dinero: 900")
    assert_equal [["Dinero: 900", false]], SpeakCapture.log
  end

  test "each line is said with the game's text codes cleaned out" do
    PokeAccess::PausePanel.say(["<c3=FAFAFA,7E5F5F>Dinero: 900</c3>", "Medallas:\n2"])
    assert_equal [["Dinero: 900. Medallas: 2", false]], SpeakCapture.log
  end

  test "while key hints are left out, so are the panel's shortcut-key lines" do
    PokeAccess::Config.verbosity = :brief
    PokeAccess::PausePanel.say(["Dinero: 900", "[A] Curar", "Pulsa Q para viajar"])
    assert_equal [["Dinero: 900", false]], SpeakCapture.log
  end

  test "a shortcut-key line names the key the player moved its button to" do
    PokeAccess::Config.rebinds = { :x => 0x4B }
    PokeAccess::PausePanel.say(["[A] Curar"])
    assert_equal [["[K] Curar", false]], SpeakCapture.log
  end

  test "under Pokemon Z's in-place Array#-, an unchanged panel is still said once" do
    with_in_place_array_minus do
      3.times { PokeAccess::PausePanel.say(["Dinero: 100", "Medallas: 2"]) }
    end
    assert_equal [["Dinero: 100. Medallas: 2", false]], SpeakCapture.log
  end

  test "a capture's panel lines leave out the menu's own option labels" do
    pairs = [["Pokédex", :positions, 40, 20], ["Nivel máx.", :positions, 300, 100], ["20", :positions, 400, 100],
             ["Mochila", :positions, 40, 60]]
    assert_equal ["Nivel máx. 20"], PokeAccess::PausePanel.lines(pairs, ["Pokédex", "Mochila"])
  end

  test "a panel row painted at an option's height is not glued to the option's label" do
    pairs = [["Pokédex", :positions, 68, 20], ["[A] Curar", :positions, 300, 20], ["Guardar", :positions, 68, 260],
             ["Nivel Máx.: 30", :positions, 300, 260]]
    assert_equal ["[A] Curar", "Nivel Máx.: 30"], PokeAccess::PausePanel.lines(pairs, ["Pokédex", "Guardar"])
  end

  test "an option label is known by its cleaned text, given as a list or alone; with none, the row stays whole" do
    pairs = [["\\c[1]Pokédex", :positions, 40, 20], ["Vidas: 3", :positions, 300, 20]]
    { [["Pokédex"]] => ["Vidas: 3"], ["Pokédex"] => ["Vidas: 3"], [] => ["Pokédex Vidas: 3"] }.each do |labels, lines|
      assert_equal lines, PokeAccess::PausePanel.lines(pairs, *labels), "labels #{labels.inspect}"
    end
  end

  test "Marin's DP menu says the focused entry, then its painted panel queued" do
    paint_dp_panel([["Pokédex", 40, 20], ["Nivel máx. actual: 20", 300, 100], ["Vidas: 3", 300, 130],
                    ["Mochila", 40, 60]])
    PokeAccess::DPMenu.read(dp_menu(0))
    assert_equal [["Pokédex", true], ["Nivel máx. actual: 20. Vidas: 3", false]], SpeakCapture.log
  end

  test "the DP menu says nothing more while its cursor stays, and the next entry alone once it moves" do
    menu = dp_menu(0)
    paint_dp_panel([["Vidas: 3", 300, 130]])
    PokeAccess::DPMenu.read(menu)
    SpeakCapture.clear
    PokeAccess::DPMenu.read(menu)
    assert_nothing_spoken "the cursor unmoved"
    menu.instance_variable_set(:@option, 1)
    PokeAccess::DPMenu.read(menu)
    assert_equal [["Mochila", true]], SpeakCapture.log
  end

  test "the DP menu's panel waits for the menu to have painted it" do
    menu = dp_menu(0)
    PokeAccess::PaintCapture.arm(:dp_panel)
    PokeAccess::DPMenu.read(menu)
    PokeAccess::PaintCapture.note_positions([["Vidas: 3", 300, 130]])
    menu.instance_variable_set(:@option, 1)
    PokeAccess::DPMenu.read(menu)
    assert_equal [["Pokédex", true], ["Mochila", true], ["Vidas: 3", false]], SpeakCapture.log
  end

  test "a DP menu entry naming the player also names the trainer card" do
    PokeAccess::DPMenu.read(World.stub_scene(:@options => [[$Trainer.name]], :@option => 0))
    assert_equal [["#{$Trainer.name}, #{t(:tc_title)}", true]], SpeakCapture.log
  end

  test "the DP menu puts the trainer on the info key" do
    PokeAccess::Info.set_info(:pokemon, Poke.build)
    PokeAccess::DPMenu.read(dp_menu(0))
    assert_equal trainer_line, PokeAccess::Info.info_text
  end

  test "a DP menu with no entries, or its cursor past them, says nothing, not even its painted panel" do
    { "no entries" => World.stub_scene(:@option => 0), "the cursor past them" => dp_menu(5) }.each do |what, menu|
      paint_dp_panel([["Vidas: 3", 300, 130]])
      PokeAccess::DPMenu.read(menu)
      assert_nothing_spoken what
    end
  end

  test "back from a submenu, the DP menu says its focused entry again, and not once it has closed" do
    menu = dp_menu(0)
    PokeAccess::DPMenu.watch(menu)
    PokeAccess::DPMenu.read(menu)
    PokeAccess::DPMenu.returned
    PokeAccess::DPMenu.read(menu)
    PokeAccess::DPMenu.unwatch
    PokeAccess::DPMenu.returned
    PokeAccess::DPMenu.read(menu)
    assert_equal [["Pokédex", true], ["Pokédex", true]], SpeakCapture.log
  end

  test "Relict's corner plate says the tower floor and the level cap its digits draw" do
    with_relict_plate(0, 25) { PokeAccess::RelictMenu.panel }
    assert_equal [["#{t(:rel_panel_floor, :n => 0)}. #{t(:rel_panel_cap, :n => 25)}", false]], SpeakCapture.log
  end

  test "a floor climbed is the one line Relict's plate says at the next opening" do
    with_relict_plate(0, 25) { PokeAccess::RelictMenu.panel }
    SpeakCapture.clear
    with_relict_plate(12, 25) { PokeAccess::RelictMenu.panel }
    assert_equal [[t(:rel_panel_floor, :n => 12), false]], SpeakCapture.log
  end

  test "Relict's plate says nothing with no floor or no level cap to draw" do
    [[nil, 25], [3, nil], [3, :absent]].each do |floor, cap|
      with_relict_plate(floor, cap) { PokeAccess::RelictMenu.panel }
      assert_nothing_spoken "floor #{floor.inspect}, cap #{cap.inspect}"
    end
  end

  test "Relict's ring says the focused button by the word its picture carries" do
    words = [:rel_radial_party, :rel_radial_bag, :rel_radial_encounters, :rel_radial_save, :rel_radial_options,
             :rel_radial_exit]
    words.each_with_index do |word, i|
      PokeAccess::RelictMenu.announce(World.stub_scene(:@index => i))
      assert_equal [[t(word), true]], SpeakCapture.log, "button #{i}"
      SpeakCapture.clear
    end
  end

  test "Relict's ring says a button once while it stays focused" do
    ring = World.stub_scene(:@index => 2)
    PokeAccess::RelictMenu.announce(ring)
    SpeakCapture.clear
    PokeAccess::RelictMenu.announce(ring)
    assert_nothing_spoken
  end

  test "Relict's ring says nothing with no button focused, or one past its six" do
    [nil, -1, 6].each do |index|
      PokeAccess::RelictMenu.announce(World.stub_scene(:@index => index))
      assert_nothing_spoken "index #{index.inspect}"
    end
  end

  test "back from a subscreen, Relict's ring says its focused button again, and not once it has closed" do
    ring = World.stub_scene(:@index => 1)
    PokeAccess::RelictMenu.watch(ring)
    PokeAccess::RelictMenu.poll
    PokeAccess::RelictMenu.poll
    PokeAccess::RelictMenu.returned
    PokeAccess::RelictMenu.poll
    PokeAccess::RelictMenu.unwatch
    PokeAccess::RelictMenu.returned
    PokeAccess::RelictMenu.poll
    assert_equal [[t(:rel_radial_bag), true], [t(:rel_radial_bag), true]], SpeakCapture.log
  end

  test "Armonia's panel says each member, the trainer lines painted at its edge but the clock, and the DexNav key" do
    with_party([Poke.build(:name => "Pikachu"), Poke.build(:name => "Bulbasaur", :hp => 0)]) do
      scene = armonia_menu(shown)
      paint_armonia_panel(scene, [["Lvl. 5", 65, 15], ["Lvl. 7", 65, 63], ["Medallas: 2", 3, 302],
                                  ["Juego: 01:05", 3, 329], ["Dinero: $900", 19, 356], ["Pokémon", 50, 58],
                                  ["Ajustes", 20, 380], ["\\c[1]", 3, 400]])
      PokeAccess::ArmoniaPanel.opened(scene)
    end
    said = ["Pikachu, #{t(:arm_level, :n => 25)}, #{t(:bt_hp_pct, :n => 100)}",
            "Bulbasaur, #{t(:arm_level, :n => 25)}, #{t(:pk_fainted)}", "Medallas: 2", "Dinero: $900",
            t(:arm_dexnav_key)]
    assert_equal [[said.join(". "), false]], SpeakCapture.log
  end

  test "Armonia's panel is said once per opening, however many buttons are focused, though a member's HP changes" do
    pikachu = Poke.build(:name => "Pikachu")
    with_party([pikachu]) do
      scene = armonia_menu(nil)
      paint_armonia_panel(scene, [["Medallas: 2", 3, 302]])
      PokeAccess::ArmoniaPanel.opened(scene)
      pikachu.hp = 20
      SpeakCapture.clear
      PokeAccess::ArmoniaPanel.opened(scene)
    end
    assert_nothing_spoken
  end

  test "Armonia's next opening says only the trainer lines that changed" do
    first = armonia_menu(nil)
    paint_armonia_panel(first, [["Medallas: 2", 3, 302], ["Dinero: $900", 3, 356]])
    PokeAccess::ArmoniaPanel.opened(first)
    SpeakCapture.clear
    second = armonia_menu(nil)
    paint_armonia_panel(second, [["Medallas: 2", 3, 302], ["Dinero: $1200", 3, 356]])
    PokeAccess::ArmoniaPanel.opened(second)
    assert_equal [["Dinero: $1200", false]], SpeakCapture.log
  end

  test "without a party to read, Armonia's panel is the trainer lines alone" do
    scene = armonia_menu(nil)
    paint_armonia_panel(scene, [["Medallas: 2", 3, 302]])
    assert_equal ["Medallas: 2"], PokeAccess::ArmoniaPanel.lines(scene)
  end

  test "an Armonia member's HP is its share of the bar, never nought while any is left" do
    { [40, 40] => 100, [100, 200] => 50, [199, 200] => 99, [1, 200] => 1, [1, 1] => 100,
      [5, 0] => nil }.each do |(hp, tot), pct|
      parts = ["Pikachu", t(:arm_level, :n => 25)]
      parts.push(t(:bt_hp_pct, :n => pct)) if pct
      pk = Poke.build(:name => "Pikachu", :hp => hp, :totalhp => tot)
      assert_equal parts.join(", "), PokeAccess::ArmoniaPanel.member(pk), "#{hp} of #{tot}"
    end
  end

  test "an Armonia member's status follows its HP, and a fainted one is said fainted instead" do
    sick = Poke.build(:name => "Pikachu", :status => 2)
    fainted = Poke.build(:name => "Bulbasaur", :hp => 0, :status => 2)
    level = t(:arm_level, :n => 25)
    assert_equal "Pikachu, #{level}, #{t(:bt_hp_pct, :n => 100)}, #{t(:st_poison)}",
                 PokeAccess::ArmoniaPanel.member(sick)
    assert_equal "Bulbasaur, #{level}, #{t(:pk_fainted)}", PokeAccess::ArmoniaPanel.member(fainted)
  end

  test "an egg in Armonia's party is said as an egg" do
    egg = Poke.build(:name => "Huevo")
    def egg.egg?; true; end
    assert_equal t(:pty_egg), PokeAccess::ArmoniaPanel.member(egg)
  end

  test "in brief an Armonia member leaves out its level" do
    PokeAccess::Config.verbosity = :brief
    pk = Poke.build(:name => "Bulbasaur", :hp => 0)
    assert_equal "Bulbasaur, #{t(:pk_fainted)}", PokeAccess::ArmoniaPanel.member(pk)
  end

  test "Armonia's DexNav key is said only while its button is shown and key hints are said" do
    disposed = Object.new
    def disposed.visible; raise IOError, "disposed sprite"; end
    { [shown, :full] => [t(:arm_dexnav_key)], [shown(false), :full] => [], [nil, :full] => [],
      [disposed, :full] => [], [shown, :brief] => [] }.each do |(button, level), lines|
      PokeAccess::Config.verbosity = level
      assert_equal lines, PokeAccess::ArmoniaPanel.lines(armonia_menu(button)), "button #{button.inspect} at #{level}"
    end
  end

  # Of two after-hooks on one method the first registered runs its body last; the shared reader's focused button
  # interrupts, so the panel's hook has to come first in the file or the button would cut the panel it follows.
  test "Armonia's panel hook is registered before the shared reader's, so the panel follows the button" do
    src = Harness.source(File.join(Harness::ROOT, "games", "armonia", "pause_menu.rb"))
    panel = src.index('after("PokemonMenu_Scene", :selectButton)')
    shared = src.index("PokeAccess::SpriteButtonMenu.define(")
    refute_nil panel, "the panel's after-hook"
    refute_nil shared, "the shared reader's definition"
    assert_operator panel, :<, shared
  end

  test "Awakening's bar follows the first focused panel, without its clock" do
    $game_switches[650] = true
    PokeAccess::AwakeningPause.open!(fates_menu(64, "0" => true, "1" => false, "2" => true))
    PokeAccess::AwakeningPause.panel_created(fates_panel("Equipo", 2))
    bar = ["Cap: 3 Clases: 2", "Pueblo Alba", "Lana", "$ 1500", t(:awk_day), t(:awk_key_quests),
           t(:awk_key_talisman), t(:awk_key_achievements)]
    assert_equal [["Equipo", true], [bar.join(". "), false]], SpeakCapture.log
  end

  test "an Awakening panel created unfocused says nothing" do
    PokeAccess::AwakeningPause.open!(fates_menu)
    PokeAccess::AwakeningPause.panel_created(fates_panel("Mochila", 3, 0))
    assert_nothing_spoken
  end

  test "an Awakening panel created focused with no menu held says its name alone" do
    PokeAccess::AwakeningPause.open!(fates_menu)
    PokeAccess::AwakeningPause.close!
    PokeAccess::AwakeningPause.open!
    PokeAccess::AwakeningPause.panel_created(fates_panel("Equipo", 2))
    assert_equal [["Equipo", true]], SpeakCapture.log
  end

  test "Awakening's bar says the time of day by the frame its picture shows" do
    PokeAccess::Config.verbosity = :brief
    { 0 => :awk_night, 64 => :awk_day, 128 => :awk_morning, 192 => :awk_evening, 32 => nil }.each do |x, word|
      want = word ? FATES_BAR + [t(word)] : FATES_BAR
      assert_equal want, PokeAccess::AwakeningPause.bar_lines(fates_menu(x)), "the frame at x #{x}"
    end
  end

  test "Awakening's bar says each shortcut icon shown with its key, and the achievements key always" do
    { {} => [:awk_key_achievements], { "0" => true } => [:awk_key_quests, :awk_key_achievements],
      { "1" => true, "2" => false } => [:awk_key_class, :awk_key_achievements],
      { "2" => true } => [:awk_key_gacha, :awk_key_achievements] }.each do |icons, keys|
      want = FATES_BAR + [t(:awk_day)] + keys.map { |k| t(k) }
      assert_equal want, PokeAccess::AwakeningPause.bar_lines(fates_menu(64, icons)), "icons #{icons.inspect}"
    end
  end

  test "Awakening's third shortcut opens the talismans once switch 650 is on" do
    $game_switches[650] = true
    want = FATES_BAR + [t(:awk_day), t(:awk_key_talisman), t(:awk_key_achievements)]
    assert_equal want, PokeAccess::AwakeningPause.bar_lines(fates_menu(64, "2" => true))
  end

  test "with the game's switches unreadable, Awakening's third shortcut stays the gacha" do
    unreadable = Object.new
    def unreadable.[](_id); raise IOError, "no switches yet"; end
    lines = with_switches(unreadable) { PokeAccess::AwakeningPause.bar_lines(fates_menu(64, "2" => true)) }
    assert_equal FATES_BAR + [t(:awk_day), t(:awk_key_gacha), t(:awk_key_achievements)], lines
  end

  test "in brief Awakening's bar leaves out the shortcut keys" do
    PokeAccess::Config.verbosity = :brief
    menu = fates_menu(64, "0" => true, "1" => true, "2" => true)
    assert_equal FATES_BAR + [t(:awk_day)], PokeAccess::AwakeningPause.bar_lines(menu)
  end

  test "an Awakening panel that becomes focused says its name, and one losing focus says nothing" do
    panel = fates_panel("Mochila", 3, 0)
    PokeAccess::AwakeningPause.panel_changed(panel, false)
    assert_nothing_spoken "losing focus"
    PokeAccess::AwakeningPause.panel_changed(panel, true)
    assert_equal [["Mochila", true]], SpeakCapture.log
  end

  test "Awakening's save panel says it is unavailable while the game forbids saving" do
    names = { 5 => "Guardar", 4 => "Opciones" }
    { [5, false] => "Guardar, #{t(:opt_unavailable)}", [5, nil] => "Guardar", [5, true] => "Guardar",
      [4, false] => "Opciones" }.each do |(index, allowed), said|
      with_fates_save(allowed) { PokeAccess::AwakeningPause.panel_changed(fates_panel(names[index], index), true) }
      assert_equal [[said, true]], SpeakCapture.log, "panel #{index}, saving #{allowed.inspect}"
      SpeakCapture.clear
    end
  end

  test "an Awakening panel with no name says nothing" do
    [nil, ""].each do |name|
      PokeAccess::AwakeningPause.panel_changed(fates_panel(name, 2), true)
      assert_nothing_spoken "name #{name.inspect}"
    end
  end

  test "a nameless Awakening panel leaves the last named one for the return" do
    PokeAccess::AwakeningPause.open!(fates_menu)
    PokeAccess::AwakeningPause.say_panel(fates_panel("Guardar", 2))
    [nil, ""].each { |name| PokeAccess::AwakeningPause.say_panel(fates_panel(name, 2)) }
    SpeakCapture.clear
    PokeAccess::AwakeningPause.returned
    assert_equal [["Guardar", true]], SpeakCapture.log
  end

  test "back from a submenu, Awakening's menu says its focused panel again" do
    PokeAccess::AwakeningPause.open!(fates_menu)
    PokeAccess::AwakeningPause.say_panel(fates_panel("Guardar", 2))
    SpeakCapture.clear
    PokeAccess::AwakeningPause.returned
    assert_equal [["Guardar", true]], SpeakCapture.log
  end

  # Awakening's menu disposes itself before saving, D.Moon, a field move or a key item, all from inside its own
  # constructor: the messages those show end as returns to a menu that is gone.
  test "once Awakening's menu has disposed itself, a return says nothing" do
    PokeAccess::AwakeningPause.open!(fates_menu)
    PokeAccess::AwakeningPause.say_panel(fates_panel("Guardar", 2))
    PokeAccess::AwakeningPause.gone!
    SpeakCapture.clear
    PokeAccess::AwakeningPause.returned
    assert_nothing_spoken
  end

  test "a return says Awakening's panel while any opening of its menu is still held" do
    PokeAccess::AwakeningPause.open!(fates_menu)
    PokeAccess::AwakeningPause.open!
    PokeAccess::AwakeningPause.say_panel(fates_panel("Guardar", 2))
    PokeAccess::AwakeningPause.close!
    SpeakCapture.clear
    PokeAccess::AwakeningPause.returned
    assert_equal [["Guardar", true]], SpeakCapture.log, "one opening still held"
    PokeAccess::AwakeningPause.close!
    SpeakCapture.clear
    PokeAccess::AwakeningPause.returned
    assert_nothing_spoken "every opening closed"
  end

  test "Awakening's menu reopened repeats no panel from its last opening" do
    PokeAccess::AwakeningPause.open!(fates_menu)
    PokeAccess::AwakeningPause.say_panel(fates_panel("Guardar", 2))
    PokeAccess::AwakeningPause.close!
    PokeAccess::AwakeningPause.open!(fates_menu)
    SpeakCapture.clear
    PokeAccess::AwakeningPause.returned
    assert_nothing_spoken
  end

  test "with Awakening's menu not open, a return says nothing, though a panel was read" do
    PokeAccess::AwakeningPause.say_panel(fates_panel("Guardar", 2))
    SpeakCapture.clear
    PokeAccess::AwakeningPause.returned
    assert_nothing_spoken
  end

  test "a close with Awakening's menu already closed does not count against its next opening" do
    PokeAccess::AwakeningPause.close!
    PokeAccess::AwakeningPause.open!(fates_menu)
    PokeAccess::AwakeningPause.say_panel(fates_panel("Guardar", 2))
    SpeakCapture.clear
    PokeAccess::AwakeningPause.returned
    assert_equal [["Guardar", true]], SpeakCapture.log
  end

  test "Royal's grid says an entry by the word inside its icon, or by its label for an icon it does not know" do
    { "dex" => :rgrid_dex, "pokeball" => :rgrid_pokemon, "pkmnpc" => :rgrid_pc, "bag" => :rgrid_bag,
      "save" => :rgrid_save, "map" => :rgrid_map, "trainer" => :rgrid_cards, "logros" => :rgrid_achievements,
      "regalo" => :rgrid_gifts, "options" => :rgrid_options, "bag_en" => :rgrid_bag }.each do |icon, word|
      assert_equal t(word), PokeAccess::RoyalGridMenu.label([icon, "Ficha", "openX"]), "icon #{icon}"
    end
    assert_equal "Extras", PokeAccess::RoyalGridMenu.label(["fondo", "Extras", "openExtras"]), "an unknown icon"
  end

  test "Royal's first focused icon is followed by the money and the key bar, queued, and the next icon comes alone" do
    menu = grid_menu(0)
    PokeAccess::RoyalGridMenu.focus(menu)
    menu.instance_variable_set(:@selected_item, 1)
    PokeAccess::RoyalGridMenu.focus(menu)
    bar = ["1.500$", t(:rgrid_key_save, :key => "D"), t(:rgrid_key_controls)].join(". ")
    assert_equal [[t(:rgrid_pokemon), true], [bar, false], [t(:rgrid_bag), true]], SpeakCapture.log
  end

  test "Royal's panel is said at the first focused icon only, though the money changes later in the opening" do
    menu = grid_menu(0)
    PokeAccess::RoyalGridMenu.focus(menu)
    menu.instance_variable_set(:@currentTexts, ["10:43", "2.000$"])
    menu.instance_variable_set(:@selected_item, 1)
    SpeakCapture.clear
    PokeAccess::RoyalGridMenu.focus(menu)
    assert_equal [[t(:rgrid_bag), true]], SpeakCapture.log
  end

  test "Royal's grid says nothing more while its cursor stays" do
    menu = grid_menu(1)
    PokeAccess::RoyalGridMenu.focus(menu)
    SpeakCapture.clear
    PokeAccess::RoyalGridMenu.focus(menu)
    assert_nothing_spoken
  end

  test "Royal's grid says nothing with its cursor past the entries, or with entries it cannot read" do
    { "the cursor past the entries" => [GRID_ITEMS, 5], "no cursor" => [GRID_ITEMS, nil], "no entries" => [nil, 0],
      "an entry that is not an [icon, label, method] triple" => [["pokeball"], 0] }.each do |what, (items, index)|
      PokeAccess::RoyalGridMenu.focus(World.stub_scene(:@items => items, :@selected_item => index,
                                                       :@currentTexts => GRID_TEXTS))
      assert_nothing_spoken what
    end
  end

  test "Royal's focused icon puts the trainer on the info key" do
    PokeAccess::Info.set_info(:pokemon, Poke.build)
    PokeAccess::RoyalGridMenu.focus(grid_menu(0))
    assert_equal trainer_line, PokeAccess::Info.info_text
  end

  test "a Royal grid entry with no word to say says nothing, not even the panel" do
    menu = World.stub_scene(:@items => [["fondo", "", "openExtras"]], :@selected_item => 0,
                            :@currentTexts => GRID_TEXTS)
    PokeAccess::RoyalGridMenu.focus(menu)
    assert_nothing_spoken
  end

  test "Royal's key bar names the save key as the player has it, D by default" do
    { {} => "D", { :z => 0x4B } => "K" }.each do |rebinds, key|
      PokeAccess::Config.rebinds = rebinds
      assert_equal [t(:rgrid_key_save, :key => key), t(:rgrid_key_controls)], PokeAccess::RoyalGridMenu.key_bar,
                   "rebinds #{rebinds.inspect}"
    end
  end

  test "with key hints left out, Royal's panel is the money alone" do
    PokeAccess::Config.verbosity = :brief
    PokeAccess::RoyalGridMenu.panel(grid_menu(0))
    assert_equal [["1.500$", false]], SpeakCapture.log
  end

  test "with no money painted, Royal's panel is the key bar alone" do
    PokeAccess::RoyalGridMenu.panel(World.stub_scene(:@currentTexts => ["10:42"]))
    assert_equal [[[t(:rgrid_key_save, :key => "D"), t(:rgrid_key_controls)].join(". "), false]], SpeakCapture.log
  end

  test "before Royal's grid has painted any text, its panel is the key bar alone" do
    PokeAccess::RoyalGridMenu.panel(World.stub_scene)
    assert_equal [[[t(:rgrid_key_save, :key => "D"), t(:rgrid_key_controls)].join(". "), false]], SpeakCapture.log
  end

  test "with no money painted and key hints left out, Royal's grid says no panel" do
    PokeAccess::Config.verbosity = :brief
    [["10:42"], nil].each do |texts|
      PokeAccess::RoyalGridMenu.panel(World.stub_scene(:@currentTexts => texts))
      assert_nothing_spoken "painted #{texts.inspect}"
    end
  end

  test "back from an entry, Royal's grid says the icon under the cursor again" do
    menu = grid_menu(1)
    PokeAccess::RoyalGridMenu.open!(menu)
    PokeAccess::RoyalGridMenu.focus(menu)
    SpeakCapture.clear
    PokeAccess::RoyalGridMenu.returned
    assert_equal [[t(:rgrid_bag), true]], SpeakCapture.log
  end

  test "a return before Royal's grid has said any icon says nothing" do
    PokeAccess::RoyalGridMenu.open!(grid_menu(1))
    PokeAccess::RoyalGridMenu.returned
    assert_nothing_spoken
  end

  test "back from an entry, Royal's grid puts the trainer back on the info key" do
    menu = grid_menu(1)
    PokeAccess::RoyalGridMenu.open!(menu)
    PokeAccess::RoyalGridMenu.focus(menu)
    PokeAccess::Info.set_info(:pokemon, Poke.build)
    PokeAccess::RoyalGridMenu.returned
    assert_equal trainer_line, PokeAccess::Info.info_text
  end

  test "an entry that ended Royal's grid brings nothing back" do
    [:@exit, :@retorno_vuelo].each do |ended|
      menu = grid_menu(1)
      PokeAccess::RoyalGridMenu.open!(menu)
      PokeAccess::RoyalGridMenu.focus(menu)
      menu.instance_variable_set(ended, true)
      SpeakCapture.clear
      PokeAccess::RoyalGridMenu.returned
      assert_nothing_spoken "with #{ended} set"
      PokeAccess::RoyalGridMenu.close!
    end
  end

  test "with Royal's grid closed, a return says nothing" do
    menu = grid_menu(1)
    PokeAccess::RoyalGridMenu.open!(menu)
    PokeAccess::RoyalGridMenu.focus(menu)
    PokeAccess::RoyalGridMenu.close!
    SpeakCapture.clear
    PokeAccess::RoyalGridMenu.returned
    assert_nothing_spoken
  end

  test "a close with Royal's grid already closed does not count against its next opening" do
    menu = grid_menu(1)
    PokeAccess::RoyalGridMenu.close!
    PokeAccess::RoyalGridMenu.open!(menu)
    PokeAccess::RoyalGridMenu.focus(menu)
    SpeakCapture.clear
    PokeAccess::RoyalGridMenu.returned
    assert_equal [[t(:rgrid_bag), true]], SpeakCapture.log
  end

  test "Reminiscencia's pause panel says the key boxes shown, then the day's objectives by their colour" do
    scene = remin_scene("viaje" => Object.new, "ayuda" => Object.new, "objective" => TextSprite.new(OBJECTIVES))
    assert_equal [t(:rem_key_travel), t(:rem_key_help), "Objetivos:", t(:rem_task_done, :task => "Regar las flores"),
                  t(:rem_task_pending, :task => "Pescar")], PokeAccess::ReminMenu.pause_panel(scene)
  end

  test "each of Reminiscencia's key boxes says its key and what it opens" do
    { "viaje" => :rem_key_travel, "scroll" => :rem_key_boosts, "ayuda" => :rem_key_help }.each do |box, key|
      assert_equal [t(key)], PokeAccess::ReminMenu.pause_panel(remin_scene(box => Object.new)), "the #{box} box"
    end
  end

  test "in brief Reminiscencia's pause panel leaves out the key boxes and keeps the objectives" do
    PokeAccess::Config.verbosity = :brief
    scene = remin_scene("viaje" => Object.new, "ayuda" => Object.new, "objective" => TextSprite.new(OBJECTIVES))
    objectives = ["Objetivos:", t(:rem_task_done, :task => "Regar las flores"), t(:rem_task_pending, :task => "Pescar")]
    assert_equal objectives, PokeAccess::ReminMenu.pause_panel(scene)
  end

  test "a Reminiscencia objective's state is read off its colour in either case, another colour is said as written" do
    text = "<c3=D00606,B89880>Pescar\n<c3=123456,B89880>Pasear\n<c3=008000,B89880>\nRegar"
    scene = remin_scene("objective" => TextSprite.new(text))
    assert_equal [t(:rem_task_pending, :task => "Pescar"), "Pasear", "Regar"], PokeAccess::ReminMenu.pause_panel(scene)
  end

  test "without its objectives window, Reminiscencia's pause panel has no objectives" do
    assert_equal [], PokeAccess::ReminMenu.pause_panel(remin_scene({}))
  end

  test "Reminiscencia's pause buttons say the words their pictures carry" do
    { 0 => :rem_menu_pokemon, 1 => :rem_menu_bag, 2 => :rem_menu_save, 3 => :rem_menu_options,
      4 => :rem_menu_achievements }.each do |i, word|
      assert_equal t(word), PokeAccess::ReminMenu.pause_label(i), "button #{i}"
    end
    assert_nil PokeAccess::ReminMenu.pause_label(5), "no sixth button"
  end

  test "on a dungeon map Reminiscencia's save button is the Abandonar picture" do
    unreadable = Object.new
    def unreadable.include?(_id); raise IOError, "no dungeon list"; end
    { [$game_map.map_id] => :rem_menu_quit, [$game_map.map_id + 1] => :rem_menu_save, nil => :rem_menu_save,
      unreadable => :rem_menu_save }.each do |maps, word|
      with_dungeon_maps(maps) do
        assert_equal t(word), PokeAccess::ReminMenu.pause_label(2), "dungeon maps #{maps.inspect}"
      end
    end
  end

  test "in the dating sim Reminiscencia's fifth button is the Descansar picture" do
    { true => :rem_menu_rest, false => :rem_menu_achievements }.each do |dating, word|
      GameFunctions.with(:isDatingSim? => proc { dating }) do
        assert_equal t(word), PokeAccess::ReminMenu.pause_label(4), "dating sim #{dating}"
      end
    end
    assert_equal t(:rem_menu_achievements), PokeAccess::ReminMenu.pause_label(4), "a game without the function"
  end

  test "opening Reminiscencia's pause menu says its focused option, then its panel queued" do
    with_remin_menu(remin_scene({ "viaje" => Object.new }, :@index => 1), :pause) do
      assert_equal [[t(:rem_menu_bag), true], [t(:rem_key_travel), false]], SpeakCapture.log
    end
  end

  test "Reminiscencia's pause menu says nothing more while its cursor stays" do
    with_remin_menu(remin_scene({}, :@index => 0), :pause) do
      SpeakCapture.clear
      PokeAccess::ReminMenu.poll
      assert_nothing_spoken
    end
  end

  test "a message's end over Reminiscencia's pause menu says its option again" do
    with_remin_menu(remin_scene({}, :@index => 0), :pause) do
      SpeakCapture.clear
      PokeAccess::ReminMenu.refocus
      PokeAccess::ReminMenu.poll
      assert_equal [[t(:rem_menu_pokemon), true]], SpeakCapture.log
    end
  end

  # Reminiscencia's pause menu ends its scene before running the chosen entry; the game reopens the menu as a new one.
  test "once Reminiscencia's pause menu has ended its scene, a message's end brings nothing back" do
    with_remin_menu(remin_scene({}, :@index => 0), :pause) do
      PokeAccess::ReminMenu.ended
      PokeAccess::ReminMenu.refocus
      SpeakCapture.clear
      PokeAccess::ReminMenu.poll
      assert_nothing_spoken
    end
  end

  test "closing Reminiscencia's world map says the pause menu's option again" do
    with_remin_menu(remin_scene({}, :@index => 0), :pause) do
      with_remin_menu(World.stub_scene(:@menu => 1), :worldmap) { SpeakCapture.clear }
      PokeAccess::ReminMenu.poll
      assert_equal [[t(:rem_menu_pokemon), true]], SpeakCapture.log
    end
  end

  test "a Reminiscencia menu is active while it is open, and not once it closes" do
    PokeAccess::ReminMenu.open(remin_scene({}, :@index => 0), :pause)
    assert_equal true, PokeAccess::ReminMenu.active?, "open"
    PokeAccess::ReminMenu.close
    assert_equal false, PokeAccess::ReminMenu.active?, "closed"
  end

  test "files a line with no category said in Reminiscencia's pause menu as a menu's, and on the map as navigation after" do
    filed = nil
    with_remin_pause_rule { PokeAccess::ReminMenu.pause_run { filed = PokeAccess::Speech.category_of(nil) } }
    assert_equal [:menu, :nav], [filed, PokeAccess::Speech.category_of(nil)]
  end

  test "opening a Reminiscencia menu over none forgets a subscreen left without its end" do
    PokeAccess::MenuReturn.enter!
    with_remin_menu(remin_scene({}, :@index => 0), :pause) do
      PausePanelSubscreens.returns = 0
      PausePanelSubscreens.new.back
    end
    assert_equal 1, PausePanelSubscreens.returns
  end

  test "an open Reminiscencia menu holds the menu lock every frame, but not while its bag is in front" do
    with_remin_menu(remin_scene({}, :@index => 0), :pause) do
      assert_equal 2, menu_locks { 2.times { PokeAccess::ReminMenu.poll } }, "the menu in front"
      PokeAccess::ReminBag.watch(World.stub_scene(:@sprites => {}))
      assert_equal 0, menu_locks { PokeAccess::ReminMenu.poll }, "the bag in front"
    end
  end

  test "with no Reminiscencia menu open, a message's end or a scene's end is ignored" do
    PokeAccess::ReminMenu.refocus
    PokeAccess::ReminMenu.ended
    PokeAccess::ReminMenu.poll
    assert_equal false, PokeAccess::ReminMenu.active?
    assert_nothing_spoken
  end

  test "Reminiscencia's title says its buttons, and its load screen its bubbles, by their painted words" do
    { [:load_main, :@index, 0] => :rem_title_play, [:load_main, :@index, 1] => :rem_title_options,
      [:load_main, :@index, 2] => :rem_title_quit, [:load_modes, :@bubbleIndex, 0] => :rem_mode_story,
      [:load_modes, :@bubbleIndex, 1] => :rem_mode_extra, [:load_modes, :@bubbleIndex, 2] => :rem_mode_dungeon,
      [:load_modes, :@bubbleIndex, 3] => :rem_mode_infinite, [:load_modes, :@bubbleIndex, 4] => :rem_mode_simulator,
      [:load_modes, :@bubbleIndex, 5] => :rem_mode_unknown }.each do |(kind, ivar, i), word|
      with_remin_menu(World.stub_scene(ivar => i), kind) do
        assert_equal [[t(word), true]], SpeakCapture.log, "#{kind} #{i}"
      end
      SpeakCapture.clear
    end
  end

  test "Reminiscencia's world map at map level says nothing" do
    with_remin_menu(World.stub_scene(:@menu => 1), :worldmap) { assert_nothing_spoken }
  end

  test "backing out of Reminiscencia's world map to its islands says the island again" do
    with_island_names do
      worldmap = World.stub_scene(:@menu => 0, :@currentisla => 3)
      with_remin_menu(worldmap, :worldmap) do
        worldmap.instance_variable_set(:@menu, 1)
        PokeAccess::ReminMenu.poll
        worldmap.instance_variable_set(:@menu, 0)
        PokeAccess::ReminMenu.poll
        assert_equal [["Isla Glauco", true], ["Isla Glauco", true]], SpeakCapture.log
      end
    end
  end

  test "while its bag is in front, a Reminiscencia menu says nothing" do
    PokeAccess::ReminBag.watch(World.stub_scene(:@sprites => {}))
    with_remin_menu(remin_scene({}, :@index => 0), :pause) { assert_nothing_spoken }
  end

  # The world map paints each island only as a drawing; the game names them elsewhere (getIslaName, by one of their
  # maps).
  test "Reminiscencia's world map says an island by the name the game gives it" do
    with_island_names do
      with_remin_menu(World.stub_scene(:@menu => 0, :@currentisla => 3), :worldmap) do
        assert_equal [["Isla Glauco", true]], SpeakCapture.log
      end
    end
  end

  test "an island Reminiscencia's game gives no name, or a game without the function, says its number" do
    scene = World.stub_scene(:@menu => 0, :@currentisla => 3)
    island = [[:isla, 3], t(:rem_island, :n => 3)]
    assert_equal island, PokeAccess::ReminMenu.worldmap_state(scene), "without getIslaName"
    GameFunctions.with(:getIslaName => proc { |_map| "  " }) do
      assert_equal island, PokeAccess::ReminMenu.worldmap_state(scene), "a blank name"
    end
  end

  test "an island the world map lists no map for says its number, though the game names islands" do
    with_island_names do
      assert_equal [[:isla, 5], t(:rem_island, :n => 5)],
                   PokeAccess::ReminMenu.worldmap_state(World.stub_scene(:@menu => 0, :@currentisla => 5))
    end
  end

  test "each of Reminiscencia's islands is named by one of its maps" do
    with_island_names do
      assert_equal ISLAND_NAMES.values_at(8, 67, 69, 82), (1..4).map { |i| PokeAccess::ReminMenu.island_name(i) }
    end
  end

  test "Realidea's speech box leads, then the key boxes and the money, queued" do
    with_money(900) { PokeAccess::ReaPauseOverlay.say(rea_menu("Salir de aventura...", "Q" => shown)) }
    assert_equal [["Salir de aventura...", false], ["Z: Guardar. Q: Teletr. $900", false]], SpeakCapture.log
  end

  test "Realidea's next opening says the speech box again, and its strip only if it changed" do
    with_money(900) do
      scene = rea_menu("Salir de aventura...", "Q" => shown)
      PokeAccess::ReaPauseOverlay.say(scene)
      SpeakCapture.clear
      PokeAccess::ReaPauseOverlay.say(scene)
    end
    assert_equal [["Salir de aventura...", false]], SpeakCapture.log
  end

  test "an empty speech box says nothing before Realidea's strip" do
    with_money(900) { PokeAccess::ReaPauseOverlay.say(rea_menu("", {})) }
    assert_equal [["Z: Guardar. $900", false]], SpeakCapture.log
  end

  test "Realidea's strip has no teleport key while its icon is blank or missing" do
    with_money(900) do
      [{ "Q" => shown(false) }, {}].each do |sprites|
        assert_equal ["Z: Guardar", "$900"], PokeAccess::ReaPauseOverlay.strip(rea_menu("", sprites)),
                     "sprites #{sprites.keys.inspect}"
      end
    end
  end

  test "Realidea's talisman leads the strip only while it glows on a map that hides something" do
    glow = PokeAccess::I18n.t(:rea_talisman_glow)
    with_money(900) do
      { [true, true] => [glow, "Z: Guardar", "$900"], [true, false] => ["Z: Guardar", "$900"],
        [false, true] => ["Z: Guardar", "$900"], [nil, true] => ["Z: Guardar", "$900"] }.each do |(icon, hidden), strip|
        $game_switches[314] = hidden
        sprites = icon.nil? ? {} : { "talisman" => shown(icon) }
        assert_equal strip, PokeAccess::ReaPauseOverlay.strip(rea_menu("", sprites)),
                     "icon #{icon.inspect}, hidden #{hidden}"
      end
    end
  end

  test "a talisman icon or a map switch that cannot be read is no glow" do
    disposed = Object.new
    def disposed.visible; raise IOError, "disposed sprite"; end
    unreadable = Object.new
    def unreadable.[](_id); raise IOError, "no switches yet"; end
    $game_switches[314] = true
    with_money(900) do
      assert_equal ["Z: Guardar", "$900"], PokeAccess::ReaPauseOverlay.strip(rea_menu("", "talisman" => disposed)),
                   "a disposed icon"
      strip = with_switches(unreadable) { PokeAccess::ReaPauseOverlay.strip(rea_menu("", "talisman" => shown)) }
      assert_equal ["Z: Guardar", "$900"], strip, "switches that raise"
    end
  end

  test "in brief Realidea's strip leaves out the key boxes" do
    PokeAccess::Config.verbosity = :brief
    $game_switches[314] = true
    with_money(900) do
      strip = PokeAccess::ReaPauseOverlay.strip(rea_menu("", "Q" => shown, "talisman" => shown))
      assert_equal [t(:rea_talisman_glow), "$900"], strip
    end
  end

  test "with no money to read, Realidea's strip says none" do
    with_money(nil) do
      assert_equal ["Z: Guardar"], PokeAccess::ReaPauseOverlay.strip(rea_menu("", {}))
    end
  end

  test "Realidea's strip says its words as the game's own translation gives them" do
    strip = with_money(900) do
      with_intl("Guardar" => "Save", "Teletr." => "Telep.", "${1}" => "{1} $") do
        PokeAccess::ReaPauseOverlay.strip(rea_menu("", "Q" => shown))
      end
    end
    assert_equal ["Z: Save", "Q: Telep.", "900 $"], strip
  end

  test "a subscreen the pause menu opens bare is one return at its end, its dialogue nested inside" do
    PausePanelSubscreens.returns = 0
    PausePanelSubscreens.new.back
    assert_equal 1, PausePanelSubscreens.returns
  end

  test "a subscreen the pause menu closes after ends without a return, its dialogue still nested" do
    PausePanelSubscreens.returns = 0
    PausePanelSubscreens.new.closing
    assert_equal 0, PausePanelSubscreens.returns
  end

  test "after a subscreen the pause menu closes after, the next fade is a return again" do
    PausePanelSubscreens.new.closing
    PausePanelSubscreens.returns = 0
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.leave!
    assert_equal 1, PausePanelSubscreens.returns
  end

  test "a pause menu's opening forgets a subscreen left without its end" do
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.reset_nesting
    PausePanelSubscreens.returns = 0
    PausePanelSubscreens.new.back
    assert_equal 1, PausePanelSubscreens.returns
  end

  # The sprite-button pause menus (Armonia, Africanus) never update the map, which is what keeps the info key on the
  # trainer in a pause menu, so they keep it there themselves.
  test "a sprite-button pause menu's focused button puts the trainer on the info key" do
    PokeAccess::Info.set_info(:item, 1)
    PokeAccess::SpriteButtonMenu.focus(World.stub_scene(:@buttons => [["pokemon", "Pokemon"]]), 0)
    assert_equal trainer_line, PokeAccess::Info.info_text
  end

  test "back from a subscreen, a sprite-button pause menu puts the trainer back on the info key" do
    PokeAccess::SpriteButtonMenu.open!
    PokeAccess::SpriteButtonMenu.focus(World.stub_scene(:@buttons => [["pokemon", "Pokemon"]]), 0)
    PokeAccess::Info.set_info(:pokemon, Poke.build)
    PokeAccess::SpriteButtonMenu.returned
    assert_equal trainer_line, PokeAccess::Info.info_text
  ensure
    PokeAccess::SpriteButtonMenu.close!
  end

  private

  # A translated text of the mod.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # What the info key says of the trainer, which a pause menu puts on it.
  def trainer_line
    line = PokeAccess::Info.trainer_info
    refute_nil line, "the trainer has a line to say"
    line
  end

  # Evaluates, once per process, the first module block of a profile file at its own line numbers: its hooks are left
  # out so none binds to the stubs, and it is read through the harness so a mutant of it applies.
  def load_profile(game, file, name)
    return if PokeAccess.const_defined?(name, false)
    path = File.join(Harness::ROOT, "games", game, file)
    src = Harness.source(path)
    block = src.match(/^module PokeAccess\r?\n.*?^end\r?\n/m)
    eval(block[0], TOPLEVEL_BINDING, path, src[0, block.begin(0)].count("\n") + 1)
  end

  # Runs the block with Reminiscencia's pause-menu block evaluated (its callMenuNuevo wrapper, absent here, and its
  # on_map? override); on_map?, the overrides listed, the absent functions and the profiles declared are put back.
  def with_remin_pause_rule
    ctl = PokeAccess::Control
    plain = ctl.method(:on_map?)
    hooks = PokeAccess::Hooks
    kept = [hooks.overrides.length, hooks.fn_absent.dup, PokeAccess::Game.profiles.dup,
            PokeAccess::Game.instance_variable_get(:@profile_name)]
    path = File.join(Harness::ROOT, "games", "reminiscencia", "menus.rb")
    found = Harness.source(path).match(/^PokeAccess::Game\.define\("reminiscencia"\) do\r?\n  kernel\("callMenuNuevo".*?^end\r?\n/m)
    eval(found[0], TOPLEVEL_BINDING, path, found.pre_match.count("\n") + 1)
    yield
  ensure
    ctl.define_singleton_method(:on_map?, plain)
    hooks.overrides.slice!(kept[0]..-1)
    hooks.fn_absent.replace(kept[1])
    PokeAccess::Game.profiles.replace(kept[2])
    PokeAccess::Game.instance_variable_set(:@profile_name, kept[3])
  end

  # [module, ivar, value] for each piece of KEPT state as it stands, arrays copied.
  def kept_state
    KEPT.flat_map do |name, ivars|
      mod = PokeAccess.const_get(name)
      ivars.map do |ivar|
        value = mod.instance_variable_get(ivar)
        [mod, ivar, value.is_a?(Array) ? value.dup : value]
      end
    end
  end

  # A sprite shown with a picture, or hidden and blank.
  def shown(visible = true)
    Sprite.new(visible, visible ? Object.new : nil)
  end

  # Runs the block with Array#- deleting in place and returning its receiver, as Pokemon Z redefines it.
  def with_in_place_array_minus
    Array.class_eval do
      alias_method :pa_spec_minus, :-
      define_method(:-) do |other|
        (other.is_a?(Array) ? other : [other]).each { |e| delete(e) if include?(e) }
        self
      end
    end
    yield
  ensure
    Array.class_eval do
      alias_method :-, :pa_spec_minus
      remove_method :pa_spec_minus
    end
  end

  # Marin's DP menu with two entries, its cursor on option.
  def dp_menu(option)
    World.stub_scene(:@options => [["Pokédex"], ["Mochila"]], :@option => option)
  end

  # The DP menu's panel as the menu paints it while it is built: the capture armed, then the rows painted.
  def paint_dp_panel(rows)
    PokeAccess::PaintCapture.arm(:dp_panel)
    PokeAccess::PaintCapture.note_positions(rows)
  end

  # Runs the block with Relict's tower floor and level cap (getLevelCap) at the values given; :absent leaves the
  # game's function undefined.
  def with_relict_plate(floor, cap)
    $PokemonGlobal.define_singleton_method(:dungeonFloor) { floor }
    return yield if cap == :absent
    GameFunctions.with(:getLevelCap => proc { cap }) { yield }
  ensure
    $PokemonGlobal.singleton_class.send(:remove_method, :dungeonFloor)
  end

  # Runs the block with the trainer's party set to party.
  def with_party(party)
    $Trainer.define_singleton_method(:party) { party }
    yield
  ensure
    $Trainer.singleton_class.send(:remove_method, :party)
  end

  # Armonia's pause menu with its DexNav button sprite (nil: none).
  def armonia_menu(dexnav)
    World.stub_scene(:@btDexNav => dexnav)
  end

  # Armonia's pbMenuTexts painting rows ([text, x, y]) under the panel's capture.
  def paint_armonia_panel(scene, rows)
    PokeAccess::ArmoniaPanel.capture(scene) { PokeAccess::PaintCapture.note_positions(rows) }
  end

  # Awakening's JessFatesMenu as its bar reads it: FATES_BAR, a clock, the day-time picture at the frame x, and the
  # shortcut icons by slot ({slot => shown?}).
  def fates_menu(day_x = 64, icons = {})
    boxes = Hash[[:@act, :@map, :@nom, :@dinero].zip(FATES_BAR.map { |text| TextSprite.new(text) })]
    World.stub_scene(boxes.merge(:@hora => TextSprite.new("10:42"), :@dia => Strip.new(SrcRect.new(day_x, 0)),
                                 :@icons => Hash[icons.map { |slot, on| [slot, shown(on)] }]))
  end

  # One of Awakening's FatesMenuPanels: its name, its index in the strip and the sprite row its picture shows, 37 when
  # focused.
  def fates_panel(name, index, row = 37)
    World.stub_scene(:@nombre => name, :@index => index, :@pnl => Strip.new(SrcRect.new(0, row)))
  end

  # Runs the block with $Fates_save, the game's leave to save, set to allowed.
  def with_fates_save(allowed)
    was = $Fates_save
    $Fates_save = allowed
    yield
  ensure
    $Fates_save = was
  end

  # Royal's Menu2 with GRID_ITEMS and GRID_TEXTS, its cursor on index.
  def grid_menu(index)
    World.stub_scene(:@items => GRID_ITEMS, :@selected_item => index, :@currentTexts => GRID_TEXTS)
  end

  # A scene of Reminiscencia's with the given sprites and ivars.
  def remin_scene(sprites, ivars = {})
    World.stub_scene({ :@sprites => sprites }.merge(ivars))
  end

  # Runs the block with a Reminiscencia menu of kind open over scene, closed after.
  def with_remin_menu(scene, kind)
    PokeAccess::ReminMenu.open(scene, kind)
    yield
  ensure
    PokeAccess::ReminMenu.close
  end

  # The times the block arms the menu lock (Keys.menu_lock!), which keeps the config key the game's for a few frames.
  def menu_locks
    keys = PokeAccess::Keys
    real = keys.method(:menu_lock!)
    count = 0
    keys.define_singleton_method(:menu_lock!) { count += 1; real.call }
    yield
    count
  ensure
    keys.define_singleton_method(:menu_lock!, real)
  end

  # Runs the block with the game's getIslaName naming the maps of ISLAND_NAMES.
  def with_island_names
    GameFunctions.with(:getIslaName => proc { |map| ISLAND_NAMES[map] }) { yield }
  end

  # Runs the block with $dungeon_maps, the maps Reminiscencia counts as a dungeon's, set to maps.
  def with_dungeon_maps(maps)
    was = $dungeon_maps
    $dungeon_maps = maps
    yield
  ensure
    $dungeon_maps = was
  end

  # Realidea's pause menu: its speech box saying speech, and its sprites.
  def rea_menu(speech, sprites)
    World.stub_scene(:@window => TextSprite.new(speech), :@sprites => sprites)
  end

  # The block's value with $game_switches replaced by switches, put back after.
  def with_switches(switches)
    was = $game_switches
    $game_switches = switches
    yield
  ensure
    $game_switches = was
  end

  # Runs the block with the trainer's money at value.
  def with_money(value)
    was = $Trainer.money
    $Trainer.money = value
    yield
  ensure
    $Trainer.money = was
  end
end
