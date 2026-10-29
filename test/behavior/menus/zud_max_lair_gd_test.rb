# ZUD's Max Lair (plugins/zud_max_lair.rb). The map: at a Selection tile the corner and every way's path traced over
# the tiles (events, raids not yet battled, warps followed, flips, the stop), the lit way again as it changes, the map
# view's hovered tile, the speed-up key once. The menus: the rental, swap, item, training, tutor and prize screens'
# entries, and the treasure and record screens read whole.

# The lair map, down to what the reader asks of it: its tiles on a grid of 32 pixels drawn over a background, the
# player icon, the four arrows, the map view's cursor and the corner's sprites; the tile questions answer from @tiles,
# keyed by grid square, as the scene's own answer from its sprites.
class LairMapScene
  Sprite = Struct.new(:x, :y, :visible, :color, :src_rect, :text) do
    def disposed?; false; end
  end
  Tint = Struct.new(:alpha)
  Crop = Struct.new(:y)
  attr_accessor :tiles, :script

  def pbStartMapScene(_map)
    @script.call(self) if @script
    :map_closed
  end

  # The screen spot of a grid square.
  def at(col, row)
    bg = @sprites["background"]
    [bg.x + col * 32, bg.y + row * 32]
  end

  def kind(coords)
    bg = @sprites["background"]
    dx = coords[0] - bg.x
    dy = coords[1] - bg.y
    return nil unless dx % 32 == 0 && dy % 32 == 0
    @tiles[[dx / 32, dy / 32]]
  end

  def is?(coords, k); (t = kind(coords)) && t[0] == k ? true : false; end
  def value(coords, k); (t = kind(coords)) && t[0] == k ? t[1] : nil; end
  def pbStartTile?(c); is?(c, :start) ? true : nil; end
  def pbRouteSelections(c); value(c, :selection); end
  def pbPokemonTiles(c); value(c, :raid); end
  def pbEventTiles(c); value(c, :event); end
  def pbTurnTiles(c); value(c, :turn); end
  def pbWarpTile?(c); is?(c, :warp); end
  def pbLockedDoorTile?(c); is?(c, :door); end
  def pbRoadblockTile?(c); is?(c, :roadblock); end
  def pbSwitchTile?(c); is?(c, :switch); end
  def pbHiddenTrapTile?(c); is?(c, :trap); end
end

# The adventure's menus, down to their select and draw methods: each runs the script the test gives it with its own
# arguments, as the screen's loop would run between its frames.
class MaxLairEventScene
  attr_accessor :script
  [:pbRentalSelect, :pbSwapSelect, :pbItemSelect, :pbTrainingSelect, :pbTutorSelect, :pbPrizeSelect,
   :pbTreasureScreen, :pbEndlessRecordScreen, :pbDrawItemScreen, :pbDrawStatScreen, :pbDrawTutorScreen].each do |m|
    define_method(m) do |*args|
      (@script[m].call(self, *args) if @script && @script[m])
      m
    end
  end
end
lair_path = File.join(Harness::ROOT, "plugins", "zud_max_lair.rb")
lair_source = Harness.source(lair_path)
lair_hooks = /^(?:PokeAccess::Hooks\.(?:around|before|after)_hook\("(?:LairMapScene|MaxLairEventScene)"|\[\[:pbRentalSelect).*?^end\r?\n/m
lair_source.scan(lair_hooks) do
  hook = Regexp.last_match
  eval(hook[0], TOPLEVEL_BINDING, lair_path, lair_source[0, hook.begin(0)].count("\n") + 1)
end

class ZudMaxLairGdTest < PokeAccessTest
  Map = LairMapScene
  Lair = PokeAccess::ZudLairMap
  Menus = PokeAccess::ZudLairMenus
  # A main stat as GameData::Stat.each_main yields it.
  Stat = Struct.new(:id, :name)
  STATS = [Stat.new(:HP, "HP"), Stat.new(:ATTACK, "Attack"), Stat.new(:DEFENSE, "Defense"), Stat.new(:SPEED, "Speed")]
  Move = Struct.new(:id)
  # A rental or party Pokemon as the menus read it.
  Mon = Struct.new(:name, :gender, :types, :ability_id, :item, :gmax, :ev, :moves, :shiny) do
    def male?; gender == 0; end
    def female?; gender == 1; end
    def gmaxFactor?; gmax; end
    def shiny?; shiny; end
  end
  Trainer = Struct.new(:party)

  def setup
    super
    @trainer = $Trainer
  end

  def teardown
    $Trainer = @trainer
    Lair.instance_variable_set(:@scene, nil)
    Menus.instance_variable_set(:@mode, nil)
    super
  end

  # ---- the map

  test "a Selection tile says the corner, then every way's path traced over the tiles, the lit one first, queued" do
    lair = crossroads
    run_map(lair) { Lair.poll }
    corner = PokeAccess.sentences([t(:zlair_hearts, :n => 3, :max => 4), t(:zlair_keys, :n => 2), "B3F"])
    up = "#{t(:dir_up)}: #{t(:zlair_ev_backpacker)}, #{t(:zlair_t_raid_type, :type => 'Type10')}, #{t(:zlair_t_selection)}"
    right = "#{t(:dir_right)}: #{t(:zlair_t_warp)}, #{t(:zlair_t_roadblock)}"
    options = t(:hint_label_key, :label => t(:zlair_options), :key => PokeAccess::KeyHints.key(:a, "Z"))
    assert_equal [[PokeAccess.sentences([corner, up, right, options]), false]], SpeakCapture.log
  end

  test "lighting another way says its path at once, and nothing while the light stays" do
    lair = crossroads
    run_map(lair) do
      Lair.poll
      SpeakCapture.clear
      light(lair, 3)
      Lair.poll
      Lair.poll
    end
    assert_equal [["#{t(:dir_right)}: #{t(:zlair_t_warp)}, #{t(:zlair_t_roadblock)}", true]], SpeakCapture.log
  end

  test "back on the same tile from the map view, the lit way's path is said again, queued" do
    lair = crossroads
    run_map(lair) do
      Lair.poll
      arrows(lair, [])
      lair.instance_variable_get(:@cursor).visible = true
      Lair.poll
      lair.instance_variable_get(:@cursor).visible = false
      arrows(lair, [0, 3])
      SpeakCapture.clear
      Lair.poll
    end
    up = "#{t(:dir_up)}: #{t(:zlair_ev_backpacker)}, #{t(:zlair_t_raid_type, :type => 'Type10')}, #{t(:zlair_t_selection)}"
    assert_equal [[up, false]], SpeakCapture.log
  end

  test "a battled raid is passed over, a flip is named, a random turn ends the trace, a closed loop ends it bare" do
    lair = crossroads
    lair.instance_variable_get(:@sprites)["pokemon0"].color.alpha = 0
    assert_equal [[:event, 1], [:selection]], Lair.trace(lair, 0)
    lair.tiles = { [5, 5] => [:selection, [0, 1, 3]], [6, 5] => [:turn, 5], [5, 6] => [:turn, 4],
                   [5, 4] => [:turn, 0], [5, 3] => [:turn, 3], [6, 3] => [:turn, 1], [6, 4] => [:turn, 2] }
    assert_equal [[:flip], [:selection]], Lair.trace(lair, 3), "turned back onto the tile it left"
    assert_equal [[:random]], Lair.trace(lair, 1)
    assert_equal [], Lair.trace(lair, 0), "four arrows turning into each other"
    assert_equal t(:dir_up), Lair.path_line(lair, 0)
  end

  test "a locked door ends a path; a switch is named and passed" do
    lair = crossroads
    lair.tiles = { [5, 5] => [:selection, [0]], [5, 4] => [:switch], [5, 3] => [:door] }
    assert_equal "#{t(:dir_up)}: #{t(:zlair_t_switch)}, #{t(:zlair_t_door)}", Lair.path_line(lair, 0)
  end

  test "the map view says its keys as it opens, then the tile the cursor selects; the boss's raid with its mark" do
    lair = crossroads
    cursor = lair.instance_variable_get(:@cursor)
    run_map(lair) do
      arrows(lair, [])
      cursor.visible = true
      x, y = lair.at(8, 1)
      cursor.x = x - 16 + 10
      cursor.y = y - 16 - 5
      Lair.poll
      Lair.poll
      cursor.x = 400
      Lair.poll
    end
    keys = [t(:hint_label_key, :label => t(:zlair_info), :key => PokeAccess::KeyHints.key(:c, t(:key_enter))),
            t(:hint_label_key, :label => t(:zlair_toggle), :key => PokeAccess::KeyHints.key(:a, "Z")),
            t(:hint_label_key, :label => t(:zlair_return), :key => PokeAccess::KeyHints.key(:b, t(:key_escape)))]
    boss = "#{t(:zlair_t_raid_type, :type => 'Type12')}, #{t(:zlair_boss)}"
    assert_equal [[PokeAccess.sentences(keys), false], [boss, true]], SpeakCapture.log
  end

  test "the map view names the plain tiles by their picture, and a battled raid as cleared" do
    lair = crossroads
    lair.instance_variable_get(:@sprites)["pokemon0"].color.alpha = 0
    {
      [5, 5] => t(:zlair_t_selection), [5, 4] => t(:zlair_ev_backpacker), [5, 3] => t(:zlair_t_raid_done),
      [5, 2] => t(:zlair_t_turn, :dir => t(:dir_right)), [6, 5] => t(:zlair_t_warp), [11, 10] => t(:zlair_t_roadblock),
      [2, 2] => t(:zlair_t_start)
    }.each do |square, said|
      assert_equal said, Lair.describe(lair, lair.at(square[0], square[1])), "for #{square.inspect}"
    end
    assert_nil Lair.describe(lair, lair.at(0, 9)), "bare ground"
  end

  test "the speed-up key is said once a lair, as its sign first shows while hints are said" do
    lair = crossroads
    run_map(lair) do
      arrows(lair, [])
      lair.instance_variable_get(:@sprites)["speedup"].visible = true
      3.times { Lair.poll }
    end
    assert_equal [[t(:hint_label_key, :label => t(:zlair_speed), :key => PokeAccess::KeyHints.key(:a, "Z")), false]],
                 SpeakCapture.log
  end

  test "outside a lair map the poll says nothing" do
    Lair.poll
    assert_nothing_spoken
  end

  # ---- the menus

  test "the rental screen says its state as it changes, then the slot the arrow points at with its data" do
    scene = MaxLairEventScene.new
    rentals = [mon("Charmander"), mon("Squirtle", :gender => 1, :item => :ORANBERRY, :gmax => true)]
    party = []
    with_stats do
      scene.script = { :pbRentalSelect => lambda do |s|
        s.instance_variable_set(:@rentals, rentals)
        s.instance_variable_set(:@rentalparty, party)
        s.instance_variable_set(:@textPos, [["Select 3 more rental Pokémon.", 230, -6]])
        s.instance_variable_set(:@sprites, { "rightarrow" => arrow(false, 0) })
        Menus.poll
        s.instance_variable_get(:@sprites)["rightarrow"] = arrow(true, 80 + 114)
        Menus.poll
        Menus.poll
      end }
      assert_equal :pbRentalSelect, scene.pbRentalSelect
    end
    state = PokeAccess.sentences(["DYNAMAX ADVENTURE", "Rental Party:", "Select 3 more rental Pokémon."])
    squirtle = PokeAccess.sentences(["Squirtle \xE2\x99\x80", t(:zud_raid_types, :list => "TypeWATER"),
                                     t(:zlair_ability, :name => "AbilityTORRENT"),
                                     t(:zlair_holding, :item => "ItemORANBERRY"), t(:dmax_factor),
                                     t(:zlair_trained, :stat => "Attack"),
                                     t(:sm_moves, :list => "MoveTACKLE, MoveWATERGUN")])
    assert_equal [[state, false], [PokeAccess::Verbosity.list_entry(squirtle, 2, 2), true]], SpeakCapture.log
    assert_equal squirtle, PokeAccess::Info.row_text, "the info key keeps the slot whole"
  end

  test "the swap screen opens on the new Pokemon whole and the party, then reads the member the arrow points at" do
    $Trainer = Trainer.new([mon("Charmander"), mon("Bulbasaur")])
    newcomer = mon("Eevee", :gender => 2, :ev => {})
    scene = MaxLairEventScene.new
    with_stats do
      scene.script = { :pbSwapSelect => lambda do |s, _pk|
        s.instance_variable_set(:@sprites, { "leftarrow" => arrow(true, 95 + 40) })
        Menus.poll
      end }
      scene.pbSwapSelect(newcomer)
    end
    eevee = PokeAccess.sentences(["Eevee", t(:zud_raid_types, :list => "TypeWATER"),
                                  t(:zlair_ability, :name => "AbilityTORRENT"),
                                  t(:sm_moves, :list => "MoveTACKLE, MoveWATERGUN")])
    opening = PokeAccess.sentences(["Select a party member to swap.", "#{t(:zlair_new)}: #{eevee}",
                                    "Current Party: Charmander, Bulbasaur", summary_hint])
    assert_equal [[opening, false], [PokeAccess::Verbosity.list_entry("Bulbasaur", 2, 2), false]], SpeakCapture.log
  end

  test "the item screen lists the party's held items and the offer, then each item for each member's turn" do
    $Trainer = Trainer.new([mon("Charmander", :item => :LEFTOVERS), mon("Bulbasaur")])
    scene = MaxLairEventScene.new
    with_stats do
      scene.script = {
        :pbItemSelect => lambda do |s|
          s.instance_variable_set(:@textPos, [])
          s.instance_variable_set(:@sprites, { "rightarrow" => arrow(false, 0) })
          s.pbDrawItemScreen([:FOCUSSASH, :WIDELENS])
          s.instance_variable_set(:@textPos, [["Select Charmander's item.", 250, -6]])
          s.instance_variable_get(:@sprites)["rightarrow"] = arrow(true, 61 + 40)
          Menus.poll
          s.pbDrawItemScreen([:FOCUSSASH])
          s.instance_variable_set(:@textPos, [["Select Bulbasaur's item.", 250, -6]])
          s.instance_variable_get(:@sprites)["rightarrow"] = arrow(true, 61)
          Menus.poll
        end
      }
      scene.pbItemSelect
    end
    opening = PokeAccess.sentences(["Current Party: Charmander, #{t(:zlair_holding, :item => 'ItemLEFTOVERS')}; " \
                                    "Bulbasaur", t(:zlair_offered, :list => "ItemFOCUSSASH, ItemWIDELENS"), summary_hint])
    assert_equal [[opening, false], [PokeAccess::Verbosity.list_entry("ItemWIDELENS", 2, 2), false],
                  [PokeAccess::Verbosity.list_entry("ItemFOCUSSASH", 1, 1), true]], SpeakCapture.log
  end

  test "the training screen lists each member's training and the courses, then the course the arrow points at" do
    $Trainer = Trainer.new([mon("Charmander"), mon("Bulbasaur", :ev => { :HP => 50, :ATTACK => 50 })])
    scene = MaxLairEventScene.new
    courses = [["Attack Training", 1], ["Balanced Training", 6]]
    with_stats do
      scene.script = {
        :pbTrainingSelect => lambda do |s|
          s.instance_variable_set(:@textPos, [["Select Charmander's training.", 230, -6]])
          s.instance_variable_set(:@sprites, { "rightarrow" => arrow(true, 61 + 40) })
          s.pbDrawStatScreen(courses)
          Menus.poll
        end
      }
      scene.pbTrainingSelect
    end
    members = "Charmander, #{t(:zlair_trained, :stat => 'Attack')}; Bulbasaur, #{t(:zlair_balanced)}"
    opening = PokeAccess.sentences(["Current Party: #{members}",
                                    t(:zlair_offered, :list => "Attack Training, Balanced Training"), summary_hint])
    assert_equal [[opening, false], [PokeAccess::Verbosity.list_entry("Balanced Training", 2, 2), false]],
                 SpeakCapture.log
  end

  test "the tutor's panel is said for each member it shows: the new move's painted data and the moves it knows" do
    $Trainer = Trainer.new([mon("Charmander"), mon("Bulbasaur")])
    scene = MaxLairEventScene.new
    party = $Trainer.party
    with_stats do
      scene.script = {
        :pbTutorSelect => lambda do |s|
          s.pbDrawTutorScreen(party[0], :EMBER)
          s.pbDrawTutorScreen(party[1], nil)
          s.pbDrawTutorScreen(party[1], nil)
        end,
        :pbDrawTutorScreen => lambda do |_s, _pk, move|
          rows = move ? [["Ember", 186, 166], ["BP: 40", 262, 194], ["AC: 100", 262, 214], ["PP: 25", 262, 234],
                         ["Scratch", 350, 170], ["Growl", 350, 192]] : [["No moves to learn.", 270, 198]]
          pbDrawTextPositions(Object.new, rows.map { |r| r + [0, nil, nil] })
        end
      }
      scene.pbTutorSelect
    end
    opening = PokeAccess.sentences(["Select a party member to tutor.", "Current Party: Charmander, Bulbasaur",
                                    summary_hint])
    ember = PokeAccess.sentences([PokeAccess::Verbosity.list_entry("Charmander", 1, 2),
                                  "#{t(:zlair_new)}, Ember, TypeTYPE1, #{t(:cat_physical)}", "BP: 40", "AC: 100",
                                  "PP: 25", t(:sm_moves, :list => "Scratch, Growl")])
    none = PokeAccess.sentences([PokeAccess::Verbosity.list_entry("Bulbasaur", 2, 2), "No moves to learn."])
    assert_equal [[opening, false], [ember, false], [none, true]], SpeakCapture.log
  end

  test "the prize screen reads the prize beside its arrow, a shiny one's sparkle with it" do
    prizes = [mon("Eevee"), mon("Ditto", :shiny => true)]
    scene = MaxLairEventScene.new
    with_stats do
      scene.script = {
        :pbPrizeSelect => lambda do |s, _list|
          s.instance_variable_set(:@sprites, { "partysprite0" => arrow(true, 60), "partysprite1" => arrow(true, 100),
                                               "rightarrow" => arrow(true, 105) })
          Menus.poll
        end
      }
      scene.pbPrizeSelect(prizes)
    end
    assert_equal [[PokeAccess::Verbosity.list_entry("Ditto, #{t(:pk_shiny)}", 2, 2), false]], SpeakCapture.log
  end

  test "the record screen is read whole once painted, its labels joined to their values; other layers ignored" do
    scene = MaxLairEventScene.new
    text = Object.new
    scene.script = {
      :pbEndlessRecordScreen => lambda do |s|
        s.instance_variable_set(:@changetext, text)
        pbDrawTextPositions(text, [["Pikachu", 236, 150, 0, nil, nil]])
        pbDrawTextPositions(text, [["Adventure Record", 256, 60, 2, nil, nil], ["Floor Reached:", 161, 250, 0, nil, nil],
                                   ["Pokémon Battled:", 161, 279, 0, nil, nil], ["B5F", 321, 250, 0, nil, nil],
                                   ["12", 321, 279, 0, nil, nil]])
        pbDrawTextPositions(Object.new, [["Elsewhere", 10, 10, 0, nil, nil]])
        Menus.poll
        Menus.poll
      end
    }
    scene.pbEndlessRecordScreen
    assert_equal [[PokeAccess.sentences(["Adventure Record", "Pikachu", "Floor Reached: B5F", "Pokémon Battled: 12"]),
                   false]], SpeakCapture.log
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A lair at a crossroads on square (5,5), the map drawn from (-64,-32): up runs past a Backpacker and raid 0 (its
  # icon on the type strip's row 10), turns right at an arrow and stops on a Selection tile; right lands on warp 0,
  # comes out of warp 1 at (10,10) and runs into a roadblock. Raid 1, the boss, sits at (8,1); the start at (2,2).
  def crossroads
    lair = Map.new
    lair.tiles = { [5, 5] => [:selection, [0, 3]], [5, 4] => [:event, 1], [5, 3] => [:raid, 0], [5, 2] => [:turn, 3],
                   [7, 2] => [:selection, [1, 2]], [6, 5] => [:warp], [10, 10] => [:warp], [11, 10] => [:roadblock],
                   [8, 1] => [:raid, 1], [2, 2] => [:start], [5, 1] => [:trap] }
    sp = Map::Sprite
    bg = sp.new(-64, -32, true)
    sprites = { "background" => bg, "lairkey" => sp.new(0, 0, true), "floorwindow" => sp.new(0, 0, true, nil, nil, "B3F"),
                "speedup" => sp.new(0, 0, false),
                "pokemon0" => sp.new(0, 0, true, Map::Tint.new(255)), "poketype0" => sp.new(0, 0, true, nil, Map::Crop.new(280)),
                "pokemon1" => sp.new(0, 0, true, Map::Tint.new(255)), "poketype1" => sp.new(0, 0, true, nil, Map::Crop.new(336)) }
    lair.instance_variable_set(:@sprites, sprites)
    sprites["mapWarpPoint0"] = sp.new(*lair.at(6, 5))
    sprites["mapWarpPoint1"] = sp.new(*lair.at(10, 10))
    player = sp.new(*lair.at(5, 5))
    player.visible = true
    tiles = lair.tiles.keys.map { |c, r| sp.new(lair.at(c, r)[0], lair.at(c, r)[1], c != 5 || r != 1) }
    { :@player => player, :@mapWarpPoint => [[0, 0], [0, 0]], :@size => 2, :@maxHearts => 4, :@knockouts => 3,
      :@lairKeys => 2, :@cursor => sp.new(0, 0, false), :@mapSprites => [bg] + tiles + [player] }.each do |k, v|
      lair.instance_variable_set(k, v)
    end
    (0..3).each { |i| lair.instance_variable_set(:"@arrow#{i}", sp.new(0, 0, false, Map::Tint.new(0))) }
    arrows(lair, [0, 3])
    light(lair, 0)
    lair
  end

  # Shows the arrows of the ways given, hiding the others.
  def arrows(lair, ways)
    (0..3).each { |i| lair.instance_variable_get(:"@arrow#{i}").visible = ways.include?(i) }
  end

  # Lights way i's arrow as the choice loop does, the others cleared.
  def light(lair, way)
    (0..3).each { |i| lair.instance_variable_get(:"@arrow#{i}").color.alpha = (i == way ? 200 : 0) }
  end

  # Runs the block inside the lair's scene, as its loop's frames.
  def run_map(lair, &blk)
    lair.script = lambda { |_s| blk.call }
    assert_equal :map_closed, lair.pbStartMapScene(0)
  end

  # An arrow or icon sprite at height y.
  def arrow(visible, y)
    LairMapScene::Sprite.new(0, y, visible)
  end

  def summary_hint
    t(:hint_label_key, :label => "Summary", :key => PokeAccess::KeyHints.key(:a, "Z"))
  end

  # A Pokemon of the lair: Water-type, Torrent, Tackle and Water Gun, trained in Attack, ivars overridden by opts.
  def mon(name, opts = {})
    m = Mon.new(name, 0, [:WATER], :TORRENT, nil, false, { :HP => 252, :ATTACK => 252 },
                [Move.new(:TACKLE), Move.new(:WATERGUN)], false)
    opts.each { |k, v| m.send("#{k}=", v) }
    m
  end

  # Runs the block with GameData::Stat.each_main walking STATS, the stub's own (or none) put back after.
  def with_stats
    meta = (class << GameData::Stat; self; end)
    had = meta.method_defined?(:each_main) ? GameData::Stat.method(:each_main) : nil
    GameData::Stat.define_singleton_method(:each_main) { |&b| STATS.each(&b) }
    yield
  ensure
    had ? GameData::Stat.define_singleton_method(:each_main, had) : meta.send(:remove_method, :each_main)
  end
end
