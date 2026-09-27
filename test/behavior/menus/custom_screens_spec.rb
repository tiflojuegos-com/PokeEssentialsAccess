# Screens of the games' own: notices, card profiles, talismans, the gachapon, a raid database, a wardrobe, badges,
# pickers. The profile readers are evaluated module-only (see pause_panels_spec).
module CustomScreensSpec
  # Evaluates the module block of one of this repo's profile files, the harness's own loading mechanism.
  def self.load_module(game, file)
    path = File.join(Harness::ROOT, "games", game, file)
    eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
  end

  # Evaluates the module block of one of this repo's plugin readers.
  def self.load_plugin_module(file)
    path = File.join(Harness::ROOT, "plugins", file)
    eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
  end

  def self.box(text)
    Struct.new(:text).new(text)
  end

  # Runs the block with Input answering true for the given keys only.
  def self.pressing(*keys)
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| keys.include?(k) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end
end

Input.const_set(:A2, 91) unless Input.const_defined?(:A2)

Suite.define("reminiscencia: the controls notice as painted, its arrows as colons, and the save's play time") do
  CustomScreensSpec.load_module("reminiscencia", "info_screens.rb") unless defined?(PokeAccess::ReminInfoScreens)
  PokeAccess::PaintCapture.arm(:rem_info)
  PokeAccess::PaintCapture.note_positions([["Flechas => Moverse", 320, 40], ["Z => Correr", 320, 78]])
  PokeAccess::ReminInfoScreens.poll
  PokeAccess::ReminInfoScreens.poll
  eq "once, queued", SpeakCapture.log, [["Flechas: Moverse, Z: Correr", false]]
  SpeakCapture.clear
  save = World.stub_scene(:@infowindow => CustomScreensSpec.box("Tiempo real jugado: 01:05"))
  PokeAccess::ReminInfoScreens.save_time(save)
  PokeAccess.say_dialogue("¿Quieres guardar la partida?")
  eq "after the save's question", SpeakCapture.lines, ["¿Quieres guardar la partida?", "Tiempo real jugado: 01:05"]
end

Suite.define("relict: the starter's presentation line is said as it waits") do
  CustomScreensSpec.load_module("relict", "arcy.rb") unless defined?(PokeAccess::RelictArcy)
  scene = World.stub_scene(:@sprites => { "helpwindow" => CustomScreensSpec.box("Ah, Bulbasaur. The Seed Pokémon...") })
  PokeAccess::RelictArcy.starter(scene)
  eq "queued", SpeakCapture.log, [["Ah, Bulbasaur. The Seed Pokémon...", false]]
end

Suite.define("realidea: the vision's points follow its first option, and a faded ability says so") do
  CustomScreensSpec.load_module("realidea", "system_scene.rb") unless defined?(PokeAccess::RealideaSystem)
  t = PokeAccess::I18n
  rs = PokeAccess::RealideaSystem
  $game_variables[50] = 340
  rs.start(rs::MAIN)
  begin
    rs.poll
    eq "the first option, then the points", SpeakCapture.log,
       [[t.t(:rl_sys_heal), true], [t.t(:rl_sys_points, :n => 340), false]]
  ensure
    rs.stop
  end
  $game_switches[142] = true
  rs.start(rs::MOVES)
  begin
    eq "a lit ability by its name", rs.label(1), t.t(:rl_mo_cut)
    eq "a faded one, unavailable", rs.label(2), "#{t.t(:rl_mo_rocksmash)}, #{t.t(:opt_unavailable)}"
  ensure
    rs.stop
  end
end

# After a screen held over Realidea's wheel (hold, unhold) the wheel keeps what it had said, not to cut the game's
# reply; back from its own menus it re-reads.
Suite.define("realidea: the wheel does not say its option again as a held screen ends") do
  CustomScreensSpec.load_module("realidea", "system_scene.rb") unless defined?(PokeAccess::RealideaSystem)
  rs = PokeAccess::RealideaSystem
  rs.start(rs::MAIN)
  begin
    rs.poll
    rs.hold
    rs.unhold
    SpeakCapture.clear
    rs.poll
    silent "after a held screen the wheel keeps what it had said"
    rs.start(rs::MOVES)
    rs.stop
    rs.poll
    spoke "back from one of its own menus, it says where it is", /#{Regexp.escape(PokeAccess::I18n.t(:rl_sys_heal))}/
  ensure
    rs.stop
  end
end

# The game's two tables are stubbed for this suite alone: another suite builds its own FatesCartas.
Suite.define("awakening: a card's profile, its notes and its level bonuses") do
  CustomScreensSpec.load_module("awakening", "fates_extra.rb") unless defined?(PokeAccess::AwakeningFatesExtra)
  t = PokeAccess::I18n
  fx = PokeAccess::AwakeningFatesExtra
  made = [:FatesCartas, :PersonajesFates].reject { |c| Object.const_defined?(c) }
  cartas = Module.new
  cartas.define_singleton_method(:j_citaDesbloqueada?) { |_id, nivel| nivel == 2 }
  cartas.define_singleton_method(:j_citaCompletada?) { |_id, _nivel| false }
  personajes = Module.new
  personajes.define_singleton_method(:resumen_niveles) do
    { 0 => { 1 => { :titulo => "Confianza", :descripcion => "Sube el ataque." },
             3 => { :titulo => "Lealtad", :descripcion => "Cura al final del combate." } },
      1 => {} }
  end
  Object.const_set(:FatesCartas, cartas) if made.include?(:FatesCartas)
  Object.const_set(:PersonajesFates, personajes) if made.include?(:PersonajesFates)
  card = Struct.new(:nombre, :edad, :titulo, :cumpleanios, :aliados, :localidad, :signo, :exp, :exp_t,
                    :rango_visible, :citas_completadas, :index, :info)
                .new("Lana", 17, "Reina", "5 de mayo", ["Guerrera"], "Alba", "Leo", 30, 100, 3, { 0 => true }, 0,
                     ["Le gusta el té.", "Odia la lluvia."])
  old = $Trainer
  begin
    tr = Object.new
    tr.define_singleton_method(:lista_cartas) { [card] }
    $Trainer = tr
    eq "every field under its label, the stars lit, the date done and the one waiting", fx.profile(0),
       [t.t(:awk_prof, :name => "Lana", :age => 17, :title => "Reina", :bday => "5 de mayo", :cls => "Guerrera",
            :loc => "Alba", :sign => "Leo", :exp => 30, :tot => 100, :stars => 3),
        t.t(:awk_prof_dates, :n => 1), t.t(:awk_prof_date_ready), t.t(:awk_prof_keys)].join(". ")
    PokeAccess::Config.verbosity = :brief
    falsy "in brief the profile's keys are left out", fx.profile(0).include?(t.t(:awk_prof_keys))
    PokeAccess::Config.verbosity = :full
    eq "the notes whole under their title", fx.more_info(0),
       [t.t(:awk_info_title), "Le gusta el té.", "Odia la lluvia."].join(". ")
    fx.bonus_open(card)
    CustomScreensSpec.pressing(Input::DOWN) { fx.bonus_poll }
    CustomScreensSpec.pressing(Input::C) { fx.bonus_poll }
    eq "the title and first level, a move, and the description C opens", SpeakCapture.lines,
       ["#{t.t(:awk_bonus_title, :name => 'Lana')}. #{t.t(:awk_bonus_row, :n => 1, :title => 'Confianza')}",
        t.t(:awk_bonus_row, :n => 3, :title => "Lealtad"), "Cura al final del combate."]
    bare = card.dup
    bare.index = 1
    bare.nombre = "Kai"
    SpeakCapture.clear
    fx.bonus_open(bare)
    eq "a character with no bonuses gets the title and that there is nothing yet", SpeakCapture.lines,
       ["#{t.t(:awk_bonus_title, :name => 'Kai')}. #{t.t(:list_empty)}"]
  ensure
    fx.bonus_close
    $Trainer = old
    made.each { |c| Object.send(:remove_const, c) }
  end
end

# The lore window shows five lines and scrolls two at a time, so a step says the two it brings into view.
Suite.define("awakening: the talisman screen's energy and slots, and the lore window by its own text") do
  CustomScreensSpec.load_module("awakening", "fates_screens.rb") unless defined?(PokeAccess::AwakeningFates)
  t = PokeAccess::I18n
  af = PokeAccess::AwakeningFates
  tals = [{ :id => 7, :name => "Talismán del Sol", :symbol => :sol, :lore => "Forjado al alba." }]
  scene = World.stub_scene(:@talismans => tals, :@selected_index => 0, :@info_scroll => 0)
  def scene.unlocked?(_s); true; end
  scene.define_singleton_method(:selected_talisman) { tals[0] }
  $game_variables[399] = 45
  $game_variables[397] = 7
  $game_variables[398] = 0
  af.equip_summary(scene)
  eq "the energy and both slots, queued", SpeakCapture.log,
     [[[t.t(:awk_energy, :n => 45), t.t(:awk_slot, :n => 1, :name => "Talismán del Sol"),
        t.t(:awk_slot, :n => 2, :name => t.t(:awk_slot_empty))].join(". "), false]]
  SpeakCapture.clear
  af.lore_opening(true)
  af.lore(scene)
  af.lore_opening(false)
  eq "the whole lore as the window opens", SpeakCapture.lines, ["Forjado al alba."]

  lines = (1..9).map { |i| "Linea #{i}." }
  bar = Struct.new(:bitmap).new(Struct.new(:width).new(300))
  long = World.stub_scene(:@selected_index => 0, :@info_scroll => 0, :@info_window_height => 110,
                          :@sprites => { "info_window" => bar })
  long.define_singleton_method(:selected_talisman) { { :lore => lines.join(" ") } }
  long.define_singleton_method(:wrap_text) { |_b, _t, _w| lines }
  af.lore_opening(true)
  af.lore(long)
  af.lore_opening(false)
  SpeakCapture.clear
  long.instance_variable_set(:@info_scroll, 2)
  af.lore(long)
  eq "a step down says the lines it brings into view", SpeakCapture.lines, ["Linea 6. Linea 7."]
  SpeakCapture.clear
  long.instance_variable_set(:@info_scroll, 0)
  af.lore(long)
  eq "and a step up the ones above", SpeakCapture.lines, ["Linea 1. Linea 2."]
end

# Royal's prizes and Awakening's Pokemon are named by the game's own message right after the reveal, so the
# reveal says only the tier; Awakening's items go into the bag in silence, so they are named.
Suite.define("gachapon: the counters beside the banner, and each prize by name and tier") do
  t = PokeAccess::I18n
  g = PokeAccess::MagicGachapon
  old = $PokemonGlobal
  begin
    pg = Object.new
    def pg.gachaCoins; 12; end
    $PokemonGlobal = pg
    scene = World.stub_scene(:@sprites => {})
    eq "the three-button copy counts its coins", g.counters(scene, [], 0), [t.t(:gacha_coins, :n => 12)]
  ensure
    $PokemonGlobal = old
  end
  g.reward("Pikachu", 3)
  g.reward("Poción", 2, 5)
  eq "each prize, interrupting the previous", SpeakCapture.log,
     [[t.t(:gacha_prize, :name => "Pikachu", :n => 3), true], [t.t(:gacha_prize_qty, :name => "Poción", :q => 5, :n => 2), true]]
  eq "Awakening hands an item prize over by its symbol, and it is named all the same", g.item_name(:POTION), "Pocion"
  eq "and by its number where a copy does that", g.item_name(1), "Pocion"

  SpeakCapture.clear
  g.item_prize([:POTION, 5, 2])
  g.item_prize([:POTION, 3])
  g.tier(4)
  eq "a prize the game names next says its tier alone, one it does not is named", SpeakCapture.lines,
     [t.t(:gacha_stars, :n => 2), t.t(:gacha_prize, :name => "Pocion", :n => 3), t.t(:gacha_stars, :n => 4)]
end

Suite.define("zud raid database's species page, its data column and every move list") do
  CustomScreensSpec.load_plugin_module("zud_raid_database.rb") unless defined?(PokeAccess::ZudRaidDatabase)
  t = PokeAccess::I18n
  pairs = [["Pikachu", :positions, 434, 10], ["#025", :positions, 477, 46], ["Appears In:", :positions, 383, 217],
           ["Raid Lv. 1", :positions, 389, 245], ["Habitat:", :positions, 434, 318], ["Forest", :positions, 434, 344],
           ["Thunderbolt", :positions, 92, 24], ["Quick Attack", :positions, 92, 41], ["None Found", :positions, 270, 85],
           ["Discharge", :positions, 92, 212], ["Charm", :positions, 270, 212]]
  lists = [t.t(:zud_raid_primary, :list => "Thunderbolt, Quick Attack"), t.t(:zud_raid_secondary, :list => "None Found"),
           t.t(:zud_raid_spread, :list => "Discharge"), t.t(:zud_raid_support, :list => "Charm")]
  eq "the column read with its labels paired, then the four lists under their headings",
     PokeAccess::ZudRaidDatabase.page_text(pairs, nil), (["Pikachu", "#025", "Appears In: Raid Lv. 1", "Habitat: Forest"] + lists).join(". ")

  sp = Object.new
  def sp.type1; :ELECTRIC; end
  def sp.type2; :ELECTRIC; end
  def sp.hasGmax?; true; end
  more = pairs + [["Raid Lv. 2", :positions, 389, 265]]
  eq "the G-Max mark and the types in the places the page draws them, the raid levels kept together",
     PokeAccess::ZudRaidDatabase.page_text(more, sp),
     (["Pikachu", "#025", t.t(:dmax_factor), t.t(:zud_raid_types, :list => "ELECTRIC"), "Appears In: Raid Lv. 1",
       "Raid Lv. 2", "Habitat: Forest"] + lists).join(". ")
end

# The raid database's search panel: a filter's new count is said, the row the cursor returns to queued after it;
# back from the grid the row is read again, back from a species page the species under the cursor.
Suite.define("zud raid database's count is not cut by the row, and coming back is not mute") do
  CustomScreensSpec.load_plugin_module("zud_raid_database.rb") unless defined?(PokeAccess::ZudRaidDatabase)
  rd = PokeAccess::ZudRaidDatabase
  win = Struct.new(:visible, :index, :commands).new(true, 1, ["Show Pokemon", "Raid Level", "Type", "Habitat", "Region", "Exit"])
  scene = World.stub_scene(:@sprites => { "settings" => win })
  rd.open(scene)
  rd.poll
  SpeakCapture.clear
  rd.count("Available Pokemon: 12")
  win.index = 0
  rd.poll
  eq "the new count, then the row the cursor was put back on, both queued", SpeakCapture.log,
     [["Available Pokemon: 12", false], ["Show Pokemon", false]]
  rd.selecting(true)
  rd.species("Pikachu")
  SpeakCapture.clear
  rd.back_on_grid
  eq "back from a species page, the species under the cursor", SpeakCapture.lines, ["Pikachu"]
  rd.selecting(false)
  SpeakCapture.clear
  rd.poll
  eq "back from the grid, the row again", SpeakCapture.lines, ["Show Pokemon"]
  rd.close
  falsy "and closed, the paint hooks let everything through", rd.open?
end

Suite.define("zud raid database's page is a position, said with a new species from medium") do
  CustomScreensSpec.load_plugin_module("zud_raid_database.rb") unless defined?(PokeAccess::ZudRaidDatabase)
  rd = PokeAccess::ZudRaidDatabase
  rd.open(World.stub_scene(:@sprites => {}))
  rd.instance_variable_set(:@page, "Page: 2/3")
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  rd.species("Raichu")
  eq "brief: the species alone", SpeakCapture.lines, ["Raichu"]
  PokeAccess::Config.verbosity = :full
  rd.instance_variable_set(:@page_seen, nil)
  SpeakCapture.clear
  rd.species("Pichu")
  eq "full: with the page it is on", SpeakCapture.lines, ["Pichu. Page: 2/3"]
  rd.close
end

# The arrows to a species' other raid forms are said as the shown form's place among them, where they are drawn,
# from the plugin's own list (the page is drawn before the arrows are set).
Suite.define("zud raid database's page says which of the species' forms it shows, from medium") do
  CustomScreensSpec.load_plugin_module("zud_raid_database.rb") unless defined?(PokeAccess::ZudRaidDatabase)
  t = PokeAccess::I18n
  rd = PokeAccess::ZudRaidDatabase
  data = Struct.new(:species, :id, :type1, :type2)
  pairs = [["Meowth", :positions, 434, 10], ["#052", :positions, 477, 46], ["Alolan Form", :positions, 434, 139]]
  Object.send(:define_method, :pbGetAvailableRaidForms) do |base|
    base == :MEOWTH ? [:MEOWTH, :MEOWTH_1, :MEOWTH_2] : [base]
  end
  begin
    alolan = data.new(:MEOWTH, :MEOWTH_1, :DARK, :DARK)
    truthy "the second of three forms, where the arrows are: under the number, above the form's name",
           rd.page_text(pairs, alolan).include?("#052. #{t.t(:zud_raid_form, :n => 2, :tot => 3)}. Alolan Form")
    truthy "a species with one form has no arrows, and nothing is said for them",
           rd.page_text(pairs, data.new(:PIKACHU, :PIKACHU, :ELECTRIC, :ELECTRIC)).include?("#052. Alolan Form")
    PokeAccess::Config.verbosity = :brief
    truthy "brief: a position, so left out", rd.page_text(pairs, alolan).include?("#052. Alolan Form")
  ensure
    PokeAccess::Config.verbosity = :full
    Object.send(:remove_method, :pbGetAvailableRaidForms)
  end
end

# The raid database's filter list, a command window hidden except while a filter is chosen, is claimed from the
# generic reader while hidden.
Suite.define("zud raid database's hidden filter list is nobody's to read") do
  CustomScreensSpec.load_plugin_module("zud_raid_database.rb") unless defined?(PokeAccess::ZudRaidDatabase)
  rd = PokeAccess::ZudRaidDatabase
  filter = Struct.new(:visible).new(false)
  scene = World.stub_scene(:@sprites => { "filter" => filter })
  rd.open(scene)
  begin
    rd.poll
    truthy "hidden, the filter list is claimed from the generic reader", PokeAccess.dedicated?(filter)
    filter.visible = true
    rd.poll
    falsy "and let go while it shows, for the generic reader to read", PokeAccess.dedicated?(filter)
  ensure
    rd.close
  end
end

# Infinite Fusion's PC fusion mode (setFusing) is said only on a real toggle, not when switched off while off.
Suite.define("infinite fusion: the PC's fusion mode is said when it really toggles") do
  CustomScreensSpec.load_module("infinitefusion_common", "storage_fusion.rb") unless defined?(PokeAccess::IFStorageFusion)
  f = PokeAccess::IFStorageFusion
  t = PokeAccess::I18n
  scene = Object.new
  SpeakCapture.clear
  f.toggle(scene, false)
  silent "switched off before it was ever on, nothing changed"
  f.toggle(scene, true)
  f.toggle(scene, false)
  eq "on, then off", SpeakCapture.lines, [t.t(:if_fuse_on), t.t(:if_fuse_off)]
end

Suite.define("infinite fusion: the wardrobe says what is on after each change") do
  CustomScreensSpec.load_module("infinitefusion_common", "outfits.rb") unless defined?(PokeAccess::IFOutfits)
  t = PokeAccess::I18n
  old = $Trainer
  had = Object.private_method_defined?(:get_hat_by_id) || Object.method_defined?(:get_hat_by_id)
  begin
    tr = Struct.new(:clothes, :hat, :hair).new("casual", "cap_red", nil)
    $Trainer = tr
    Object.send(:define_method, :get_hat_by_id) { |id| id == "cap_red" ? Struct.new(:name).new("Gorra roja") : nil } unless had
    eq "the hat by the name the outfit data gives it", PokeAccess::IFOutfits.item(:hat), "Gorra roja"
    eq "no hairstyle set", PokeAccess::IFOutfits.item(:hair), t.t(:if_outfit_none)
    $Trainer = Struct.new(:hat_color, :hat2_color).new(10, 40)
    eq "a shifted dye is the hat's own", PokeAccess::IFOutfits.hat_hue(nil), 10
    eq "and in Hoenn the second hat's, when the call says so", PokeAccess::IFOutfits.hat_hue(true), 40
  ensure
    $Trainer = old
    Object.send(:remove_method, :get_hat_by_id) unless had
  end
end

# Opalo's card turns to a page of badges drawn as pictures, with the keys that play each earned badge's
# anthem under them. The keys are single letters, and a synthesizer reads Y and I alike. The badges are named as
# the game's own badge ceremony paints them (FANCY_BADGE_NAMES), here Opalo's table.
OPALO_BADGE_NAMES = ["Medalla Corriente", "Medalla Doma", "Medalla Ferro", "Medalla Presa", "Medalla Évoca",
                     "Medalla Descarga", "Medalla Géminis", "Medalla Témpano"]
Suite.define("opalo: the badges page names the badges earned and each anthem's key as a key") do
  CustomScreensSpec.load_module("opalo", "trainer_card.rb") unless defined?(PokeAccess::OpaloCard)
  t = PokeAccess::I18n
  old = $Trainer
  was_rebinds = PokeAccess::Config.rebinds
  added_names = !Object.const_defined?(:FANCY_BADGE_NAMES)
  Object.const_set(:FANCY_BADGE_NAMES, OPALO_BADGE_NAMES) if added_names
  begin
    tr = Object.new
    def tr.badges; [true, false, true]; end
    $Trainer = tr
    eq "the badges earned, their keys, and the way back", PokeAccess::OpaloCard.badges_text,
       [t.t(:tcard_badge_list, :list => "Corriente, Ferro"),
        t.t(:tcard_anthem_keys, :keys => "#{t.t(:key_other, :n => 'Q')}, #{t.t(:key_other, :n => 'E')}"),
        t.t(:tcard_to_main, :key => "C")].join(". ")
    def tr.badges; [false, false, false, false, true]; end
    eq "the fifth badge is named as the game writes it, accent and all",
       PokeAccess::OpaloCard.badges_text.split(". ")[0], t.t(:tcard_badge_list, :list => "Évoca")
    def tr.badges; [false, false, false, false, false, true]; end
    truthy "the sixth badge's key is named so a synthesizer does not read it as the eighth's",
           PokeAccess::OpaloCard.badges_text.include?(t.t(:key_other, :n => t.t(:key_letter_y)))
    def tr.badges; [false, false, true, true]; end
    PokeAccess::Config.rebinds = { :r => 0x4B }
    eq "the R key is the R button here: rebound, its anthem is on the bound key, and a key of its own stays",
       PokeAccess::OpaloCard.badges_text.split(". ")[1],
       t.t(:tcard_anthem_keys, :keys => "#{t.t(:key_other, :n => 'E')}, #{t.t(:key_other, :n => 'K')}")
    PokeAccess::Config.rebinds = {}
    def tr.badges; []; end
    eq "none earned, no keys", PokeAccess::OpaloCard.badges_text, [t.t(:tr_badges, :n => 0), t.t(:tcard_to_main, :key => "C")].join(". ")
    PokeAccess::Config.verbosity = :brief
    eq "in brief the way back, a key hint, is left out", PokeAccess::OpaloCard.badges_text, t.t(:tr_badges, :n => 0)
    Object.send(:remove_const, :FANCY_BADGE_NAMES) if added_names
    def tr.badges; [true, true]; end
    eq "with no table to name them by, the badges earned are counted", PokeAccess::OpaloCard.badges_text,
       t.t(:tr_badges, :n => 2)
  ensure
    Object.send(:remove_const, :FANCY_BADGE_NAMES) if added_names && Object.const_defined?(:FANCY_BADGE_NAMES)
    $Trainer = old
    PokeAccess::Config.rebinds = was_rebinds
  end
end

# The data page says the stars the card draws (estrellas_1..4), as their count alone: the card paints no most, and
# with none (estrellas_0 is blank) nothing.
Suite.define("opalo: the data page says the stars the card draws, and nothing when it draws none") do
  CustomScreensSpec.load_module("opalo", "trainer_card.rb") unless defined?(PokeAccess::OpaloCard)
  old = $Trainer
  begin
    $Trainer = Struct.new(:name, :money, :pokedexOwned, :pokedexSeen).new("Rojo", 100, 1, 2)
    $game_variables[250] = 0
    parts = PokeAccess::OpaloCard.main_text.split(", ")
    eq "no stars drawn, none said", parts.grep(/Estrella|estrella|Rango/), []
    $game_variables[250] = 3
    parts = PokeAccess::OpaloCard.main_text.split(", ")
    eq "three drawn, three said, with no most the card never paints", parts.grep(/Estrella|estrella|Rango/),
       ["Estrellas: 3"]
  ensure
    $Trainer = old
    $game_variables.clear
  end
end

Suite.define("awakening: a talisman's effect waits for full, and the info key keeps it") do
  CustomScreensSpec.load_module("awakening", "fates_screens.rb") unless defined?(PokeAccess::AwakeningFates)
  af = PokeAccess::AwakeningFates
  tals = [{ :id => 7, :name => "Talismán del Sol", :symbol => :sol, :description => "Sube el ataque." }]
  scene = World.stub_scene(:@talismans => tals, :@selected_index => 0)
  def scene.unlocked?(_s); true; end
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :awk_talisman)
    SpeakCapture.clear
    af.talisman(scene)
    SpeakCapture.last
  end
  eq "brief: the talisman's name", rows[0], "Talismán del Sol"
  eq "medium: and its place", rows[1], PokeAccess::I18n.t(:list_entry, :name => "Talismán del Sol", :n => 1, :tot => 1)
  eq "full: and its effect", rows[2], "#{rows[1]}. Sube el ataque."
  eq "the info key keeps the effect", PokeAccess::Info.info_text, "Talismán del Sol. Sube el ataque."
end

Suite.define("armonia: the DexNav names a species, its state from medium, and keeps the whole zone on the info key") do
  CustomScreensSpec.load_module("armonia", "dexnav.rb") unless defined?(PokeAccess::ArmoniaDexNav)
  t = PokeAccess::I18n
  dn = PokeAccess::ArmoniaDexNav
  util = PokeAccess::Util
  seen = util.method(:dex_seen?)
  owned = util.method(:dex_owned?)
  util.define_singleton_method(:dex_seen?) { |sp| sp != 3 }
  util.define_singleton_method(:dex_owned?) { |sp| sp == 1 }
  begin
    name = PokeAccess::Data.species_name(1)
    rows = vb_levels { dn.species_label(1) }
    eq "brief: the species by name", rows[0], name
    eq "medium: and caught", rows[1], "#{name}, #{t.t(:dex_caught)}"
    eq "one never seen stays unknown at any level", vb_levels { dn.species_label(3) }[0], t.t(:dex_unknown)
    scene = World.stub_scene(:@visibleZones => [[0, "dexnavtierra"]], :@index => 0, :@encounterArray => [1, 2])
    PokeAccess::Config.verbosity = :brief
    line = dn.encounters(scene).to_s
    PokeAccess::Config.verbosity = :full
    truthy "a zone in brief names its species without their state", !line.include?(t.t(:dex_caught))
    truthy "which the info key keeps", PokeAccess::Info.info_text.to_s.include?(t.t(:dex_caught))
    page = dn.rewards(scene)
    eq "flipped to the rewards page, the info key says that page and the rule it paints", PokeAccess::Info.info_text,
       PokeAccess.sentences([page, t.t(:dxn_rewards_rule)])
  ensure
    util.define_singleton_method(:dex_seen?, seen)
    util.define_singleton_method(:dex_owned?, owned)
  end
end

# The pictures behind the DexNav paint the zone's name ("Tierra"), the arrows to the other zones and the keys:
# "Z RECOMPENSA, X SALIR" on a zone, "Z POKEMON, X SALIR" and the rule of the rewards on the rewards page.
Suite.define("armonia: the DexNav says the zone as painted, its place among the zones, and the keys each page paints") do
  CustomScreensSpec.load_module("armonia", "dexnav.rb") unless defined?(PokeAccess::ArmoniaDexNav)
  t = PokeAccess::I18n
  dn = PokeAccess::ArmoniaDexNav
  util = PokeAccess::Util
  seen = util.method(:dex_seen?)
  owned = util.method(:dex_owned?)
  util.define_singleton_method(:dex_seen?) { |_sp| false }
  util.define_singleton_method(:dex_owned?) { |_sp| false }
  begin
    zones = [[0, "dexnavtierra"], [1, "dexnavsurf"], [2, "dexnavrio"]]
    land = World.stub_scene(:@visibleZones => zones, :@index => 0, :@num_enc => 1, :@encounterArray => [])
    truthy "the land zone is named as its picture paints it", dn.page(land).start_with?(t.t(:dxn_zone_land))
    eq "and that is Tierra", t.t(:dxn_zone_land), "Tierra"
    surf = World.stub_scene(:@visibleZones => zones, :@index => 1, :@num_enc => 3, :@encounterArray => [4])
    rows = vb_levels { dn.encounters(surf) }
    one = t.t(:dxn_list, :zone => t.t(:dxn_zone_surf), :n => 1, :names => t.t(:dex_unknown))
    placed = t.t(:dxn_list, :zone => t.t(:list_entry, :name => t.t(:dxn_zone_surf), :n => 2, :tot => 3), :n => 1,
                 :names => t.t(:dex_unknown))
    eq "brief: the zone alone", rows[0], one
    eq "medium and full: its place among the three the arrows move between", rows[1..2], [placed, placed]
    PokeAccess::Config.verbosity = :brief
    dn.encounters(surf)
    PokeAccess::Config.verbosity = :full
    eq "the info key keeps the place at every level", PokeAccess::Info.info_text, placed
    rows = vb_levels { dn.page(surf) }
    eq "brief: no keys", rows[0], one
    eq "medium and full: the keys the zone's picture paints", rows[1..2],
       [PokeAccess.sentences([placed, t.t(:dxn_keys_species)])] * 2
    rewards = World.stub_scene(:@visibleZones => zones, :@index => 0, :@num_enc => 3, :@showPageRewards => true,
                               :@mapid => 999)
    body = dn.rewards(rewards)
    rows = vb_levels { dn.page(rewards) }
    eq "the rewards page in brief: the rewards alone", rows[0], body
    eq "medium: and its keys", rows[1], PokeAccess.sentences([body, t.t(:dxn_keys_rewards)])
    eq "full: the rule it paints too", rows[2], PokeAccess.sentences([body, t.t(:dxn_rewards_rule), t.t(:dxn_keys_rewards)])
  ensure
    util.define_singleton_method(:dex_seen?, seen)
    util.define_singleton_method(:dex_owned?, owned)
  end
end

# The rewards page draws each zone's reward on that zone's base picture (0172_dexnav.rb, loadCurrentPage), tables
# shaped as the script's DEXNAV_ZONES and DEXNAV_REWARDS for a map with land and fishing rewards.
Suite.define("armonia: the DexNav's rewards page names each reward's zone as the zone pages do") do
  CustomScreensSpec.load_module("armonia", "dexnav.rb") unless defined?(PokeAccess::ArmoniaDexNav)
  t = PokeAccess::I18n
  dn = PokeAccess::ArmoniaDexNav
  tables = { :DEXNAV_ZONES => [[0, "dexnavtierra", "BaseTierra"], [2, "dexnavsurf", "BaseSurf"], [5, "dexnavrio", "BasePesca"]],
             :DEXNAV_REWARDS => { 3 => [[0, :POTION, 3], [5, :POKEBALL, 3], :FOCUSBAND] } }
  made = tables.keys.reject { |c| Object.const_defined?(c) }
  made.each { |c| Object.const_set(c, tables[c]) }
  old = $PokemonGlobal
  begin
    glob = Object.new
    glob.define_singleton_method(:getDexNavRewards) { |_map| { 0 => true } }
    $PokemonGlobal = glob
    land = "#{t.t(:dxn_reward_line, :item => dn.item_label(:POTION), :n => 3)}, #{t.t(:dxn_claimed)}"
    fish = t.t(:dxn_reward_line, :item => dn.item_label(:POKEBALL), :n => 3)
    list = "#{t.t(:dxn_zone_land)}: #{land}, #{t.t(:dxn_zone_fish)}: #{fish}"
    eq "each reward under its zone's name, the claimed one marked", dn.rewards_text(World.stub_scene(:@mapid => 3)),
       t.t(:dxn_rewards, :taken => 1, :tot => 2, :list => list, :final => dn.item_label(:FOCUSBAND))
  ensure
    $PokemonGlobal = old
    made.each { |c| Object.send(:remove_const, c) }
  end
end

Suite.define("reminiscencia: the upgrade tree says a stat and its price, the bonus from medium") do
  CustomScreensSpec.load_module("reminiscencia", "extras.rb") unless defined?(PokeAccess::ReminExtras)
  t = PokeAccess::I18n
  saved = [$Trainer, $PokemonBag]
  begin
    $Trainer = Struct.new(:buffStatFriend).new([[500, 10], [800, 5]])
    bag = Object.new
    def bag.coins=(n); @coins = n; end
    def bag.pbQuantity(item); item == :COIN ? @coins : 0; end
    bag.coins = 600
    $PokemonBag = bag
    scene = World.stub_scene(:@selec => 0)
    name = t.t(:rem_st_atk)
    coins = t.t(:rem_coins, :n => 600)
    rows = vb_levels do
      PokeAccess::Cursor.reset(scene, :rem_tree)
      SpeakCapture.clear
      PokeAccess::ReminExtras.scroll_tree(scene)
      SpeakCapture.last
    end
    eq "brief: the stat, what the next level costs and, as it opens, the coins", rows[0],
       [name, t.t(:rem_tree_cost, :cost => 500), coins].join(", ")
    eq "medium: with its bonus", rows[1],
       [name, t.t(:rem_tree_bonus, :pct => 10), t.t(:rem_tree_cost, :cost => 500), coins].join(", ")
    eq "the info key keeps the whole row", PokeAccess::Info.info_text, rows[1]
    SpeakCapture.clear
    scene.instance_variable_set(:@selec, 1)
    PokeAccess::ReminExtras.scroll_tree(scene)
    eq "a move says no coins, and a price above them is marked as the red cost is", SpeakCapture.last,
       [t.t(:rem_st_spatk), t.t(:rem_tree_bonus, :pct => 5), t.t(:rem_tree_cost, :cost => 800), t.t(:rem_tree_short)].join(", ")
    bag.coins = 100
    $Trainer.buffStatFriend[1] = [900, 8]
    SpeakCapture.clear
    PokeAccess::ReminExtras.scroll_tree(scene, true)
    truthy "a purchase says the coins left", SpeakCapture.last.to_s.end_with?(t.t(:rem_coins, :n => 100))
  ensure
    $Trainer, $PokemonBag = saved
  end
end

# The help list paints a section past the ones unlocked as "???" (HelpUI/unknown, while ayudasUI is shorter than
# its index); it is said as the word for an unknown one, still with its lock and its place in the list.
Suite.define("reminiscencia: a help section painted as question marks is an unknown one") do
  CustomScreensSpec.load_module("reminiscencia", "extras.rb") unless defined?(PokeAccess::ReminExtras)
  t = PokeAccess::I18n
  saved = $Trainer
  begin
    $Trainer = Struct.new(:ayudasUI).new(["controles", "pokemon"])
    scene = World.stub_scene(:@index => 1)
    SpeakCapture.clear
    PokeAccess::ReminExtras.help_section(scene)
    eq "an unlocked section by its name", SpeakCapture.last, PokeAccess::Verbosity.list_entry(t.t(:rem_help_pokemon), 2, 10)
    scene.instance_variable_set(:@index, 2)
    SpeakCapture.clear
    PokeAccess::ReminExtras.help_section(scene)
    eq "one past the unlocked ones as unknown, and locked", SpeakCapture.last,
       PokeAccess::Verbosity.list_entry("#{t.t(:rem_help_unknown)}, #{t.t(:rem_help_locked)}", 3, 10)
  ensure
    $Trainer = saved
  end
end

# Two of the help buttons paint other words than the topic they were first named by: option6.png says "Sobre los
# combates con refuerzos" and option8.png "Cartas".
Suite.define("reminiscencia: the help sections say the words their buttons paint") do
  CustomScreensSpec.load_module("reminiscencia", "extras.rb") unless defined?(PokeAccess::ReminExtras)
  saved = $Trainer
  begin
    $Trainer = Struct.new(:ayudasUI).new(%w[controles pokemon objetos capturas phione ubicaciones auxilio alarmado cartas])
    said = [6, 8].map do |i|
      SpeakCapture.clear
      PokeAccess::ReminExtras.help_section(World.stub_scene(:@index => i))
      SpeakCapture.last.to_s
    end
    truthy "the SOS battles section", said[0].start_with?("Combates con refuerzos")
    truthy "and the cards", said[1].start_with?("Cartas")
  ensure
    $Trainer = saved
  end
end

# The world map's place panel paints "???" for a place never visited; the word for it is said, since a screen reader
# says nothing for the marks.
Suite.define("reminiscencia: the world map's unvisited place is said as a word") do
  CustomScreensSpec.load_module("reminiscencia", "extras.rb") unless defined?(PokeAccess::ReminExtras)
  bmp = Object.new
  panel = Struct.new(:bitmap).new(bmp)
  scene = World.stub_scene(:@sprites => { "info" => panel })
  ex = PokeAccess::ReminExtras
  ex.help_on(scene)
  begin
    SpeakCapture.clear
    ex.help_text(bmp, [["???", 324, 228, 2]])
    eq "the marks as the word", SpeakCapture.lines, [PokeAccess::I18n.t(:rem_map_unvisited)]
    ex.help_on(scene)
    SpeakCapture.clear
    ex.help_text(bmp, [["Pueblo Brizo", 324, 228, 2]])
    eq "a visited place by its name", SpeakCapture.lines, ["Pueblo Brizo"]
  ensure
    ex.help_off
  end
end

Suite.define("reminiscencia: the species picker's panel is said in full, and the info key keeps it below") do
  CustomScreensSpec.load_module("reminiscencia", "picker.rb") unless defined?(PokeAccess::ReminPicker)
  rp = PokeAccess::ReminPicker
  bmp = Object.new
  rows = [["BULBASAUR", 10, 10], ["Tipo: Planta", 10, 40], ["Ataque 49", 10, 70]]
  PokeAccess::Config.verbosity = :medium
  begin
    rp.watch do
      rp.note(bmp, rows)
      SpeakCapture.clear
      rp.flush
    end
    keys = rp.keys_line
    eq "medium: the panel is not said, only the keys the picker paints", SpeakCapture.lines, [keys]
    eq "and the info key has it", PokeAccess::Info.info_text, "Tipo: Planta, Ataque 49"
    PokeAccess::Config.verbosity = :full
    rp.watch do
      rp.note(bmp, rows)
      SpeakCapture.clear
      rp.flush
    end
    eq "full: the panel, then the keys", SpeakCapture.lines, ["Tipo: Planta, Ataque 49", keys]
  ensure
    PokeAccess::Config.verbosity = :full
  end
end

class PickBlessing
  def updateCursor; :moved; end
  def swapCard; :swapped; end

  # The legend as the game paints it: the key pictures first, then the texts and the coins, at its coordinates.
  def drawMaintext
    pbDrawImagePositions(nil, [["Graphics/Pictures/Blessings/A", 400, 286, 0, 0, -1, -1],
                               ["Graphics/Pictures/Blessings/C", 304, 358, 0, 0, -1, -1],
                               ["Graphics/Pictures/Blessings/Z", 352, 322, 0, 0, -1, -1],
                               ["Graphics/Pictures/Blessings/coinBox", 474, 250, 0, 0, -1, -1]])
    pbDrawTextPositions(nil, [["Ver porcentajes", 448, 290, 0], ["Escoger bendición", 352, 362, 0],
                              ["Resetear cartas", 400, 326, 0], ["Monedas: 12", 614, 254, 1]])
  end
end
BLESSINGS_HASH = { :B1 => [1, 2, nil, "Sube el ataque."] } unless defined?(BLESSINGS_HASH)
load File.join(Harness::ROOT, "games", "reminiscencia", "blessings.rb")

Suite.define("reminiscencia: a blessing says what it does, its rarity from medium and its category in full") do
  t = PokeAccess::I18n
  scene = PickBlessing.new
  scene.instance_variable_set(:@blessings, [:B1])
  scene.instance_variable_set(:@index, 0)
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :bless)
    SpeakCapture.clear
    scene.updateCursor
    SpeakCapture.last
  end
  rarity = t.t(:bless_rarity, :n => 3)
  eq "brief: what the card does", rows[0], "Sube el ataque."
  eq "medium: its rarity first", rows[1], "#{rarity}. Sube el ataque."
  eq "full: its category too", rows[2], "#{t.t(:rem_bless_power)}. #{rarity}. Sube el ataque."
  eq "the info key keeps the whole card", PokeAccess::Info.info_text, rows[2]
end

# The chooser's legend (drawMaintext): the coins it paints, then each action beside its key picture while key hints
# are said; as the chooser opens it waits for the first card, after a reset it follows the new cards.
Suite.define("reminiscencia: the blessing legend, its coins and keys, after the card") do
  t = PokeAccess::I18n
  scene = PickBlessing.new
  scene.instance_variable_set(:@blessings, [:B1])
  scene.instance_variable_set(:@index, 0)
  keys = ["A: Ver porcentajes", "Z: Resetear cartas", "C: Escoger bendición"].map do |s|
    k, a = s.split(": ")
    t.t(:rem_key_action, :key => k, :action => a)
  end
  legend = (["Monedas: 12"] + keys).join(". ")
  SpeakCapture.clear
  scene.drawMaintext
  silent "painted before the cards, it waits"
  scene.swapCard
  eq "the card first, then the coins and each key with its action", SpeakCapture.lines.length, 2
  eq "the legend in reading order", SpeakCapture.lines[1], legend
  SpeakCapture.clear
  scene.swapCard
  scene.drawMaintext
  eq "after a reset, the legend follows the new cards", SpeakCapture.lines.last, legend
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  scene.drawMaintext
  eq "without key hints, the coins alone", SpeakCapture.lines, ["Monedas: 12"]
end

# gettinginput runs pressBall on C, as the plugin does: the picture fades in and the Yes/No window opens inside it.
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
load File.join(Harness::ROOT, "plugins", "starter_selection.rb")

module CustomScreensSpec
  # A starter with two types, as the gen-6 data reads them off the Pokemon.
  def self.starter_poke
    pk = Poke.build(:name => "Bulbasaur", :species => 1)
    pk.define_singleton_method(:type1) { 12 }
    pk.define_singleton_method(:type2) { 3 }
    pk
  end
end

Suite.define("starter selection: moving says the starter's name alone, at every level, and the info key has the rest") do
  pk = CustomScreensSpec.starter_poke
  scene = PokemonStarterSelection.new
  scene.instance_variable_set(:@data, { "pkmn_1" => pk })
  scene.instance_variable_set(:@select, 1)
  types = PokeAccess::Data.pokemon_types(pk).join("/")
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :starter_sel)
    SpeakCapture.clear
    scene.gettinginput
    SpeakCapture.last
  end
  eq "the name is the picture under the cursor, at every level", rows, ["Bulbasaur", "Bulbasaur", "Bulbasaur"]
  eq "Ctrl+T has the row as full says it, the name", PokeAccess::Info.row_text, "Bulbasaur"
  falsy "the types stay out while the screen hides them", PokeAccess::Info.row_text.include?(types)
end

Suite.define("starter selection: choosing says the types it shows, then the Yes/No inside pressBall is read") do
  pk = CustomScreensSpec.starter_poke
  scene = PokemonStarterSelection.new
  scene.instance_variable_set(:@data, { "pkmn_1" => pk })
  scene.instance_variable_set(:@pokemon, pk)
  scene.instance_variable_set(:@select, 1)
  types = PokeAccess::Data.pokemon_types(pk).join("/")
  truthy "the stand-in Pokemon has types to show", !types.empty?
  scene.gettinginput
  scene.chooses = true
  SpeakCapture.clear
  scene.gettinginput
  eq "the types pressBall fades in, queued, then the confirm window's first option",
     SpeakCapture.log, [[types, false], ["Sí", false]]
  eq "and Ctrl+T has the name with them", PokeAccess::Info.row_text, "Bulbasaur, #{types}"
  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  scene.gettinginput
  PokeAccess::Config.verbosity = :full
  eq "brief leaves the types out, not the window", SpeakCapture.lines, ["Sí"]
end
