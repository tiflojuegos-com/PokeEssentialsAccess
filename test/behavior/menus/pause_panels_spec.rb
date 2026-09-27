# The panels pause menus paint beside their options: said after the focused option (PausePanel), and at later
# openings only the lines that changed. Profiles are evaluated module-only so their hooks do not stack on the stubs.
module PausePanelSpec
  @returns = 0

  class << self
    attr_accessor :returns
  end

  # Evaluates the module block of one of this repo's profile files, the harness's own loading mechanism.
  def self.load_module(game, file)
    path = File.join(Harness::ROOT, "games", game, file)
    eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
  end

  def self.forget
    PokeAccess::PausePanel.instance_variable_set(:@last, [])
  end

  def self.box(text)
    o = Object.new
    o.define_singleton_method(:vtxt) { text }
    o.define_singleton_method(:text) { text }
    o
  end

  def self.shown(visible = true)
    Struct.new(:visible, :bitmap).new(visible, visible ? Object.new : nil)
  end

  # Two subscreens a menu opens bare, one it comes back from and one it always closes after.
  class Screens
    def back; PokeAccess::MenuReturn.enter!; PokeAccess::MenuReturn.leave!; end
    def closing; PokeAccess::MenuReturn.enter!; PokeAccess::MenuReturn.leave!; end
  end
end

PokeAccess::MenuReturn.bare("PausePanelSpec::Screens", :back)
PokeAccess::MenuReturn.bare("PausePanelSpec::Screens", :closing, :closes => true)
PokeAccess::MenuReturn.on_return { PausePanelSpec.returns += 1 }

Suite.define("pause panel: all its lines at the first opening, then only the ones that changed") do
  PausePanelSpec.forget
  pp = PokeAccess::PausePanel
  pp.say(["Nivel máx. actual: 20", "Vidas: 3"])
  eq "the whole panel, queued", SpeakCapture.log, [["Nivel máx. actual: 20. Vidas: 3", false]]
  SpeakCapture.clear
  pp.say(["Nivel máx. actual: 20", "Vidas: 3"])
  eq "an unchanged panel says nothing", SpeakCapture.lines, []
  pp.say(["Nivel máx. actual: 20", "Vidas: 2"])
  eq "a life lost is the one line said", SpeakCapture.lines, ["Vidas: 2"]
  SpeakCapture.clear
  pp.say("")
  pp.say(nil)
  eq "an empty panel is silent", SpeakCapture.lines, []
  pairs = [["Pokédex", :positions, 40, 20], ["Nivel máx.", :positions, 300, 100], ["20", :positions, 400, 100],
           ["Mochila", :positions, 40, 60]]
  eq "the capture's lines, less the menu's own labels", pp.lines(pairs, ["Pokédex", "Mochila"]), ["Nivel máx. 20"]
  z = [["Pokédex", :positions, 68, 20], ["[A] Curar", :positions, 300, 20], ["Guardar", :positions, 68, 260],
       ["Nivel Máx.: 30", :positions, 300, 260]]
  eq "a panel row at an option's height is not glued to its label (Pokemon Z)", pp.lines(z, ["Pokédex", "Guardar"]),
     ["[A] Curar", "Nivel Máx.: 30"]
end

# Under Pokemon Z's Array#- (deletes in place and returns the receiver), redefined here for this suite only, an
# unchanged panel is said once.
Suite.define("pause panel: under Pokemon Z's in-place Array#-, an unchanged panel is said once") do
  PausePanelSpec.forget
  Array.class_eval do
    alias_method :pp_spec_minus, :-
    define_method(:-) do |var|
      (var.is_a?(Array) ? var : [var]).each { |e| delete(e) if include?(e) }
      self
    end
  end
  said = nil
  begin
    SpeakCapture.clear
    3.times { PokeAccess::PausePanel.say(["Dinero: 100", "Medallas: 2"]) }
    said = SpeakCapture.lines.length
  ensure
    Array.class_eval do
      alias_method :-, :pp_spec_minus
      remove_method :pp_spec_minus
    end
    PausePanelSpec.forget
  end
  eq "three openings of the same panel say it once", said, 1
end

Suite.define("dp pause menu: its panel follows the first option") do
  PausePanelSpec.forget
  menu = World.stub_scene(:@options => [["Pokédex"], ["Mochila"]], :@option => 0)
  PokeAccess::PaintCapture.arm(:dp_panel)
  PokeAccess::PaintCapture.note_positions([["Pokédex", 40, 20], ["Nivel máx. actual: 20", 300, 100],
                                           ["Vidas: 3", 300, 130], ["Mochila", 40, 60]])
  PokeAccess::DPMenu.read(menu)
  PokeAccess::DPMenu.read(menu)
  eq "the option, then the panel queued, once", SpeakCapture.log,
     [["Pokédex", true], ["Nivel máx. actual: 20. Vidas: 3", false]]
end

Suite.define("relict: the ring's plate says the floor and the level cap its digits draw") do
  PausePanelSpec.load_module("relict", "pausemenu.rb") unless defined?(PokeAccess::RelictMenu)
  PausePanelSpec.forget
  t = PokeAccess::I18n
  old = $PokemonGlobal
  had_cap = Object.private_method_defined?(:getLevelCap) || Object.method_defined?(:getLevelCap)
  floor = [0]
  begin
    g = Object.new
    g.define_singleton_method(:dungeonFloor) { floor[0] }
    $PokemonGlobal = g
    Object.send(:define_method, :getLevelCap) { 25 } unless had_cap
    PokeAccess::RelictMenu.panel
    eq "outside the tower the floor is the 0 the digit strip draws for its ?", SpeakCapture.lines,
       ["#{t.t(:rel_panel_floor, :n => '0')}. #{t.t(:rel_panel_cap, :n => '25')}"]
    SpeakCapture.clear
    floor[0] = 12
    PokeAccess::RelictMenu.panel
    eq "a floor climbed is the one line said", SpeakCapture.lines, [t.t(:rel_panel_floor, :n => "12")]
    eq "the buttons say the words their pictures carry", [t.t(PokeAccess::RelictMenu::RADIAL[0]), t.t(PokeAccess::RelictMenu::RADIAL[5])],
       [t.t(:rel_radial_party), t.t(:rel_radial_exit)]
  ensure
    $PokemonGlobal = old
    Object.send(:remove_method, :getLevelCap) unless had_cap
  end
end

Suite.define("armonia: the menu's panel says each member's level, HP and status, badges and money, and the DexNav key") do
  PausePanelSpec.load_module("armonia", "pause_menu.rb") unless defined?(PokeAccess::ArmoniaPanel)
  PausePanelSpec.forget
  t = PokeAccess::I18n
  old = $Trainer
  begin
    party = [Poke.build(:name => "Pikachu"), Poke.build(:name => "Bulbasaur", :hp => 0)]
    tr = Object.new
    tr.define_singleton_method(:party) { party }
    $Trainer = tr
    scene = World.stub_scene(:@btDexNav => PausePanelSpec.shown)
    PokeAccess::ArmoniaPanel.capture(scene) do
      PokeAccess::PaintCapture.note_positions([["Lvl. 5", 65, 15], ["Lvl. 7", 65, 63], ["Medallas: 2", 3, 302],
                                               ["Juego: 01:05", 3, 329], ["Dinero: $900", 3, 356],
                                               ["Pokémon", 50, 58]])
    end
    PokeAccess::ArmoniaPanel.opened(scene)
    PokeAccess::ArmoniaPanel.opened(scene)
    pika = "Pikachu, #{t.t(:arm_level, :n => 25)}, #{t.t(:bt_hp_pct, :n => 100)}"
    bulba = "Bulbasaur, #{t.t(:arm_level, :n => 25)}, #{t.t(:pk_fainted)}"
    eq "once per opening: each member, the trainer lines but the clock, no button labels", SpeakCapture.lines,
       [[pika, bulba, "Medallas: 2", "Dinero: $900", t.t(:arm_dexnav_key)].join(". ")]
    party[0].hp = 1
    party[0].totalhp = 200
    party[0].status = 2
    eq "a sliver of HP is never nought, and the status icon follows the bar",
       PokeAccess::ArmoniaPanel.member(party[0]),
       "Pikachu, #{t.t(:arm_level, :n => 25)}, #{t.t(:bt_hp_pct, :n => 1)}, #{PokeAccess::Party.status_slot(party[0])}"
    PokeAccess::Config.verbosity = :brief
    eq "in brief the level is left out", PokeAccess::ArmoniaPanel.lines(scene)[1], "Bulbasaur, #{t.t(:pk_fainted)}"
    falsy "and so is the DexNav key, a key hint",
          PokeAccess::ArmoniaPanel.lines(scene).include?(t.t(:arm_dexnav_key))
    party[0].hp = 40
    party[0].totalhp = 40
    party[0].status = 0
    PokeAccess::Config.verbosity = :full
    SpeakCapture.clear
    scene2 = World.stub_scene(:@btDexNav => PausePanelSpec.shown(false),
                              :@access_panel_rows => ["Medallas: 2", "Dinero: $1200"])
    PokeAccess::ArmoniaPanel.opened(scene2)
    eq "the next opening says the money that changed", SpeakCapture.lines, ["Dinero: $1200"]
  ensure
    $Trainer = old
  end
end

# Of two after-hooks on one method the first registered runs its body last; the shared reader's focused button
# interrupts, so the panel's hook has to come first in the file or the button cuts the panel it follows.
Suite.define("armonia: the panel's hook is registered before the shared reader's, so it follows the button") do
  src = File.read(File.join(Harness::ROOT, "games", "armonia", "pause_menu.rb"))
  panel = src.index('after("PokemonMenu_Scene", :selectButton)')
  shared = src.index("PokeAccess::SpriteButtonMenu.define(")
  truthy "the panel's after-hook comes before SpriteButtonMenu.define", panel && shared && panel < shared
end

Suite.define("awakening: the bar across the menu follows the first panel, and a dimmed save says so") do
  PausePanelSpec.load_module("awakening", "pausemenu.rb") unless defined?(PokeAccess::AwakeningPause)
  PausePanelSpec.forget
  t = PokeAccess::I18n
  aw = PokeAccess::AwakeningPause
  icons = { "0" => PausePanelSpec.shown, "1" => PausePanelSpec.shown(false), "2" => PausePanelSpec.shown }
  menu = World.stub_scene(:@act => PausePanelSpec.box("Cap:   3   Clases:  2"), :@map => PausePanelSpec.box("Pueblo Alba"),
                          :@nom => PausePanelSpec.box("Lana"), :@dinero => PausePanelSpec.box("$ 1500"),
                          :@hora => PausePanelSpec.box("10:42"),
                          :@dia => Struct.new(:src_rect).new(Struct.new(:x).new(64)), :@icons => icons)
  pnl = Struct.new(:src_rect).new(Struct.new(:y).new(37))
  panel = World.stub_scene(:@nombre => "Equipo", :@index => 2, :@pnl => pnl)
  save = World.stub_scene(:@nombre => "Guardar", :@index => 5)
  old_save = $Fates_save
  begin
    $game_switches[650] = true
    aw.open!(menu)
    aw.panel_created(panel)
    eq "the focused panel, then the bar without its clock", SpeakCapture.log,
       [["Equipo", true], [["Cap: 3 Clases: 2", "Pueblo Alba", "Lana", "$ 1500", t.t(:awk_day), t.t(:awk_key_quests),
                           t.t(:awk_key_talisman), t.t(:awk_key_achievements)].join(". "), false]]
    PokeAccess::Config.verbosity = :brief
    eq "in brief the shortcut keys are left out of the bar", aw.bar_lines(menu).length, 5
    PokeAccess::Config.verbosity = :full
    SpeakCapture.clear
    $Fates_save = false
    aw.panel_changed(save, true)
    eq "the save panel drawn dimmed", SpeakCapture.lines, ["Guardar, #{t.t(:opt_unavailable)}"]
  ensure
    aw.close!
    $Fates_save = old_save
  end
end

# Awakening's menu disposes itself before saving, D.Moon, a field move or a key item, all from inside its own
# constructor: the messages those show end as returns to a menu that is gone, and must not bring its panel back.
Suite.define("awakening: a menu taken off the screen brings back no panel") do
  PausePanelSpec.load_module("awakening", "pausemenu.rb") unless defined?(PokeAccess::AwakeningPause)
  ap = PokeAccess::AwakeningPause
  panel = Object.new
  panel.instance_variable_set(:@nombre, "Guardar")
  panel.instance_variable_set(:@index, 2)
  ap.open!
  begin
    ap.say_panel(panel)
    SpeakCapture.clear
    ap.returned
    eq "back from a screen over the menu, its panel is said again", SpeakCapture.lines, ["Guardar"]
    ap.gone!
    SpeakCapture.clear
    ap.returned
    silent "once the menu has disposed itself, a message's end says nothing of it"
  ensure
    ap.close!
  end
end

# Royal's grid menu: the word inside each icon and the money once; back from an entry, the icon again, unless the
# entry ended the menu (@exit).
Suite.define("royal: the grid says the word inside each icon, and the money beside it once") do
  PausePanelSpec.load_module("royal", "menu_parrilla.rb") unless defined?(PokeAccess::RoyalGridMenu)
  PausePanelSpec.forget
  t = PokeAccess::I18n
  grid = PokeAccess::RoyalGridMenu
  eq "the English set of pictures says the same word", grid.label(["bag_en", "Mochila", "openBag"]), t.t(:rgrid_bag)
  eq "the cards are Tarjetas, not the undrawn Ficha", grid.label(["trainer", "Ficha", "openTarjetaLiga"]), t.t(:rgrid_cards)
  eq "the achievements icon, not the Mystery Gift's label", grid.label(["logros", "Regalo", "openLogros"]), t.t(:rgrid_achievements)
  items = [["pokeball", "Equipo", "openParty"], ["bag", "Mochila", "openBag"]]
  menu = World.stub_scene(:@items => items, :@selected_item => 0, :@currentTexts => ["10:42", "1.500$"])
  grid.focus(menu)
  menu.instance_variable_set(:@selected_item, 1)
  grid.focus(menu)
  bar = [t.t(:rgrid_key_save, :key => "D"), t.t(:rgrid_key_controls)]
  eq "the icon, the money and the key bar queued after the first, then the next icon", SpeakCapture.log,
     [[t.t(:rgrid_pokemon), true], [PokeAccess.sentences(["1.500$"] + bar), false], [t.t(:rgrid_bag), true]]
  eq "the bar names the save key as the player has it, D (Input::SPECIAL) by default", grid.key_bar, bar
  PokeAccess::Config.rebinds = { :z => 0x4B }
  eq "or the key it is rebound to", grid.key_bar[0], t.t(:rgrid_key_save, :key => "K")
  PokeAccess::Config.rebinds = {}
  PausePanelSpec.forget
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  grid.panel(World.stub_scene(:@currentTexts => ["10:42", "1.500$"]))
  eq "with key hints off, the money alone", SpeakCapture.lines, ["1.500$"]
  PokeAccess::Config.verbosity = :full

  grid.open!(menu)
  begin
    PokeAccess::Info.set_info(:pokemon, :someone)
    SpeakCapture.clear
    grid.returned
    eq "back from an entry, the icon under the cursor", SpeakCapture.lines, [t.t(:rgrid_bag)]
    eq "and the info key answers with the trainer again, not the last Pokemon",
       PokeAccess::Info.instance_variable_get(:@kind), :trainer
    menu.instance_variable_set(:@exit, true)
    SpeakCapture.clear
    grid.returned
    silent "an entry that ended the menu brings nothing back"
  ensure
    grid.close!
  end
end

Suite.define("reminiscencia: the pause menu's key boxes and the day's objectives by their colour") do
  PausePanelSpec.load_module("reminiscencia", "menus.rb") unless defined?(PokeAccess::ReminMenu)
  PausePanelSpec.forget
  t = PokeAccess::I18n
  rm = PokeAccess::ReminMenu
  text = "<ac><c3=FAFAFA,7E5F5F>Objetivos:\n<c3=008000,B89880>Regar las flores\n<c3=d00606,B89880>Pescar</ac>"
  scene = World.stub_scene(:@sprites => { "viaje" => Object.new, "ayuda" => Object.new,
                                          "objective" => PausePanelSpec.box(text) })
  eq "the keys showing, then each task with the state its colour shows", rm.pause_panel(scene),
     [t.t(:rem_key_travel), t.t(:rem_key_help), "Objetivos:", t.t(:rem_task_done, :task => "Regar las flores"),
      t.t(:rem_task_pending, :task => "Pescar")]
  PokeAccess::Config.verbosity = :brief
  eq "in brief the key boxes are left out and the objectives stay", rm.pause_panel(scene),
     ["Objetivos:", t.t(:rem_task_done, :task => "Regar las flores"), t.t(:rem_task_pending, :task => "Pescar")]
  PokeAccess::Config.verbosity = :full
  eq "the first button says the word its picture carries", rm.pause_label(0), t.t(:rem_menu_pokemon)
  old_maps = $dungeon_maps
  begin
    $dungeon_maps = [$game_map.map_id]
    eq "on a dungeon map the save button is the Abandonar picture", rm.pause_label(2), t.t(:rem_menu_quit)
  ensure
    $dungeon_maps = old_maps
  end
  eq "the title's bubbles say their painted words", rm.word(rm::LOAD_MODES[3]), t.t(:rem_mode_infinite)
end

# Reminiscencia's pause menu ends its scene before running the chosen entry; after that a message's end brings back
# no option (the game reopens the menu as a new one).
Suite.define("reminiscencia: a pause menu that ended its scene says its option no more") do
  PausePanelSpec.load_module("reminiscencia", "menus.rb") unless defined?(PokeAccess::ReminMenu)
  rm = PokeAccess::ReminMenu
  stack = rm.instance_variable_get(:@stack)
  stack.push({ :scene => World.stub_scene(:@index => 0, :@sprites => {}), :kind => :pause, :last => nil })
  begin
    SpeakCapture.clear
    rm.poll
    eq "the open menu says its option", SpeakCapture.lines, [PokeAccess::I18n.t(:rem_menu_pokemon)]
    rm.refocus
    SpeakCapture.clear
    rm.poll
    eq "and says it again when a message over it ends", SpeakCapture.lines, [PokeAccess::I18n.t(:rem_menu_pokemon)]
    rm.ended
    rm.refocus
    SpeakCapture.clear
    rm.poll
    silent "once it has ended its scene, a message's end brings nothing back"
  ensure
    stack.pop
  end
end

Suite.define("realidea: the menu's speech box leads the strip, and each key says the word beside it") do
  PausePanelSpec.load_module("realidea", "pause_overlay.rb") unless defined?(PokeAccess::ReaPauseOverlay)
  old = $Trainer
  begin
    tr = Object.new
    def tr.money; 900; end
    $Trainer = tr
    PausePanelSpec.forget
    scene = World.stub_scene(:@window => PausePanelSpec.box("Salir de aventura..."),
                             :@sprites => { "Q" => PausePanelSpec.shown })
    PokeAccess::ReaPauseOverlay.say(scene)
    eq "the objective, then the keys and the money, queued", SpeakCapture.log,
       [["Salir de aventura...", false], ["Z: Guardar. Q: Teletr. $900", false]]
    SpeakCapture.clear
    PokeAccess::ReaPauseOverlay.say(scene)
    eq "the next opening says the objective again, the strip only if it changed", SpeakCapture.lines,
       ["Salir de aventura..."]
    bare = World.stub_scene(:@window => PausePanelSpec.box(""), :@sprites => { "Q" => PausePanelSpec.shown(false) })
    eq "no teleport key while its icon is blank", PokeAccess::ReaPauseOverlay.strip(bare), ["Z: Guardar", "$900"]
  ensure
    $Trainer = old
  end
end

Suite.define("realidea: the talisman leads the strip while it glows on a map that hides something") do
  PausePanelSpec.load_module("realidea", "pause_overlay.rb") unless defined?(PokeAccess::ReaPauseOverlay)
  old = $Trainer
  begin
    tr = Object.new
    def tr.money; 900; end
    $Trainer = tr
    lit = World.stub_scene(:@window => PausePanelSpec.box(""),
                           :@sprites => { "Q" => PausePanelSpec.shown(false), "talisman" => PausePanelSpec.shown })
    eq "no glow on a map that hides nothing", PokeAccess::ReaPauseOverlay.strip(lit), ["Z: Guardar", "$900"]
    $game_switches[314] = true
    eq "the talisman first while it glows", PokeAccess::ReaPauseOverlay.strip(lit),
       [PokeAccess::I18n.t(:rea_talisman_glow), "Z: Guardar", "$900"]
    unlit = World.stub_scene(:@window => PausePanelSpec.box(""),
                             :@sprites => { "Q" => PausePanelSpec.shown(false), "talisman" => PausePanelSpec.shown(false) })
    eq "and nothing while the menu keeps it hidden", PokeAccess::ReaPauseOverlay.strip(unlit), ["Z: Guardar", "$900"]
  ensure
    $Trainer = old
  end
end

Suite.define("menu return: a subscreen the menu closes after keeps its dialogues nested and ends silent") do
  PokeAccess::MenuReturn.reset_nesting
  screens = PausePanelSpec::Screens.new
  PausePanelSpec.returns = 0
  screens.back
  eq "coming back from a bare subscreen is one return", PausePanelSpec.returns, 1
  PausePanelSpec.returns = 0
  screens.closing
  eq "a save the menu closes after: its question nested, its end silent", PausePanelSpec.returns, 0
end

# The sprite-button pause menus (Armonia, Africanus) never update the map, which is what keeps the info key on the
# trainer in a pause menu, so they keep it there themselves: on the focused button and back from a subscreen.
Suite.define("sprite-button pause menus: the info key answers with the trainer, back from a subscreen too") do
  sb = PokeAccess::SpriteButtonMenu
  scene = World.stub_scene(:@buttons => [["pokemon", "Pokemon"]])
  PokeAccess::Info.set_info(:item, 1)
  sb.focus(scene, 0)
  eq "on the focused button", PokeAccess::Info.instance_variable_get(:@kind), :trainer
  sb.open!
  begin
    PokeAccess::Info.set_info(:pokemon, :someone)
    sb.returned
    eq "and back from the party", PokeAccess::Info.instance_variable_get(:@kind), :trainer
  ensure
    sb.close!
  end
end

# The world map paints each island only as a drawing; the game names them elsewhere (getIslaName, by one of their
# maps), and that name is said rather than a number; where the function is missing, the number stays.
Suite.define("reminiscencia: the world map says an island by the name the game gives it") do
  PausePanelSpec.load_module("reminiscencia", "menus.rb") unless defined?(PokeAccess::ReminMenu)
  rm = PokeAccess::ReminMenu
  scene = World.stub_scene(:@menu => 0, :@currentisla => 3)
  eq "without the game's function, the number", rm.worldmap_state(scene), [[:isla, 3], PokeAccess::I18n.t(:rem_island, :n => 3)]
  names = { 8 => "Isla Brizo", 67 => "Isla Pontos", 69 => "Isla Glauco", 82 => "Isla Talasa" }
  Object.send(:define_method, :getIslaName) { |id| names[id] || "algún lugar remoto" }
  begin
    eq "with it, the island's own name", rm.worldmap_state(scene), [[:isla, 3], "Isla Glauco"]
    eq "each island by one of its maps", (1..4).map { |i| rm.island_name(i) }, names.values_at(8, 67, 69, 82)
  ensure
    Object.send(:remove_method, :getIslaName)
  end
end
