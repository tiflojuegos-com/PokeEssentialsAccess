# ZUD Mechanics' release for Essentials 20 (Keishou), which names its sprites and tile questions otherwise than the one for
# 19 the other tests here drive: the Max Lair map and its tutor, swap and prize screens (plugins/zud_max_lair.rb), the den's
# entry and rewards screens (plugins/zud_raid_dens.rb) and the database (plugins/zud_raid_database.rb), on stand-ins of its
# scripts' shape.
class ZudV20GdTest < PokeAccessTest
  T = PokeAccess::I18n
  Map = PokeAccess::ZudLairMap
  Den = PokeAccess::ZudRaidDens
  Menus = PokeAccess::ZudLairMenus
  DB = PokeAccess::ZudRaidDatabase

  Shade = Struct.new(:alpha)
  Crop = Struct.new(:y)
  # A type as GameData::Type.each yields it: where this release cuts its icon from the strip, 28 pixels a row.
  TypeIcon = Struct.new(:id, :icon_position)
  FIRE_ROW = 10
  WATER_ROW = 11
  TYPE_ICONS = [TypeIcon.new(:NORMAL, 0), TypeIcon.new(:FIRE, FIRE_ROW), TypeIcon.new(:WATER, WATER_ROW)]

  # A sprite of the map: its place, whether it shows, the arrow's colour and the row of the type strip an icon crops.
  class Tile
    attr_accessor :x, :y, :visible, :color, :src_rect

    def initialize(x, y, visible = true)
      @x = x
      @y = y
      @visible = visible
      @color = Shade.new(0)
      @src_rect = Crop.new(0)
    end
  end

  # LairMapScene as MaxLair_Map.rb and MaxLair_Controls.rb lay it out, with their two questions about a tile.
  class LairScene
    attr_accessor :sprites, :player, :cursor, :keycount, :knockouts

    # What lair_StartBattle does to a raid it fights: the silhouette and the type icon go, the tile stays.
    def battle(i)
      @sprites["Shadow_#{i}"].visible = false
      @sprites["Type_#{i}"].visible = false
    end

    def initialize(tiles, arrows, lit)
      @sprites = { "background" => Tile.new(-100, -200) }
      tiles.each do |key, at|
        @sprites[key] = Tile.new(at[0], at[1])
        next unless key =~ /\APokemon_(\d+)\z/
        @sprites["Shadow_#{$1}"] = Tile.new(at[0] + 16, at[1] - 16)
        @sprites["Type_#{$1}"] = Tile.new(at[0] - 32, at[1] + 4)
        @sprites["Type_#{$1}"].src_rect.y = FIRE_ROW * 28
      end
      @player = @sprites["Player"] = Tile.new(164, 264)
      @map_sprites = @sprites.values
      @cursor = @sprites["cursor_ui"] = Tile.new(0, 0, false)
      4.times do |i|
        @sprites["arrow_ui_#{i}"] = Tile.new(0, 0, arrows.include?(i))
        @sprites["arrow_ui_#{i}"].color = Shade.new(i == lit ? 200 : 0)
      end
      @max_hearts = 3
      @knockouts = 2
      @keycount = 0
      @lair_pokemon = Array.new(11) { Struct.new(:types).new([:FIRE]) }
      @map_name = "Dynite Den"
    end

    def lair_OnTile?(tile = "", coords = nil)
      @sprites.keys.any? { |k| k.include?(tile) && @sprites[k].visible && coords == [@sprites[k].x, @sprites[k].y] }
    end

    def lair_TileType(tile = "", coords = nil)
      return nil unless lair_OnTile?(tile, coords)
      @sprites.keys.each do |key|
        next if !key.include?(tile) || !@sprites[key].visible || coords != [@sprites[key].x, @sprites[key].y]
        case key.split("_").first
        when "TurnNorth" then return 0
        when "TurnSouth" then return 1
        when "TurnWest" then return 2
        when "TurnEast" then return 3
        when "TurnRandom" then return 4
        when "TurnFlip" then return 5
        when "NPCEquip" then return 1
        when "SelectNS" then return [0, 1]
        else return key.split("_").last.to_i
        end
      end
    end
  end

  def scene(tiles, arrows = [0], lit = 0)
    LairScene.new(tiles, arrows, lit)
  end

  def setup
    super
    @kept_players = [$Trainer, $player]
    GameData::Type.define_singleton_method(:each) { |&blk| TYPE_ICONS.each(&blk) }
  end

  def teardown
    $Trainer, $player = @kept_players
    GameData::Type.singleton_class.send(:remove_method, :each)
    super
  end

  def up; T.t(:dir_up); end
  def right; T.t(:dir_right); end

  test "a way's path is traced over the tiles by name, up to the Selection tile it stops on" do
    s = scene("NPCEquip_0" => [164, 232], "Pokemon_3" => [164, 200], "SelectNS_0" => [164, 168])
    fire = T.t(:zlair_t_raid_type, :type => PokeAccess::Data.type_name(:FIRE))
    assert_equal "#{up}: #{T.t(:zlair_ev_backpacker)}, #{fire}, #{T.t(:zlair_t_selection)}", Map.path_line(s, 0)
  end

  test "a raid already battled keeps its tile but names nothing along a route, and says it is cleared on the map; the boss's has its mark" do
    s = scene("Pokemon_3" => [164, 232], "Pokemon_10" => [164, 200], "SelectNS_0" => [164, 168])
    s.battle(3)
    assert_equal true, s.sprites["Pokemon_3"].visible, "as the game leaves it"
    fire = T.t(:zlair_t_raid_type, :type => PokeAccess::Data.type_name(:FIRE))
    assert_equal "#{up}: #{fire}, #{T.t(:zlair_boss)}, #{T.t(:zlair_t_selection)}", Map.path_line(s, 0)
    assert_equal T.t(:zlair_t_raid_done), Map.describe(s, [164, 232])
    assert_equal "#{fire}, #{T.t(:zlair_boss)}", Map.describe(s, [164, 200])
  end

  test "the info key has the corner and every way, the lit one first, as the arrow keys change it" do
    s = scene({ "SelectNS_0" => [164, 200], "SelectNS_1" => [196, 264] }, [0, 3], 3)
    with_state(nil) do
      Map.run(s) do
        Map.poll
        first = PokeAccess::Info.instance_variable_get(:@row)
        assert_equal Map.route_line(s, 3), first
        refute_includes first, T.t(:zlair_options), "no key hints in it"
        s.sprites["arrow_ui_3"].color = Shade.new(0)
        s.sprites["arrow_ui_0"].color = Shade.new(200)
        Map.poll
        assert_equal Map.route_line(s, 0), PokeAccess::Info.instance_variable_get(:@row)
      end
    end
    assert_nil PokeAccess::Info.instance_variable_get(:@row), "and lets it go once the choice is made"
  end

  test "the info key has the tile the map view's cursor is on" do
    s = scene("NPCEquip_0" => [100, 100])
    s.cursor.visible = true
    s.cursor.x = 90
    s.cursor.y = 90
    with_hints_off do
      Map.run(s) do
        Map.poll
        assert_equal T.t(:zlair_ev_backpacker), PokeAccess::Info.instance_variable_get(:@row)
      end
    end
  end

  test "an arrow tile turns the trace, and a warp carries it to the next shown warp, as lair_WarpPlayer picks" do
    s = scene("TurnEast_0" => [164, 232], "Warp_0_1" => [196, 232], "Warp_1_2" => [300, 100], "SelectNS_0" => [332, 100])
    assert_equal "#{up}: #{T.t(:zlair_t_warp)}, #{T.t(:zlair_t_selection)}", Map.path_line(s, 0)
  end

  test "a raid tile names the type its icon crops, which on a double type may be the second" do
    s = scene("Pokemon_3" => [164, 232], "SelectNS_0" => [164, 200])
    s.sprites["Type_3"].src_rect.y = WATER_ROW * 28
    water = T.t(:zlair_t_raid_type, :type => PokeAccess::Data.type_name(:WATER))
    assert_equal "#{up}: #{water}, #{T.t(:zlair_t_selection)}", Map.path_line(s, 0)
  end

  test "a raid tile with no icon names no type" do
    s = scene("Pokemon_3" => [164, 232], "SelectNS_0" => [164, 200])
    s.sprites.delete("Type_3")
    assert_equal "#{up}: #{T.t(:zlair_t_raid)}, #{T.t(:zlair_t_selection)}", Map.path_line(s, 0)
  end

  test "a Reset tile is named and ends the trace, as it sends the icon back to the Start tile" do
    s = scene("Reset_0" => [164, 232], "SelectNS_0" => [164, 200])
    assert_equal "#{up}: #{T.t(:zlair_t_reset)}", Map.path_line(s, 0)
  end

  test "a Flare is named and passed over" do
    s = scene("Flare_0" => [164, 232], "SelectNS_0" => [164, 200])
    assert_equal "#{up}: #{T.t(:zlair_t_flare)}, #{T.t(:zlair_t_selection)}", Map.path_line(s, 0)
  end

  test "the map view names a Reset and a Flare tile" do
    s = scene("Reset_0" => [100, 100], "Flare_0" => [200, 200])
    assert_equal T.t(:zlair_t_reset), Map.describe(s, [100, 100])
    assert_equal T.t(:zlair_t_flare), Map.describe(s, [200, 200])
  end

  test "the last warp carries it back to the first" do
    s = scene("Warp_0_1" => [10, 10], "Warp_1_2" => [164, 232])
    assert_equal Map.place(s, s.sprites["Warp_0_1"]), Map.warp_landing_v20(s, [164, 232])
  end

  test "a door, a roadblock and a random turn stop the trace" do
    { "Door_0" => :door, "Block_0" => :roadblock, "TurnRandom_0" => :random }.each do |key, word|
      s = scene(key => [164, 232], "SelectNS_0" => [164, 200])
      assert_equal "#{up}: #{T.t(:"zlair_t_#{word}")}", Map.path_line(s, 0), key
    end
  end

  test "the Selection tile says the corner, then each way, the lit one first, queued, by the arrows it shows" do
    s = scene({ "SelectNS_0" => [164, 200], "SelectNS_1" => [196, 264] }, [0, 3], 3)
    s.sprites["keycount"] = Tile.new(0, 0, true)
    s.keycount = 4
    with_state(nil) { Map.run(s) { Map.poll } }
    line, interrupt = SpeakCapture.log[0]
    assert_equal false, interrupt
    assert_includes line, T.t(:zlair_hearts, :n => 2, :max => 3)
    assert_includes line, T.t(:zlair_keys, :n => 4)
    assert_operator line.index(right), :<, line.index(up), "the lit way first"
  end

  test "the hearts and keys come from the adventure where it keeps them" do
    s = scene({})
    s.sprites["keycount"] = Tile.new(0, 0, true)
    with_state(Struct.new(:knockouts, :keycount).new(1, 7)) do
      assert_includes Map.corner(s), T.t(:zlair_hearts, :n => 1, :max => 3)
      assert_includes Map.corner(s), T.t(:zlair_keys, :n => 7)
    end
  end

  test "the keys are left out while their sprite is hidden" do
    s = scene({ "SelectNS_0" => [164, 200] })
    s.sprites["keycount"] = Tile.new(0, 0, false)
    with_state(nil) { refute_includes Map.corner(s), T.t(:zlair_keys, :n => 0) }
  end

  test "the map view says the tile the cursor reacts to, as lair_CursorReact picks it, traps and shadows aside" do
    s = scene("NPCEquip_0" => [100, 100], "Trap_0_1" => [200, 200], "Shadow_3" => [300, 300])
    s.cursor.visible = true
    s.cursor.x = 90
    s.cursor.y = 90
    assert_equal [100, 100], Map.hovered(s, s.cursor)
    assert_equal T.t(:zlair_ev_backpacker), Map.describe(s, [100, 100])
    s.cursor.x = 190
    s.cursor.y = 190
    assert_nil Map.hovered(s, s.cursor), "a trap is not named"
    s.cursor.x = 290
    s.cursor.y = 290
    assert_nil Map.hovered(s, s.cursor), "nor a Pokemon's shadow"
  end

  test "the speed-up key is said by the sign of this release" do
    s = scene({})
    s.sprites["speedup_ui"] = Tile.new(0, 0, true)
    s.sprites["arrow_ui_0"].visible = false
    Map.run(s) { Map.poll }
    assert_equal [[Map.hint(:zlair_speed, :a, nil), false]], SpeakCapture.log
  end

  # The menu's header row, as this release paints it with the item and training screens.
  test "a menu's header row is found at this release's height" do
    s = Object.new
    s.instance_variable_set(:@textPos, [["Pikachu", 46, 100], ["Select Pikachu's item.", 250, 5]])
    assert_equal "Select Pikachu's item.", Menus.header(s)
  end

  # A Pokemon as this release's menus read it, which asks for the Gigantamax mark by its own name.
  Mon = Struct.new(:name, :gmax, :shiny) do
    def gmax_factor?; gmax; end
    def shiny?; shiny; end
    def types; [:FIRE]; end
    def moves; []; end
    def ev; {}; end
  end

  # MaxLairEventScene's sprites, as far as the arrows the menus are read by; pbGenerateTutorMove marks this release.
  class MenuScene
    attr_reader :sprites

    def initialize(sprites)
      @sprites = sprites
    end

    def pbGenerateTutorMove(_pk, _old = nil); nil; end
  end

  # The tutor's panel as pbDrawTutorScreen paints it, as [text, source, x, y]: the header, then the new move and the
  # moves known, or that there is nothing to learn.
  def tutor_rows(left, move = true)
    top = [["Select #{left} more move(s) to tutor.", :positions, 230, 5]]
    return top + [["No moves to learn.", :positions, 270, 208]] unless move
    top + [["Ember", :positions, 186, 176], ["BP: 40", :positions, 262, 204], ["AC: 100", :positions, 262, 224],
           ["PP: 25", :positions, 262, 244], ["Scratch", :positions, 350, 180], ["Growl", :positions, 350, 202]]
  end

  def ember_parts(name, i)
    [PokeAccess::Verbosity.list_entry(name, i, 2), "#{T.t(:zlair_new)}, Ember, TypeTYPE1, #{T.t(:cat_physical)}",
     "BP: 40", "AC: 100", "PP: 25", T.t(:sm_moves, :list => "Scratch, Growl")]
  end

  def with_party(*names)
    $Trainer = nil
    $player = Struct.new(:party).new(names.map { |n| Mon.new(n, false, false) })
    yield $player.party
  end

  test "the tutor's header is no move name, and is said only as it changes" do
    with_party("Charmander", "Bulbasaur") do |party|
      s = MenuScene.new({})
      Menus.tutor_panel(s, party[0], :EMBER, tutor_rows(3))
      assert_equal [[PokeAccess.sentences(["Select 3 more move(s) to tutor."] + ember_parts("Charmander", 1)), false]],
                   SpeakCapture.log, "first read queued, with the header"
      SpeakCapture.clear
      Menus.tutor_panel(s, party[1], :EMBER, tutor_rows(3))
      assert_equal [[PokeAccess.sentences(ember_parts("Bulbasaur", 2)), true]], SpeakCapture.log, "the same header, unsaid"
      SpeakCapture.clear
      Menus.tutor_panel(s, party[1], nil, tutor_rows(2, false))
      assert_equal [[PokeAccess.sentences(["Select 2 more move(s) to tutor.",
                                           PokeAccess::Verbosity.list_entry("Bulbasaur", 2, 2), "No moves to learn."]), true]],
                   SpeakCapture.log, "a new count, said; the header is no line of the panel"
      SpeakCapture.clear
      Menus.tutor_panel(s, party[1], nil, tutor_rows(2, false))
      assert_equal [], SpeakCapture.log, "a repaint says nothing"
    end
  end

  test "the tutor's info key has the panel with its header, whoever the cursor is on" do
    with_party("Charmander", "Bulbasaur") do |party|
      s = MenuScene.new({})
      Menus.tutor_panel(s, party[0], :EMBER, tutor_rows(3))
      Menus.tutor_panel(s, party[1], :EMBER, tutor_rows(3))
      assert_equal PokeAccess.sentences(["Select 3 more move(s) to tutor."] + ember_parts("Bulbasaur", 2)), info_row
    end
  end

  test "this release's tutor opens without the heading it does not paint" do
    with_party("Charmander") do
      Menus.tutor_opening(MenuScene.new({}))
      assert_equal 1, SpeakCapture.log.length
      refute_includes SpeakCapture.log[0][0], "Select a party member to tutor."
      assert_includes SpeakCapture.log[0][0], "Current Party: Charmander"
    end
  end

  test "the Gigantamax mark is asked by this release's name, on a rental and on the newcomer of a swap" do
    plain = Mon.new("Pikachu", false, false)
    gmax = Mon.new("Pikachu", true, false)
    refute_includes Menus.pokemon_line(plain), T.t(:dmax_factor)
    assert_includes Menus.pokemon_line(gmax), T.t(:dmax_factor)
    with_party("Charmander") do
      Menus.swap_opening(gmax)
      assert_includes SpeakCapture.log[0][0], T.t(:dmax_factor)
    end
  end

  test "the swap screen says the member the arrow points at, and the info key has it whole" do
    with_party("Charmander", "Bulbasaur") do |party|
      s = MenuScene.new("leftarrow" => Tile.new(0, 95 + 40))
      Menus.run(s, :swap) { Menus.poll }
      assert_equal [[PokeAccess::Verbosity.list_entry("Bulbasaur", 2, 2), false]], SpeakCapture.log
      assert_equal Menus.pokemon_line(party[1]), info_row
    end
  end

  test "the prize screen says the prize the arrow stands beside, and the info key has it whole" do
    prizes = [Mon.new("Eevee", false, false), Mon.new("Ditto", false, true)]
    s = MenuScene.new("partysprite0" => Tile.new(0, 60), "partysprite1" => Tile.new(0, 100), "rightarrow" => Tile.new(0, 105))
    Menus.run(s, :prize, prizes) { Menus.poll }
    assert_equal [[PokeAccess::Verbosity.list_entry("Ditto, #{T.t(:pk_shiny)}", 2, 2), false]], SpeakCapture.log
    assert_equal Menus.pokemon_line(prizes[1]), info_row
  end

  test "the item screen keeps the item for the info key, the training screen the course" do
    s = MenuScene.new("rightarrow" => Tile.new(0, 61))
    Menus.run(s, :items, [:POTION]) { Menus.poll }
    assert_equal [:item, :POTION], [PokeAccess::Info.instance_variable_get(:@kind), PokeAccess::Info.instance_variable_get(:@data)]
    PokeAccess::Cursor.reset(s, :zlair_row)
    Menus.run(s, :training, [["Attack Training", :ATTACK]]) { Menus.poll }
    assert_equal "Attack Training", info_row
    assert_equal :text, PokeAccess::Info.instance_variable_get(:@kind)
  end

  # MaxRaidScene with @rules and @pkmn in place of its own instance variables, its overlay painted 11 pixels lower.
  class DenScene
    attr_reader :overlay

    def initialize(rules, pkmn)
      @rules = rules
      @pkmn = pkmn
      @overlay = Object.new
      @bonuses = [0, 4]
    end

    def raid_FieldHash; {}; end
  end

  Boss = Struct.new(:species_data, :gmax) do
    def gmax?; gmax; end
  end

  def den
    species = Struct.new(:id).new(:PIKACHU)
    DenScene.new({ :rank => 4, :hard => true, :loot => false, :size => 2, :weather => :Rain, :environ => :Cave }, Boss.new(species, true))
  end

  def noted(s, rows)
    Den.watch(s, :entry)
    rows.each { |text, x, y| Den.note(s.overlay, text, x, y) }
    Den.instance_variable_get(:@rows).dup
  ensure
    Den.instance_variable_set(:@scene, nil)
    Den.instance_variable_set(:@phase, nil)
    Den.instance_variable_set(:@said, true)
  end

  test "the den reads its settings from @rules and the boss from @pkmn" do
    s = den
    assert_equal 4, Den.rule(s, :@rank, :rank)
    parts = Den.boss_parts(s)
    assert_includes parts, T.t(:zden_stars, :n => 4)
    assert_includes parts, T.t(:dmax_factor)
    assert_includes parts, T.t(:zden_hard)
    refute_includes parts, T.t(:zden_loot)
    assert_includes Den.field_line(s, "FIELD"), T.t(:w_rain)
    assert_includes Den.field_line(s, "FIELD"), T.t(:zden_env_cavern)
  end

  test "the entry screen's labels are told apart at this release's height" do
    s = den
    rows = noted(s, [["MAX RAID DEN", 25, 32], ["Leave Den", 403, 154], ["Enter Den", 403, 217], ["Set Party", 111, 295],
                     ["FIELD", 450, 19], ["Battle ends in 10 turns, or after 3 knock outs.", 287, 276]])
    line = Den.entry_line(s, rows)
    assert_equal 0, line.index("MAX RAID DEN")
    assert_includes line, "Battle ends in 10 turns"
    assert_includes line, "FIELD: "
  end

  test "the rewards screen's rows are told apart, the ability from Exit at the same height" do
    s = den
    rows = noted(s, [["You caught Pikachu!", 270, 32], ["Exit", 393, 295], ["Lvl. 50", 38, 88], ["Ability: Static", 20, 295]])
    line = Den.rewards_line(s, rows)
    assert_equal 0, line.index("You caught Pikachu!")
    assert_includes line, "Lvl. 50"
    assert_includes line, "Ability: Static"
  end

  # RaidDataScene's overlays, as Raid_Database.rb keeps them.
  class DataScene
    attr_reader :overlay, :pagetext

    def initialize
      @overlay = Object.new
      @pagetext = Object.new
      @sprites = {}
    end
  end

  test "the database's filter values and its count are found at this release's heights, the species name too" do
    s = DataScene.new
    DB.open(s)
    SpeakCapture.clear
    DB.note(s.overlay, "[Fire]", 181)
    assert_equal "Fire", DB.instance_variable_get(:@values)[2]
    DB.note(s.overlay, "Available Pokémon: 12", 346)
    assert_equal [["Available Pokémon: 12", false]], SpeakCapture.log
    SpeakCapture.clear
    DB.selecting(true)
    DB.note(s.overlay, "Pikachu", 352)
    assert_equal [["Pikachu", true]], SpeakCapture.log
  ensure
    DB.close
  end

  test "the species page says which of the species' raid forms it is, from this release's list" do
    species = Struct.new(:types, :species, :id, :get_raid_forms)
    assert_equal T.t(:zud_raid_form, :n => 2, :tot => 3), DB.form_text(species.new([:FIRE], :X, :X_1, [:X, :X_1, :X_2]))
    assert_nil DB.form_text(species.new([:FIRE], :X, :X, [:X])), "a species with one has nothing to say"
  end

  test "the species page's types come from this release's types" do
    sp = Struct.new(:types, :species, :id).new([:FIRE, :WATER], :X, :X)
    rows = DB.pictures(sp)
    fire = (GameData::Type.get(:FIRE).name rescue "FIRE")
    water = (GameData::Type.get(:WATER).name rescue "WATER")
    assert_equal [[T.t(:zud_raid_types, :list => "#{fire}, #{water}"), :positions, 367, 194]], rows
  end

  private

  # What the info key holds as its line.
  def info_row; PokeAccess::Info.instance_variable_get(:@row); end

  # Runs the block with key hints left unsaid.
  def with_hints_off
    meta = (class << PokeAccess::Verbosity; self; end)
    meta.send(:alias_method, :v20_spec_hints, :hints?)
    PokeAccess::Verbosity.define_singleton_method(:hints?) { false }
    yield
  ensure
    meta.send(:alias_method, :hints?, :v20_spec_hints)
    meta.send(:remove_method, :v20_spec_hints)
  end

  # Runs the block with the adventure's state as the map asks for it.
  def with_state(adventure)
    meta = (class << Map; self; end)
    meta.send(:alias_method, :v20_spec_state, :state)
    Map.define_singleton_method(:state) { adventure }
    yield
  ensure
    meta.send(:alias_method, :state, :v20_spec_state)
    meta.send(:remove_method, :v20_spec_state)
  end
end
