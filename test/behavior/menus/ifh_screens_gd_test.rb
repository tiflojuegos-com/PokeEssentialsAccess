# Infinite Fusion Hoenn's own screens, gamedata pass: the starters, the PokeNav apps and launcher, the challenges and
# the quest log and map panel, each read at its reading's level with the whole row kept on the info key.

# The starter picker: each repaint paints the rows the spec hands it in @paint, as the game paints the starter's name
# and category line.
class StartersSelectionScene
  def updateStarterSelectionGraphics
    pbDrawTextPositions(nil, @paint) if @paint
    :drawn
  end
end

# The one-starter variant, which inherits the picker's repaint.
class StartersSelectionSceneSingle < StartersSelectionScene; end

# A PokeNav app: the base opener takes the buttons and focuses the first, hover is a cursor move's repaint.
class PokeNavAppScene
  def pbStartScene(buttons = [])
    @buttons = buttons
    @index = 0
    :started
  end

  def hover(_id); :hovered; end
  def pbEndScene; :ended; end
end

# A PokeNav app's button: its id and the label it paints.
class PokenavButton
  attr_reader :id
  def initialize(id, text = nil); @id = id; @text = text; end
end

# The contacts list: zone headers among the trainers; its opener runs the base one, then focuses a trainer and hovers
# its button, as the game's does.
class ContactsAppScene < PokeNavAppScene
  def pbStartScene(buttons, index)
    super(buttons)
    @index = index
    @buttons[@index].hover
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

# A trainer's sheet: its row of hearts, and a close that repaints the PokeNav header through the HUD reader.
class ContactsAppInfoPageScene
  attr_accessor :trainer
  def showFriendshipIcons; :shown; end

  def pbEndScene
    PokeAccess::HudText.say("PokeNav")
    :ended
  end
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

# The fusion quiz's menu: its opener runs the base one, as the game's does.
class FusionQuizAppScene < PokeNavAppScene
  def pbStartScene(buttons = nil)
    super(buttons)
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

# The map's quest panel: its own loop, polled as it opens and again on each index in moves; it keeps what the info
# key held while it was up.
class QuestMapPopup
  attr_reader :seen_info

  def initialize(quests, moves = [])
    @quests = quests
    @moves = moves
    @index = 0
    @location_name = "Petalburgo"
  end

  def run
    PokeAccess::Frame.run_pollers
    @seen_info = PokeAccess::Info.info_text
    @moves.each do |i|
      @index = i
      PokeAccess::Frame.run_pollers
    end
    :closed
  end
end

# The profile's files, loaded after the stand-ins above: a hook on a class not yet defined binds nothing.
%w[starters pokenav quests].each do |f|
  path = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "#{f}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class IfhScreensGdTest < PokeAccessTest
  NAME_ROW = ["Torchic", 156, 10]
  CATEGORY_ROW = ["Chick Pokemon", 156, 40]
  Quest = Struct.new(:name, :completed, :type)
  Detail = Struct.new(:name, :completed, :desc, :npc, :location)
  Challenge = Struct.new(:description, :money_reward, :item_reward, :completed)
  Claim = Struct.new(:can_claim_reward)
  Trainer = Struct.new(:id, :friendship_level)

  # A quest log category: its button's text, and the first count of the player's quests it holds.
  CountedMode = Struct.new(:button_text, :count) do
    def filter_quests(all); all.first(count); end
  end

  test "reads the focused starter at each level: its name, then the painted category line, then the shiny mark" do
    rows = vb_levels do
      last_said { picker(:paint => [NAME_ROW, CATEGORY_ROW], :shiny => true).updateStarterSelectionGraphics }
    end
    assert_equal ["SpeciesTORCHIC", row("SpeciesTORCHIC, Chick Pokemon", 2, 3),
                  row("SpeciesTORCHIC, Chick Pokemon, #{t(:pk_shiny)}", 2, 3)], rows
  end

  test "reads a starter painted without a category line, on a plain sprite, by its name and place alone" do
    rows = vb_levels { last_said { picker(:paint => [NAME_ROW]).updateStarterSelectionGraphics } }
    assert_equal ["SpeciesTORCHIC", row("SpeciesTORCHIC", 2, 3), row("SpeciesTORCHIC", 2, 3)], rows
  end

  test "keeps the whole starter on the info key at brief" do
    PokeAccess::Config.verbosity = :brief
    picker(:paint => [NAME_ROW, CATEGORY_ROW], :shiny => true).updateStarterSelectionGraphics
    assert_equal "SpeciesTORCHIC, Chick Pokemon, #{t(:pk_shiny)}", PokeAccess::Info.info_text
  end

  test "says each starter once, interrupting, as the cursor moves along the row" do
    scene = picker
    log = spoken do
      scene.updateStarterSelectionGraphics
      scene.updateStarterSelectionGraphics
      scene.instance_variable_set(:@index, 2)
      scene.updateStarterSelectionGraphics
    end
    assert_equal [[row("SpeciesTORCHIC", 2, 3), true], [row("SpeciesMUDKIP", 3, 3), true]], log
  end

  test "reads the one-starter variant without a place in the row" do
    scene = picker(:class => StartersSelectionSceneSingle, :paint => [NAME_ROW, CATEGORY_ROW])
    assert_equal "SpeciesTORCHIC, Chick Pokemon", last_said { scene.updateStarterSelectionGraphics }
  end

  test "reads the starters at both ends of the row, and nothing for a cursor off it" do
    got = [0, 2, -1, 3, 1.0, nil].map { |i| last_said { picker(:index => i).updateStarterSelectionGraphics } }
    assert_equal [row("SpeciesTREECKO", 1, 3), row("SpeciesMUDKIP", 3, 3), nil, nil, nil, nil], got
    assert_nil last_said { picker(:species => nil).updateStarterSelectionGraphics }, "a picker without its starters"
  end

  test "an app that keeps the base opener reads its first button as it opens" do
    buttons = [PokenavButton.new(:map, "Mapa"), PokenavButton.new(:radio, "Radio")]
    log = spoken { PokeNavAppScene.new.pbStartScene(buttons) }
    assert_equal [[row("Mapa", 1, 2), true]], log
  end

  test "reads each button the cursor moves to once" do
    app = nav_app([PokenavButton.new(:map, "Mapa"), PokenavButton.new(:radio, "Radio")])
    log = spoken do
      app.hover(:map)
      app.instance_variable_set(:@index, 1)
      app.hover(:radio)
      app.hover(:radio)
    end
    assert_equal [[row("Mapa", 1, 2), true], [row("Radio", 2, 2), true]], log
  end

  test "reads a button by its text id where it paints no text, and nothing for one with no label" do
    { PokenavButton.new("Ajustes") => row("Ajustes", 1, 1),
      PokenavButton.new(:BULBASAUR) => nil,
      PokenavButton.new("", "   ") => nil }.each do |button, want|
      got = last_said { PokeNavAppScene.new.pbStartScene([button]) }
      assert_equal [want], [got], "for #{button.inspect}"
    end
  end

  test "says nothing for a cursor outside the app's buttons" do
    buttons = [PokenavButton.new(:map, "Mapa"), PokenavButton.new(:radio, "Radio")]
    got = [-1, 2, 1.0].map { |i| last_said { nav_app(buttons, i).hover(nil) } }
    assert_equal [nil, nil, nil], got
    assert_nil last_said { nav_app(nil).hover(nil) }, "an app without buttons"
  end

  test "closing an app takes its row off the info key" do
    app = radar_app([:ZIGZAGOON])
    app.hover(:ZIGZAGOON)
    app.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "reads a seen species on the radar at the Pokedex reading's level: its name, then its rarity and scan cost" do
    rows = vb_levels { last_said { radar_app([:ZIGZAGOON]).hover(:ZIGZAGOON) } }
    medium = row("SpeciesZIGZAGOON, Common, #{t(:if2_radar_battery, :n => 30)}", 1, 1)
    assert_equal ["SpeciesZIGZAGOON", medium, medium], rows
  end

  test "keeps the whole radar row on the info key at brief" do
    PokeAccess::Config.verbosity = :brief
    radar_app([:ZIGZAGOON]).hover(:ZIGZAGOON)
    assert_equal "SpeciesZIGZAGOON, Common, #{t(:if2_radar_battery, :n => 30)}", PokeAccess::Info.info_text
  end

  test "reads an unseen species as unknown, and puts that on the info key over the species before" do
    app = radar_app([:ZIGZAGOON, :WURMPLE], [:ZIGZAGOON])
    app.hover(:ZIGZAGOON)
    app.instance_variable_set(:@index, 1)
    assert_equal row(t(:if2_radar_unknown), 2, 2), last_said { app.hover(:WURMPLE) }
    assert_equal t(:if2_radar_unknown), PokeAccess::Info.info_text
  end

  test "leaves out a rarity the radar has blank and a scan cost it cannot give" do
    app = radar_app([:ZIGZAGOON])
    def app.get_rarity_flavor_text(_sp); " "; end
    def app.get_energy_for_scan(_sp); nil; end
    assert_equal row("SpeciesZIGZAGOON", 1, 1), last_said { app.hover(:ZIGZAGOON) }
  end

  test "says nothing for a radar row while a scan runs, or for a row without a species" do
    assert_nil with_scan { last_said { radar_app([:ZIGZAGOON]).hover(:ZIGZAGOON) } }, "during a scan"
    assert_nil last_said { radar_app([nil]).hover(nil) }, "a row with no species"
  end

  test "the radar's first row leads with the header's name, battery and zone as painted; the next row does not" do
    scene = PokeRadarAppScene.new
    scene.instance_variable_set(:@seenPokemon, [:ZIGZAGOON, :WURMPLE])
    scene.instance_variable_set(:@buttons, [PokenavButton.new(:ZIGZAGOON), PokenavButton.new(:WURMPLE)])
    scene.instance_variable_set(:@index, 0)
    first = spoken { scene.hover(:ZIGZAGOON) }
    scene.instance_variable_set(:@index, 1)
    second = spoken { scene.hover(:WURMPLE) }
    assert_equal [["PokeRadar. 12/1000. Route 104 (Grass). #{row('SpeciesZIGZAGOON', 1, 2)}", true]], first
    assert_equal [[row("SpeciesWURMPLE", 2, 2), true]], second
  end

  test "opens on a trainer with its zone, its trade and new icons, and its place among the trainers alone" do
    log = spoken { contacts_app }
    assert_equal [["Favorites. #{row(joey_row(true), 1, 3)}", true]], log
  end

  test "names the zone the cursor moves into, and again on coming back to the first" do
    app = contacts_app
    assert_equal [["Route 104. #{row('Hiker Bob', 3, 3)}", true]], spoken { move(app, 4) }
    assert_equal [["Favorites. #{row('Lass Ana', 2, 3)}", true]], spoken { move(app, 2) }
  end

  test "reads a trainer of the same zone without the zone's name" do
    app = contacts_app
    assert_equal [[row("Lass Ana", 2, 3), true]], spoken { move(app, 2) }
  end

  test "keeps a trainer's new mark while its icon fades, and drops it once faded" do
    app = contacts_app
    move(app, 2)
    assert_equal row(joey_row(true), 1, 3), last_said { move(app, 1) }, "fading"
    app.instance_variable_get(:@buttons)[1].instance_variable_set(:@fading_new_icon, Struct.new(:disposed?).new(true))
    move(app, 2)
    assert_equal row(joey_row(false), 1, 3), last_said { move(app, 1) }, "faded"
  end

  test "says a zone header the cursor lands on by its name alone" do
    app = contacts_app
    assert_equal "Route 104", last_said { move(app, 3) }
  end

  test "reads a trainer with no named zone above it by itself" do
    ana = ContactsAppTrainerButton.new("Lass Ana")
    lists = { "no header above" => [ana, ContactsAppLocationButton.new("Route 104")],
              "a header with no text" => [ContactsAppLocationButton.new(nil), ana] }
    lists.each do |what, buttons|
      index = buttons.index(ana)
      assert_equal row("Lass Ana", 1, 1), last_said { ContactsAppScene.new.pbStartScene(buttons, index) }, what
    end
  end

  test "says nothing for a trainer whose button has no text" do
    buttons = [ContactsAppLocationButton.new("Favorites"), ContactsAppTrainerButton.new(nil)]
    assert_nothing_said { ContactsAppScene.new.pbStartScene(buttons, 1) }
  end

  test "says each trainer sheet's friendship, queued, even when it matches the one before" do
    sheet = ContactsAppInfoPageScene.new
    log = spoken do
      sheet.trainer = Trainer.new(1, 2)
      sheet.showFriendshipIcons
      sheet.trainer = Trainer.new(2, 2)
      sheet.showFriendshipIcons
    end
    assert_equal [[t(:pnav_friendship, :n => 2), false]] * 2, log
  end

  test "does not repeat a sheet redrawn for the same trainer" do
    sheet = ContactsAppInfoPageScene.new
    sheet.trainer = Trainer.new(1, 2)
    sheet.showFriendshipIcons
    assert_nothing_said { sheet.showFriendshipIcons }
  end

  test "says nothing of the hearts of a sheet with no friendship level" do
    sheet = ContactsAppInfoPageScene.new
    sheet.trainer = Trainer.new(1, nil)
    assert_nothing_said { sheet.showFriendshipIcons }
  end

  test "keeps quiet the header a sheet's close repaints, and only that" do
    assert_nothing_said { ContactsAppInfoPageScene.new.pbEndScene }
    assert_equal [["PokeNav", false]], spoken { PokeAccess::HudText.say("PokeNav") }, "painted outside the close"
  end

  test "reads the quiz menu's first button each time the menu reopens after a game" do
    scene = FusionQuizAppScene.new
    buttons = [["play", "Play"], ["score", "Score"], ["exit", "Exit"]].map { |id, text| PokenavButton.new(id, text) }
    log = spoken do
      scene.pbStartScene(buttons)
      scene.pbStartScene(buttons)
    end
    assert_equal [[row("Play", 1, 3), true]] * 2, log
  end

  test "reads a challenge by what it asks, from medium its place and that it is ready, in full its reward" do
    rows = vb_levels do
      last_said { challenges([ready_challenge, earning_challenge], [Claim.new(true), Claim.new(false)]).pbUpdate }
    end
    head = row("Atrapa 3 Pokémon", 1, 2)
    assert_equal ["Atrapa 3 Pokémon", "#{head}. #{t(:if2_ch_ready)}", "#{head}. #{t(:if2_ch_collect, :n => 500)}"], rows
  end

  test "keeps a challenge and its whole reward on the info key at brief" do
    PokeAccess::Config.verbosity = :brief
    challenges([ready_challenge], [Claim.new(true)]).pbUpdate
    assert_equal "Atrapa 3 Pokémon. #{t(:if2_ch_collect, :n => 500)}", PokeAccess::Info.info_text
  end

  test "says a reward still to earn only in full" do
    rows = vb_levels do
      scene = challenges([ready_challenge, earning_challenge], [Claim.new(true), Claim.new(false)], 1)
      last_said { scene.pbUpdate }
    end
    head = row("Gana 2 combates", 2, 2)
    assert_equal ["Gana 2 combates", head, "#{head}. #{t(:if2_ch_reward, :n => 300)}"], rows
  end

  test "names the items a reward gives after its money" do
    scene = challenges([Challenge.new("Gana 2 combates", 300, [:POTION, :REPEL], false)], [Claim.new(false)])
    assert_equal "#{row('Gana 2 combates', 1, 1)}. #{t(:if2_ch_reward, :n => 300)}. ItemPOTION, ItemREPEL",
                 last_said { scene.pbUpdate }
  end

  test "tells a reward ready by the challenge's button, else by the challenge itself, and counts no money as none" do
    bare = Struct.new(:description, :money_reward)
    no_money = Struct.new(:description, :completed)
    cases = [[ready_challenge, [Claim.new(true)], t(:if2_ch_collect, :n => 500)],
             [ready_challenge, [], t(:if2_ch_collect, :n => 500)],
             [bare.new("Atrapa 3 Pokémon", 500), [], t(:if2_ch_reward, :n => 500)],
             [no_money.new("Atrapa 3 Pokémon", false), [], t(:if2_ch_reward, :n => 0)]]
    cases.each do |challenge, buttons, reward|
      got = last_said { challenges([challenge], buttons).pbUpdate }
      assert_equal "#{row('Atrapa 3 Pokémon', 1, 1)}. #{reward}", got, "for #{challenge.inspect} with #{buttons.inspect}"
    end
  end

  test "reads a challenge whose reward it cannot read without the reward" do
    scene = challenges([Challenge.new("Atrapa 3 Pokémon", Object.new, [], true)], [Claim.new(true)])
    assert_equal row("Atrapa 3 Pokémon", 1, 1), last_said { scene.pbUpdate }
    assert_equal "Atrapa 3 Pokémon", PokeAccess::Info.info_text, "the info key keeps what it asks for"
  end

  test "reads the first challenge queued after the header the app paints, and each move interrupting" do
    scene = challenges([ready_challenge, earning_challenge], [Claim.new(true), Claim.new(false)])
    log = spoken do
      scene.pbUpdate
      scene.pbUpdate
      scene.instance_variable_set(:@index, 1)
      scene.pbUpdate
    end
    assert_equal [["#{row('Atrapa 3 Pokémon', 1, 2)}. #{t(:if2_ch_collect, :n => 500)}", false],
                  ["#{row('Gana 2 combates', 2, 2)}. #{t(:if2_ch_reward, :n => 300)}", true]], log
  end

  test "reads the challenge that slides into the slot of one collected" do
    scene = challenges([ready_challenge, earning_challenge], [Claim.new(true), Claim.new(false)])
    scene.pbUpdate
    scene.instance_variable_set(:@challenges, [earning_challenge])
    scene.instance_variable_set(:@buttons, [Claim.new(false)])
    assert_equal [["#{row('Gana 2 combates', 1, 1)}. #{t(:if2_ch_reward, :n => 300)}", true]], spoken { scene.pbUpdate }
  end

  test "says nothing for a challenge with no description or a cursor outside the list" do
    list = [ready_challenge, earning_challenge]
    got = [-1, 2, 1.0].map { |i| last_said { challenges(list, [], i).pbUpdate } }
    assert_equal [nil, nil, nil], got
    assert_nil last_said { challenges([Challenge.new(" ", 500, [], true)], []).pbUpdate }, "a blank description"
    assert_nil last_said { challenges(nil, []).pbUpdate }, "no challenges"
  end

  test "closing the challenges takes the row off the info key" do
    scene = challenges([ready_challenge], [Claim.new(true)])
    scene.pbUpdate
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "says nothing of the rearrange mode as the launcher opens, or on a frame that keeps it" do
    gear = launcher
    assert_equal [["Rearrange", true]], spoken { gear.pbUpdate }, "the opening frame names the focused app only"
    assert_nothing_said { gear.pbUpdate }
  end

  test "says the rearrange mode with the app under the cursor, which the launcher's reader then leaves alone" do
    gear = launcher
    gear.pbScene
    assert_equal [["#{t(:if2_nav_rearrange_on)}. Rearrange", true]], spoken { start_rearranging(gear) }
  end

  test "lifts an app with its place on the grid, and sets it down where the cursor is" do
    gear = launcher
    gear.index = 1
    lifted = spoken { gear.swap_apps }
    gear.index = 4
    placed = spoken { gear.swap_apps }
    assert_equal [[t(:if2_nav_picked, :name => "Quests") + t(:pc_pos, :row => 1, :col => 2), true]], lifted
    assert_equal [[t(:if2_nav_placed, :name => "Quests") + t(:pc_pos, :row => 2, :col => 1), true]], placed
  end

  test "keeps the next frame quiet about the app a drop has just named" do
    gear = launcher
    gear.pbScene
    start_rearranging(gear)
    gear.index = 1
    gear.pbUpdate
    gear.swap_apps
    gear.index = 4
    gear.pbUpdate
    gear.swap_apps
    assert_nothing_said { gear.pbUpdate }
  end

  test "says when the rearrange mode ends" do
    gear = launcher
    gear.pbScene
    start_rearranging(gear)
    gear.instance_variable_set(:@rearranging, false)
    assert_equal [[t(:if2_nav_rearrange_off), true]], spoken { gear.pbUpdate }
  end

  test "says the rearrange mode alone over a slot with no app" do
    gear = launcher
    gear.index = 7
    gear.pbScene
    assert_equal [[t(:if2_nav_rearrange_on), true]], spoken { start_rearranging(gear) }
  end

  test "says nothing for a swap on a slot with no app" do
    gear = launcher
    gear.index = 7
    assert_nothing_said { gear.swap_apps }
  end

  test "reads a quest at the quest reading's level: its name, then whether it is done and its place" do
    list = [Quest.new("Busca el gato", false), Quest.new("Lleva la carta", true)]
    rows = vb_levels { last_said { questlog(list, 1).move_selection } }
    medium = row("Lleva la carta, #{t(:qu_status_done)}", 2, 2)
    assert_equal ["Lleva la carta", medium, medium], rows
  end

  test "keeps the whole quest on the info key at brief" do
    PokeAccess::Config.verbosity = :brief
    questlog([Quest.new("Lleva la carta", true)]).move_selection
    assert_equal "Lleva la carta, #{t(:qu_status_done)}", PokeAccess::Info.info_text
  end

  test "says from medium the kind a quest's name colour marks, and none for a field quest" do
    PokeAccess::Config.verbosity = :medium
    { :MAIN_QUEST => ", #{t(:qmp_main)}", :MAGMA_QUEST => ", #{t(:if2_qt_magma)}",
      :AQUA_QUEST => ", #{t(:if2_qt_aqua)}", :FIELD_QUEST => "" }.each do |type, mark|
      got = last_said { questlog([Quest.new("Grafiti", false, type)]).move_selection }
      assert_equal row("Grafiti, #{t(:qu_status_pending)}#{mark}", 1, 1), got, "for #{type}"
    end
  end

  test "reads each quest once, interrupting, as the cursor moves down the list" do
    scene = questlog([Quest.new("Busca el gato", false), Quest.new("Lleva la carta", true)])
    log = spoken do
      scene.move_selection
      scene.move_selection
      scene.instance_variable_set(:@quest_list_menu_index, 1)
      scene.move_selection
    end
    assert_equal [[row("Busca el gato, #{t(:qu_status_pending)}", 1, 2), true],
                  [row("Lleva la carta, #{t(:qu_status_done)}", 2, 2), true]], log
  end

  test "says an empty category's own message, and nothing when it has none" do
    mode = Struct.new(:empty_message)
    scene = questlog([])
    scene.instance_variable_set(:@current_mode, mode.new("No hay misiones."))
    assert_equal [["No hay misiones.", true]], spoken { scene.move_selection }
    scene.instance_variable_set(:@current_mode, mode.new(" "))
    assert_nothing_said { scene.move_selection }
  end

  test "says nothing for a quest with no name or a cursor outside the list" do
    list = [Quest.new("Busca el gato", false), Quest.new("Lleva la carta", true)]
    got = [-1, 2, 1.0].map { |i| last_said { questlog(list, i).move_selection } }
    assert_equal [nil, nil, nil], got
    assert_nil last_said { questlog([Quest.new("", false)]).move_selection }, "a quest without a name"
    assert_nil last_said { questlog(nil).move_selection }, "no list"
  end

  test "reads nothing for an empty slot of the quest list, as a row or as a brief" do
    scene = questlog([nil])
    assert_nothing_said { scene.move_selection }
    assert_nothing_said { scene.draw_quest_details }
  end

  test "reads the focused quest again each time a category's list opens" do
    scene = questlog([Quest.new("Busca el gato", false)])
    log = spoken do
      scene.show_quest_list
      scene.show_quest_list
    end
    assert_equal [[row("Busca el gato, #{t(:qu_status_pending)}", 1, 1), true]] * 2, log
  end

  test "reads the brief of the quest handed in: its whole line, description, giver and place" do
    scene = questlog([Detail.new("Lleva la carta", true, "Lleva la carta a Ana", "Ana", "Ruta 104")])
    handed = Detail.new("Busca el gato", false, "Encuentra al gato", "Señora Rosa", "Petalburgo")
    expected = "#{pending_line('Busca el gato')}. Encuentra al gato. Señora Rosa. Petalburgo"
    assert_equal [[expected, true]], spoken { scene.draw_quest_details(handed) }
  end

  test "reads the brief of the focused quest when none is handed in, and nothing off the list" do
    scene = questlog([Detail.new("Busca el gato", false, "Encuentra al gato", "Rosa", "Petalburgo")])
    assert_equal [["#{pending_line('Busca el gato')}. Encuentra al gato. Rosa. Petalburgo", true]],
                 spoken { scene.draw_quest_details }
    scene.instance_variable_set(:@quest_list_menu_index, 1)
    assert_nothing_said { scene.draw_quest_details }
  end

  test "leaves the fields a quest has blank out of its brief" do
    scene = questlog([Detail.new("Busca el gato", false, "Encuentra al gato", " ", nil)])
    assert_equal [["#{pending_line('Busca el gato')}. Encuentra al gato", true]], spoken { scene.draw_quest_details }
  end

  test "opens the log with its title and map hint, then the focused category with its count, all queued" do
    scene = categories
    log = with_trainer_quests([:a, :b, :c]) { spoken { scene.draw_main_text } }
    assert_equal [["Quest Log. L/R : MAP", false], [row("Main Quests: 2", 1, 2), false]], log
  end

  test "reads the next category by its button's text and count, interrupting" do
    scene = categories
    log = with_trainer_quests([:a, :b, :c]) do
      scene.draw_main_text
      scene.instance_variable_set(:@main_menu_index, 1)
      spoken { scene.switch_button }
    end
    assert_equal [[row("Completed: 3", 2, 2), true]], log
  end

  test "leaves the map hint out of the title while key hints are off or the log cannot switch to the map" do
    PokeAccess::Config.verbosity = :brief
    assert_equal "Quest Log", spoken { categories.draw_main_text }.first[0], "hints off"
    PokeAccess::Config.verbosity = :full
    scene = categories
    def scene.can_switch_mode?; false; end
    assert_equal "Quest Log", spoken { scene.draw_main_text }.first[0], "no map to switch to"
  end

  test "says the same category again, queued, on coming back from its list" do
    scene = categories
    log = with_trainer_quests([:a, :b, :c]) do
      scene.draw_main_text
      spoken { scene.redraw_main_screen }
    end
    assert_equal [[row("Main Quests: 2", 1, 2), false]], log
  end

  test "keeps quiet about the categories while a quest's details are up" do
    scene = categories
    scene.instance_variable_set(:@scene, 2)
    assert_nothing_said { scene.switch_button }
  end

  test "reads a category by its button text, else its title, else its name, and nothing for one with none" do
    titled = Struct.new(:title)
    named = Struct.new(:name)
    cases = { categories([Struct.new(:button_text).new("Main Quests")]) => row("Main Quests", 1, 1),
              categories([titled.new("Side Quests")]) => row("Side Quests", 1, 1),
              categories([named.new("Old Quests")]) => row("Old Quests", 1, 1),
              categories([Struct.new(:button_text).new("")]) => nil }
    got = cases.keys.map { |scene| last_said { scene.switch_button } }
    assert_equal cases.values, got
  end

  test "says nothing for a category cursor outside the list" do
    got = [-1, 2, 1.0].map do |i|
      scene = categories
      scene.instance_variable_set(:@main_menu_index, i)
      last_said { scene.switch_button }
    end
    assert_equal [nil, nil, nil], got
    assert_nil last_said { categories(nil).switch_button }, "no categories"
  end

  test "opens the panel with its place's quests header, then reads the first row, both queued" do
    log = spoken { QuestMapPopup.new([Quest.new("Busca el gato", false, :MAIN_QUEST)]).run }
    assert_equal [["Petalburgo Quests", false], [row("Busca el gato, #{t(:qmp_main)}", 1, 1), false]], log
  end

  test "reads a panel row at the quest reading's level: its name, then its kind and place" do
    rows = vb_levels { spoken { QuestMapPopup.new([Quest.new("Busca el gato", false, :MAIN_QUEST)]).run }.last[0] }
    medium = row("Busca el gato, #{t(:qmp_main)}", 1, 1)
    assert_equal ["Busca el gato", medium, medium], rows
  end

  test "reads the panel row the cursor moves to, interrupting, and nothing past the last" do
    quests = [Quest.new("Busca el gato", false, :MAIN_QUEST), Quest.new("Limpia la ruta", false, :FIELD_QUEST)]
    log = spoken { QuestMapPopup.new(quests, [1, 2]).run }
    assert_equal [["Petalburgo Quests", false], [row("Busca el gato, #{t(:qmp_main)}", 1, 2), false],
                  [row("Limpia la ruta", 2, 2), true]], log
  end

  test "has the panel's whole row on the info key while it is up, and nothing of it once it closes" do
    PokeAccess::Config.verbosity = :brief
    panel = QuestMapPopup.new([Quest.new("Busca el gato", false, :MAIN_QUEST)])
    panel.run
    assert_equal "Busca el gato, #{t(:qmp_main)}", panel.seen_info
    assert_nil PokeAccess::Info.info_text
  end

  private

  # The mod's Spanish text for an i18n key.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A list row with its place, as the readers say it while positions are said.
  def row(name, n, tot)
    t(:list_entry, :name => name, :n => n, :tot => tot)
  end

  # What the block makes the mod say, as [text, interrupt] pairs, the log cleared first.
  def spoken
    SpeakCapture.clear
    yield
    SpeakCapture.log.dup
  end

  # The last line the block makes the mod say, or nil when it says nothing.
  def last_said
    SpeakCapture.clear
    yield
    SpeakCapture.last
  end

  # Passes when the block makes the mod say nothing.
  def assert_nothing_said(msg = nil)
    SpeakCapture.clear
    yield
    assert_nothing_spoken msg
  end

  # A starter picker over Treecko, Torchic and Mudkip, on Torchic unless :index says otherwise; :paint the rows its
  # repaint paints, :shiny Torchic's sprite shiny, :species another list, :class the variant.
  def picker(opts = {})
    scene = (opts[:class] || StartersSelectionScene).new
    species = opts.key?(:species) ? opts[:species] : [:TREECKO, :TORCHIC, :MUDKIP]
    scene.instance_variable_set(:@starters_species, species)
    scene.instance_variable_set(:@starter_pokemon, [Poke.build, Poke.build(:shiny => opts[:shiny] ? true : false), Poke.build])
    scene.instance_variable_set(:@index, opts.key?(:index) ? opts[:index] : 1)
    scene.instance_variable_set(:@paint, opts[:paint])
    scene
  end

  # A PokeNav app over buttons, its cursor on index.
  def nav_app(buttons, index = 0)
    app = PokeNavAppScene.new
    app.instance_variable_set(:@buttons, buttons)
    app.instance_variable_set(:@index, index)
    app
  end

  # The radar as an app with @seenPokemon, a row per species in ids, those in seen seen; each seen species is
  # "Common" and costs 30 to scan.
  def radar_app(ids, seen = ids)
    app = nav_app(ids.map { |id| PokenavButton.new(id) })
    app.instance_variable_set(:@seenPokemon, seen.compact)
    def app.get_rarity_flavor_text(_sp); "Common"; end
    def app.get_energy_for_scan(_sp); 30; end
    app
  end

  # Runs the block while the radar is scanning, $PokemonTemp put back afterwards.
  def with_scan
    saved = $PokemonTemp
    $PokemonTemp = Struct.new(:pokeradar).new(true)
    yield
  ensure
    $PokemonTemp = saved
  end

  # The contacts app opened on Joey (a new trainer with a trade on offer) in Favorites, then Ana, the Route 104
  # header and Bob.
  def contacts_app
    buttons = [ContactsAppLocationButton.new("Favorites"), ContactsAppTrainerButton.new("Youngster Joey", true, true),
               ContactsAppTrainerButton.new("Lass Ana"), ContactsAppLocationButton.new("Route 104"),
               ContactsAppTrainerButton.new("Hiker Bob")]
    app = ContactsAppScene.new
    app.pbStartScene(buttons, 1)
    app
  end

  # Joey's row: his name, his trade icon and, while it shows, his new icon.
  def joey_row(fresh)
    [["Youngster Joey", t(:if2_nav_trade)], fresh ? [t(:if2_nav_new)] : []].flatten.join(", ")
  end

  # Moves an app's cursor to index, as the game hovers the button there.
  def move(app, index)
    app.instance_variable_set(:@index, index)
    app.hover(nil)
  end

  # The challenges screen over list, its buttons and its cursor on index.
  def challenges(list, buttons, index = 0)
    scene = PokemonChallenges_Scene.new
    scene.instance_variable_set(:@challenges, list)
    scene.instance_variable_set(:@buttons, buttons)
    scene.instance_variable_set(:@index, index)
    scene
  end

  # A challenge done, its 500 to collect.
  def ready_challenge
    Challenge.new("Atrapa 3 Pokémon", 500, [], true)
  end

  # A challenge still to do, worth 300.
  def earning_challenge
    Challenge.new("Gana 2 combates", 300, [], false)
  end

  # The launcher over five apps, its cursor on Rearrange.
  def launcher
    names = ["Map", "Quests", "Day/Night", "Rearrange", "PokeRadar"]
    gear = PokemonPokegear_Scene.new(names)
    gear.instance_variable_set(:@commands, names.map { |n| [n.downcase, n] })
    gear.index = 3
    gear
  end

  # Turns the launcher's rearrange mode on and runs its loop again, as the game does once Rearrange is chosen.
  def start_rearranging(gear)
    gear.instance_variable_set(:@rearranging, true)
    gear.pbScene
  end

  # The quest log on a category's list, its cursor on index.
  def questlog(list, index = 0)
    scene = Questlog.new
    scene.instance_variable_set(:@filtered_quests, list)
    scene.instance_variable_set(:@quest_list_menu_index, index)
    scene.instance_variable_set(:@main_menu_index, 0)
    scene
  end

  # A quest still to do as its brief's first line says it: its name and its state.
  def pending_line(name)
    t(:qu_line, :name => name, :status => t(:qu_status_pending))
  end

  # The quest log's main screen over modes (by default Main Quests, which holds two, and Completed, which holds every
  # quest), on the first.
  def categories(modes = [CountedMode.new("Main Quests", 2), CountedMode.new("Completed", 3)])
    scene = Questlog.new
    scene.instance_variable_set(:@modes, modes)
    scene.instance_variable_set(:@main_menu_index, 0)
    scene
  end

  # Runs the block with the player holding quests, $Trainer put back afterwards.
  def with_trainer_quests(quests)
    saved = $Trainer
    $Trainer = Struct.new(:quests).new(quests)
    yield
  ensure
    $Trainer = saved
  end
end
