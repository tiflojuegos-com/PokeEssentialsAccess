# Infinite Fusion Hoenn's own screens (starters, PokeNav apps and launcher, challenges, quests) at their readings'
# levels, gamedata pass. The stand-ins come before the profile files load: a hook on a missing class binds nothing.
class StartersSelectionScene
  def updateStarterSelectionGraphics
    pbDrawTextPositions(nil, @paint) if @paint
    :drawn
  end
end

class PokeNavAppScene
  def hover(_id); :hovered; end
  def pbStartScene(_buttons = []); :started; end
  def pbEndScene; :ended; end
end

# The contacts list: zone headers among the trainers, opened on a trainer.
class ContactsAppScene < PokeNavAppScene
  def pbStartScene(buttons, index)
    @buttons = buttons
    @index = index
    :started
  end
end

class ContactsAppLocationButton
  def initialize(text); @text = text; end
end

# A trainer row; its hover clears the new flag and starts fading the icon, as the game's does.
class ContactsAppTrainerButton
  def initialize(text, trade = false, fresh = false); @text = text; @is_trade_available = trade; @is_new = fresh; end
  def hover
    return unless @is_new
    @is_new = false
    @fading_new_icon = Struct.new(:disposed?).new(false)
  end
end

class ContactsAppInfoPageScene
  attr_accessor :trainer
  def showFriendshipIcons; :shown; end
end

# The HUD writer, defined once for every spec that paints through it: redefining it would drop the wraps on it.
unless Kernel.respond_to?(:pbDisplayText)
  def Kernel.pbDisplayText(_message, _x, _y, _z = nil, _base = nil, _shadow = nil, _align = 2); nil; end
end

# The PokeRadar: each hover repaints its header labels as HUD text (name, battery, zone), then the row's, then calls
# up to the base hover, as the game's does.
class PokeRadarAppScene < PokeNavAppScene
  def displayTextElements
    Kernel.pbDisplayText("PokeRadar", 256, 8)
    Kernel.pbDisplayText("12/1000", 450, 8)
    Kernel.pbDisplayText("Route 104 (Grass)", 256, 40)
  end
  def hover(id)
    displayTextElements
    Kernel.pbDisplayText(id.to_s, 256, 240)
    super
  end
end

class FusionQuizAppScene < PokeNavAppScene
  def pbStartScene(buttons = nil)
    @buttons = buttons
    @index = 0
    :started
  end
end

class PokemonChallenges_Scene
  def pbUpdate; :updated; end
  def pbEndScene; :ended; end
end

# The launcher's rearrange mode, over the harness's own launcher: a first press lifts the app, a second swaps it.
class PokemonPokegear_Scene
  def swap_apps
    if @held_index
      @commands[@index], @commands[@held_index] = @commands[@held_index], @commands[@index]
      @buttons = @commands.map { |c| PokegearButton.new(c[1]) }
      @held_index = nil
    else
      @held_index = @index
    end
  end
end

class Questlog
  def draw_main_text; end
  def switch_button; end
  def move_selection; end
  def show_quest_list; end
  def redraw_main_screen; end
  def draw_quest_details(_q = nil); end
  def can_switch_mode?; true; end
end

class QuestMapPopup
  attr_reader :seen_info
  def initialize(quests); @quests = quests; @index = 0; @location_name = "Petalburgo"; end
  def run
    PokeAccess::Keys.run_frame_pollers
    @seen_info = PokeAccess::Info.info_text
    :closed
  end
end

%w[starters pokenav quests].each do |f|
  load File.expand_path("../../../games/infinitefusion_hoenn/#{f}.rb", File.dirname(__FILE__))
end

Suite.define("ifh starters: a starter by name, its place in the row while positions are said") do
  scene = StartersSelectionScene.new
  scene.instance_variable_set(:@starters_species, [:TREECKO, :TORCHIC, :MUDKIP])
  scene.instance_variable_set(:@index, 1)
  name = PokeAccess::Data.species_name(:TORCHIC)
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :if2_starter)
    SpeakCapture.clear
    PokeAccess::IF2Starters.focus(scene)
    SpeakCapture.last
  end
  eq "brief: the name", rows[0], name
  eq "medium and full: with its place", rows[1, 2], [PokeAccess::I18n.t(:list_entry, :name => name, :n => 2, :tot => 3)] * 2
end

Suite.define("ifh pokeradar: a species at the Pokedex reading's level, the whole row on the info key") do
  t = PokeAccess::I18n
  scene = PokeNavAppScene.new
  scene.instance_variable_set(:@seenPokemon, [:ZIGZAGOON])
  def scene.get_rarity_flavor_text(_sp); "Common"; end
  def scene.get_energy_for_scan(_sp); 30; end
  btn = Struct.new(:id).new(:ZIGZAGOON)
  name = PokeAccess::Data.species_name(:ZIGZAGOON)
  rows = vb_levels { PokeAccess::IF2PokeNav.radar_text(scene, btn) }
  eq "brief: the species", rows[0], name
  eq "medium: its rarity and what a scan costs", rows[1], [name, "Common", t.t(:if2_radar_battery, :n => 30)].join(", ")
  eq "and full says the same", rows[2], rows[1]
  PokeAccess::Config.verbosity = :brief
  PokeAccess::IF2PokeNav.radar_text(scene, btn)
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the whole row", PokeAccess::Info.info_text, rows[2]
  unseen = Struct.new(:id).new(:WURMPLE)
  eq "an unseen species is unknown", PokeAccess::IF2PokeNav.radar_text(scene, unseen), t.t(:if2_radar_unknown)
  eq "and so is the info key, not the species before", PokeAccess::Info.info_text, t.t(:if2_radar_unknown)
  scene.pbEndScene
  eq "closing the app takes it off the info key", PokeAccess::Info.info_text, nil
end

Suite.define("ifh challenges: a challenge at the quest reading's level, its reward on the info key") do
  t = PokeAccess::I18n
  ch = Struct.new(:description, :money_reward, :item_reward, :completed)
  claim = Struct.new(:can_claim_reward)
  scene = PokemonChallenges_Scene.new
  scene.instance_variable_set(:@challenges, [ch.new("Atrapa 3 Pokémon", 500, [], true), ch.new("Gana 2 combates", 300, [], false)])
  scene.instance_variable_set(:@buttons, [claim.new(true), claim.new(false)])
  scene.instance_variable_set(:@index, 0)
  head = t.t(:list_entry, :name => "Atrapa 3 Pokémon", :n => 1, :tot => 2)
  whole = t.t(:if2_ch_collect, :n => 500)
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :if2_challenge)
    SpeakCapture.clear
    PokeAccess::IF2Challenges.focus(scene)
    SpeakCapture.last
  end
  eq "brief: what it asks for", rows[0], "Atrapa 3 Pokémon"
  eq "medium: its place, and that its reward is ready", rows[1], "#{head}. #{t.t(:if2_ch_ready)}"
  eq "full: the reward itself", rows[2], "#{head}. #{whole}"
  eq "the info key keeps the reward", PokeAccess::Info.info_text, "Atrapa 3 Pokémon. #{whole}"
  PokeAccess::Config.verbosity = :medium
  scene.instance_variable_set(:@index, 1)
  SpeakCapture.clear
  PokeAccess::IF2Challenges.focus(scene)
  eq "medium: a reward still to earn is not announced", SpeakCapture.last,
     t.t(:list_entry, :name => "Gana 2 combates", :n => 2, :tot => 2)
  PokeAccess::Config.verbosity = :full
  scene.pbEndScene
  eq "closing the app takes it off the info key", PokeAccess::Info.info_text, nil
end

Suite.define("ifh quests: a quest by name, whether it is done from medium, and the whole row on the info key") do
  t = PokeAccess::I18n
  q = Struct.new(:name, :completed)
  scene = Questlog.new
  scene.instance_variable_set(:@filtered_quests, [q.new("Busca el gato", false), q.new("Lleva la carta", true)])
  scene.instance_variable_set(:@quest_list_menu_index, 1)
  scene.instance_variable_set(:@main_menu_index, 0)
  whole = t.t(:qu_line, :name => "Lleva la carta", :status => t.t(:qu_status_done))
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :if2_quest)
    SpeakCapture.clear
    PokeAccess::IF2Quests.quest(scene)
    SpeakCapture.last
  end
  eq "brief: the quest's name", rows[0], "Lleva la carta"
  eq "medium: whether it is done, and its place", rows[1], t.t(:list_entry, :name => whole, :n => 2, :tot => 2)
  eq "the info key keeps the whole row", PokeAccess::Info.info_text, whole
  eq "and the quest's page still says it whole", PokeAccess::IF2Quests.quest_line(q.new("Lleva la carta", true)), whole
end

Suite.define("ifh quest panel: a main quest is marked from medium, and the row leaves the info key with the panel") do
  t = PokeAccess::I18n
  q = Struct.new(:name, :type)
  PokeAccess::Config.verbosity = :brief
  begin
    popup = QuestMapPopup.new([q.new("Busca el gato", :MAIN_QUEST)])
    SpeakCapture.clear
    popup.run
    truthy "brief: the quest's name without the mark", SpeakCapture.lines.include?("Busca el gato")
    eq "while the panel is up the info key has the whole row", popup.seen_info, "Busca el gato, #{t.t(:qmp_main)}"
    eq "and once it closes, nothing of it", PokeAccess::Info.info_text, nil
    PokeAccess::Config.verbosity = :medium
    SpeakCapture.clear
    QuestMapPopup.new([q.new("Busca el gato", :MAIN_QUEST)]).run
    truthy "medium: with the mark and its place",
           SpeakCapture.lines.include?(t.t(:list_entry, :name => "Busca el gato, #{t.t(:qmp_main)}", :n => 1, :tot => 1))
    SpeakCapture.clear
    QuestMapPopup.new([q.new("Frena a Magma", :MAGMA_QUEST)]).run
    truthy "a Magma quest by its dark red",
           SpeakCapture.lines.include?(t.t(:list_entry, :name => "Frena a Magma, #{t.t(:if2_qt_magma)}", :n => 1, :tot => 1))
    SpeakCapture.clear
    QuestMapPopup.new([q.new("Limpia la ruta", :FIELD_QUEST)]).run
    truthy "and a field quest, painted white, with no mark",
           SpeakCapture.lines.include?(t.t(:list_entry, :name => "Limpia la ruta", :n => 1, :tot => 1))
  ensure
    PokeAccess::Config.verbosity = :full
  end
end

Suite.define("ifh starters: the category line painted under the starter from medium, and the shiny mark in full") do
  t = PokeAccess::I18n
  scene = StartersSelectionScene.new
  scene.instance_variable_set(:@starters_species, [:TREECKO, :TORCHIC, :MUDKIP])
  scene.instance_variable_set(:@starter_pokemon, [Poke.build, Poke.build(:shiny => true), Poke.build])
  scene.instance_variable_set(:@index, 1)
  scene.instance_variable_set(:@paint, [["Torchic", 156, 10], ["Chick Pokemon", 156, 40]])
  name = PokeAccess::Data.species_name(:TORCHIC)
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :if2_starter)
    SpeakCapture.clear
    scene.updateStarterSelectionGraphics
    SpeakCapture.last
  end
  eq "brief: the name", rows[0], name
  eq "medium: the painted category line and its place", rows[1],
     t.t(:list_entry, :name => "#{name}, Chick Pokemon", :n => 2, :tot => 3)
  eq "full: whether its sprite is shiny", rows[2],
     t.t(:list_entry, :name => "#{name}, Chick Pokemon, #{t.t(:pk_shiny)}", :n => 2, :tot => 3)
end

Suite.define("ifh pokeradar: the first row leads with the header's name, battery and zone; later rows do not") do
  scene = PokeRadarAppScene.new
  scene.instance_variable_set(:@seenPokemon, [:ZIGZAGOON, :WURMPLE])
  scene.instance_variable_set(:@buttons, [Struct.new(:id).new(:ZIGZAGOON), Struct.new(:id).new(:WURMPLE)])
  scene.instance_variable_set(:@index, 0)
  SpeakCapture.clear
  scene.hover(:ZIGZAGOON)
  first = SpeakCapture.log
  eq "one read on opening, interrupting the HUD lines it covers", first.length, 1
  truthy "and led by the labels the header painted, as painted",
         first[0][0].index("PokeRadar. 12/1000. Route 104 (Grass). ") == 0 && first[0][1] == true
  scene.instance_variable_set(:@index, 1)
  SpeakCapture.clear
  scene.hover(:WURMPLE)
  truthy "a move reads the row alone", SpeakCapture.log.length == 1 && SpeakCapture.last.index("PokeRadar").nil?
end

Suite.define("ifh contacts: a zone's name on entering it, the trainers counted alone and their row icons") do
  t = PokeAccess::I18n
  joey = ContactsAppTrainerButton.new("Youngster Joey", true, true)
  buttons = [ContactsAppLocationButton.new("Favorites"), joey, ContactsAppTrainerButton.new("Lass Ana"),
             ContactsAppLocationButton.new("Route 104"), ContactsAppTrainerButton.new("Hiker Bob")]
  scene = ContactsAppScene.new
  joey.hover
  marks = "Youngster Joey, #{t.t(:if2_nav_trade)}, #{t.t(:if2_nav_new)}"
  SpeakCapture.clear
  scene.pbStartScene(buttons, 1)
  eq "opening: the zone, the trainer, its trade and new icons, and its place among trainers", SpeakCapture.last,
     "Favorites. #{t.t(:list_entry, :name => marks, :n => 1, :tot => 3)}"
  scene.instance_variable_set(:@index, 4)
  scene.hover(nil)
  eq "a move into the next zone names it", SpeakCapture.last,
     "Route 104. #{t.t(:list_entry, :name => 'Hiker Bob', :n => 3, :tot => 3)}"
  scene.instance_variable_set(:@index, 2)
  scene.hover(nil)
  eq "and back, the zone again", SpeakCapture.last, "Favorites. #{t.t(:list_entry, :name => 'Lass Ana', :n => 2, :tot => 3)}"
  scene.instance_variable_set(:@index, 1)
  scene.hover(nil)
  eq "within a zone, no zone name; the new icon while it fades", SpeakCapture.last,
     t.t(:list_entry, :name => marks, :n => 1, :tot => 3)
  joey.instance_variable_set(:@fading_new_icon, nil)
  scene.instance_variable_set(:@index, 2)
  scene.hover(nil)
  scene.instance_variable_set(:@index, 1)
  scene.hover(nil)
  eq "a trainer already seen is not new", SpeakCapture.last,
     t.t(:list_entry, :name => "Youngster Joey, #{t.t(:if2_nav_trade)}", :n => 1, :tot => 3)
  scene.instance_variable_set(:@index, 3)
  scene.hover(nil)
  eq "a header the cursor lands on after an empty zone is said by its name", SpeakCapture.last, "Route 104"
end

Suite.define("ifh contacts: the friendship of each trainer's sheet, even when it matches the one before") do
  t = PokeAccess::I18n
  trainer = Struct.new(:id, :friendship_level)
  scene = ContactsAppInfoPageScene.new
  scene.trainer = trainer.new(1, 2)
  SpeakCapture.clear
  scene.showFriendshipIcons
  scene.trainer = trainer.new(2, 2)
  scene.showFriendshipIcons
  eq "each sheet says its hearts", SpeakCapture.lines, [t.t(:pnav_friendship, :n => 2)] * 2
  SpeakCapture.clear
  scene.showFriendshipIcons
  silent "but the same sheet redrawn does not"
end

Suite.define("ifh fusion quiz app: the menu is read again when it reopens after a game") do
  t = PokeAccess::I18n
  scene = FusionQuizAppScene.new
  buttons = [["play", "Play"], ["score", "Score"], ["exit", "Exit"]].map do |id, text|
    b = Object.new
    b.instance_variable_set(:@id, id)
    b.instance_variable_set(:@text, text)
    b
  end
  SpeakCapture.clear
  scene.pbStartScene(buttons)
  scene.pbStartScene(buttons)
  eq "opened twice on Play, said twice", SpeakCapture.lines, [t.t(:list_entry, :name => "Play", :n => 1, :tot => 3)] * 2
end

Suite.define("ifh challenges: the first challenge waits for the title and count the header paints") do
  ch = Struct.new(:description, :money_reward, :item_reward, :completed)
  scene = PokemonChallenges_Scene.new
  scene.instance_variable_set(:@challenges, [ch.new("Atrapa 3 Pokémon", 500, [], false), ch.new("Gana 2", 300, [], false)])
  scene.instance_variable_set(:@buttons, [])
  scene.instance_variable_set(:@index, 0)
  SpeakCapture.clear
  scene.pbUpdate
  scene.instance_variable_set(:@index, 1)
  scene.pbUpdate
  eq "queued on opening, interrupting on each move", SpeakCapture.log.map { |l| l[1] }, [false, true]
end

Suite.define("ifh launcher: rearrange mode on and off, and each app lifted and set down with its place") do
  t = PokeAccess::I18n
  names = ["Map", "Quests", "Day/Night", "Rearrange", "PokeRadar"]
  gear = PokemonPokegear_Scene.new(names)
  gear.instance_variable_set(:@commands, names.map { |n| [n.downcase, n] })
  gear.index = 3
  gear.pbUpdate
  SpeakCapture.clear
  gear.instance_variable_set(:@rearranging, true)
  gear.pbUpdate
  eq "the mode is said with the app under the cursor, which the button reader then leaves alone",
     SpeakCapture.lines, ["#{t.t(:if2_nav_rearrange_on)}. Rearrange"]
  gear.index = 1
  SpeakCapture.clear
  gear.swap_apps
  eq "a first press lifts the app", SpeakCapture.last,
     t.t(:if2_nav_picked, :name => "Quests") + t.t(:pc_pos, :row => 1, :col => 2)
  gear.index = 4
  gear.swap_apps
  eq "a second sets it down where the cursor is", SpeakCapture.last,
     t.t(:if2_nav_placed, :name => "Quests") + t.t(:pc_pos, :row => 2, :col => 1)
  gear.instance_variable_set(:@rearranging, false)
  SpeakCapture.clear
  gear.pbUpdate
  eq "leaving the mode says so", SpeakCapture.lines, [t.t(:if2_nav_rearrange_off)]
end

Suite.define("ifh quests: a category as its button paints it, with its count, after the log's title and hint") do
  t = PokeAccess::I18n
  mode = Struct.new(:button_text, :count) do
    def filter_quests(all); all.first(count); end
  end
  saved = $Trainer
  begin
    $Trainer = Struct.new(:quests).new([:a, :b, :c])
    scene = Questlog.new
    scene.instance_variable_set(:@modes, [mode.new("Main Quests", 2), mode.new("Completed", 3)])
    scene.instance_variable_set(:@main_menu_index, 0)
    SpeakCapture.clear
    scene.draw_main_text
    eq "the title and the hint for the map, then the category and its count, all queued", SpeakCapture.log,
       [["Quest Log. L/R : MAP", false], [t.t(:list_entry, :name => "Main Quests: 2", :n => 1, :tot => 2), false]]
    scene.instance_variable_set(:@main_menu_index, 1)
    scene.switch_button
    eq "the next category by its button's text", SpeakCapture.last,
       t.t(:list_entry, :name => "Completed: 3", :n => 2, :tot => 2)
  ensure
    $Trainer = saved
  end
end

Suite.define("ifh quests: the kind a quest's name colour marks is said from medium") do
  t = PokeAccess::I18n
  q = Struct.new(:name, :completed, :type)
  scene = Questlog.new
  scene.instance_variable_set(:@filtered_quests, [q.new("Grafiti", false, :MAGMA_QUEST)])
  scene.instance_variable_set(:@quest_list_menu_index, 0)
  scene.instance_variable_set(:@main_menu_index, 1)
  rows = vb_levels do
    PokeAccess::Cursor.reset(scene, :if2_quest)
    SpeakCapture.clear
    PokeAccess::IF2Quests.quest(scene)
    SpeakCapture.last
  end
  eq "brief: the name alone", rows[0], "Grafiti"
  eq "medium: its state and its kind", rows[1],
     t.t(:list_entry, :name => "Grafiti, #{t.t(:qu_status_pending)}, #{t.t(:if2_qt_magma)}", :n => 1, :tot => 1)
end
