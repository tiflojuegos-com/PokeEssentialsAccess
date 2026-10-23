# Soulstones 2's raid adventures (games/soulstones2/raid_adventure.rb): each menu box as it becomes the selected one,
# the overlay's new words, the crossroads' paths, the free view's tile, the corner counters and the lair's title card.

SS2AdvNamed = Struct.new(:name)
SS2AdvColor = Struct.new(:alpha)
SS2AdvRect = Struct.new(:y)
SS2AdvText = Struct.new(:text)
SS2AdvWindow = Struct.new(:text, :visible)
SS2AdvOverlay = Struct.new(:bitmap)
SS2AdvMove = Struct.new(:name, :type, :total_pp, :base_damage, :accuracy, :category)
SS2AdvRaidMon = Struct.new(:item_id)
SS2AdvType = Struct.new(:name, :icon_position)
SS2AdvAdventure = Struct.new(:style, :hearts, :max_hearts, :keys, :floor, :map)

# A Pokemon as the adventure's boxes show it; options override the fields a test is about.
class SS2AdvMon
  attr_reader :name, :gender, :hp, :totalhp, :status, :level, :types, :tera_type

  def initialize(name, gender, opts = {})
    @name = name
    @gender = gender
    @hp = opts.fetch(:hp, 10)
    @totalhp = opts.fetch(:totalhp, 10)
    @level = opts.fetch(:level, 20)
    @status = opts.fetch(:status, :NONE)
    @item_name = opts[:item]
    @shiny = opts[:shiny]
    @ev = opts.fetch(:ev, {})
    @types = opts.fetch(:types, [:FIRE])
    @ability_name = opts.fetch(:ability, "Mar Llamas")
    @move_names = opts.fetch(:moves, ["Ascuas", "Gruñido"])
    @tera_type = opts.fetch(:tera, :WATER)
    @gmax = opts.fetch(:gmax, true)
  end

  def ev; Hash.new(0).merge(@ev); end
  def ability; @ability_name && SS2AdvNamed.new(@ability_name); end
  def moves; @move_names.map { |m| SS2AdvNamed.new(m) }; end
  def fainted?; @hp <= 0; end
  def hasItem?; !@item_name.nil?; end
  def item; SS2AdvNamed.new(@item_name); end
  def shiny?; @shiny ? true : false; end
  def gmax_factor?; @gmax; end
end

# An item as a square holds it: its name, its id and, for a machine, the move it teaches.
class SS2AdvItem
  attr_reader :name, :move, :id

  def initialize(name, move = nil, id = :POTION)
    @name = name
    @move = move
    @id = id
  end

  def is_machine?; !@move.nil?; end
end

# What every adventure box keeps: the content its reader reads (@pokemon, @item or @move), the lair's style, the count
# an item square paints, the rows a painted box draws as it is selected, and where the box stands.
class SS2AdvBox
  attr_accessor :x, :y

  def initialize(content, opts = {})
    @pokemon = content
    @item = content
    @move = content
    @style = opts[:style]
    @quantity = opts.fetch(:qty, 0)
    @rows = opts[:rows]
    @x = opts.fetch(:x, 166)
    @y = opts.fetch(:y, 44)
    @selected = false
  end

  def selected=(value)
    return if @selected == value
    @selected = value
    pbDrawTextPositions(nil, @rows.map { |r| [r, 0, 0] }) if @rows && value
  end

  def setItemValues(item, qty = 0)
    @item = item
    @quantity = qty
  end

  def pokemon=(pk); @pokemon = pk; end
end

class AdventurePartyDatabox < SS2AdvBox; end
class AdventureRentalDatabox < SS2AdvBox; end
class AdventureRewardbox < SS2AdvBox; end
class AdventureItembox < SS2AdvBox; end
class AdventureMovebox < SS2AdvBox; end
class AdventureAttributebox < SS2AdvBox; end
class AdventureDynamaxbox < SS2AdvBox; end

# The adventure menus' scene: an overlay the menus paint their words on, and the two menus that lay boxes out beside
# their words (an exchange's offer, the record's party). party replaces the members a menu shows (the record's
# recorded party, the exchange's rental party) and bar the record's bottom bar; picking makes the player pick the
# first member inside the exchange.
class AdventureMenuScene
  attr_writer :party, :bar, :picking

  def initialize; @sprites = { "overlay" => SS2AdvOverlay.new(Object.new) }; end
  def pbStartScene(_style = :Basic); end
  def pbUpdate; end

  # The close, whose fade-out updates the scene as it goes, as the game's does.
  def pbEndScene
    pbUpdate
  end

  # The exchange in the game's order: the offer's box and the party's, the first member selected, then the key
  # buttons, heading, question, the offer's label and two button hints painted. A pick repaints the heading alone,
  # and only then are the picked member and the offer traded between their boxes.
  def pbExchangeMenu(pk)
    party = members
    @sprites["pokemon"] = AdventureRentalDatabox.new(pk, :style => :Basic, :x => 166, :y => 140)
    party.each_with_index do |mon, i|
      @sprites["party_#{i}"] = AdventurePartyDatabox.new(mon, :style => :Basic)
      @sprites["party_#{i}"].selected = (i == 0)
    end
    pbDrawImagePositions(overlay, [["Graphics/Pictures/Adventure/buttons", 178, 244, 0, 0, 32, 32],
                                   ["Graphics/Pictures/Adventure/buttons", 290, 244, 32, 0, 32, 32]])
    pbDrawTextPositions(overlay, [["RENTAL PARTY", 79, 8], ["Add it?", 337, 12], ["New Pokemon!", 218, 102],
                                  ["View Summary", 218, 254], ["Keep Party", 330, 254]])
    return unless @picking
    pbDrawTextPositions(overlay, [["RENTAL PARTY", 79, 8]])
    @sprites["party_0"].pokemon = pk
    @sprites["party_0"].selected = false
    @sprites["pokemon"].pokemon = party[0]
  end

  # The record: a box per member of the recorded party, then heading, party heading and the bar's hint painted first,
  # then the data down the left panel.
  def pbRecordMenu
    members.each_with_index do |pk, i|
      @sprites["rental_#{i}"] = AdventureRentalDatabox.new(pk, :x => 166, :y => 44 + 96 * i)
    end
    rows = [["RECORD DATA", 79, 8], ["Endless party:", 337, 12]] + (@bar || [["Summary", 56, 364]])
    [["Adventure Map:", "Lair"], ["Floor Reached:", "5"], ["Battles Won:", "9"]].each_with_index do |(k, v), i|
      rows.push([k, 10, 64 + 96 * i], [v, 10, 96 + 96 * i])
    end
    pbDrawTextPositions(overlay, rows)
  end

  def add(key, sprite); @sprites[key] = sprite; end
  def overlay; @sprites["overlay"].bitmap; end
  def paint(words); pbDrawTextPositions(overlay, words.map { |w| [w, 0, 0] }); end

  # The members a menu shows: the party given, else three genderless ones, Mon0 to Mon2.
  def members
    @party || (0..2).map { |i| SS2AdvMon.new("Mon#{i}", 2) }
  end
end

# A lair tile as the map's sprite of it: its kind and coordinates, a battle's index, a warp's destination, a switch's
# position, whether a trap is hidden, whether the party already used it (the game deactivates a chest once opened),
# the tint of an unvisited one and the description its panel shows. As the game's: a used tile is neither interactable
# nor hidden, and the cursor reacts to none that is hidden, used or a plain way (NO_CURSOR).
class SS2AdvTile
  NAMES = { :Battle => "Battle", :Chest => "Chest", :Pathway => "Pathway", :Crossroad => "Crossroad",
            :TurnNorth => "Turn North", :TurnSouth => "Turn South", :TurnWest => "Turn West", :TurnEast => "Turn East",
            :HiddenTrap => "Hidden Trap", :Warp => "Warp", :Switch => "Switch", :StartPoint => "Start Point" }
  NO_CURSOR = [:Pathway]
  attr_reader :tile_id, :battle_id, :coords, :warp_point, :description
  attr_accessor :tint

  def initialize(id, x, y, opts = {})
    @tile_id = id
    @coords = [x, y]
    @battle_id = opts[:battle]
    @hidden = opts[:hidden]
    @used = opts[:used]
    @warp_point = opts[:warp]
    @on = opts[:on]
    @description = opts[:desc]
    @tint = 0
  end

  def tile; SS2AdvNamed.new(NAMES[@tile_id]); end
  def interactable?; !@used; end
  def hidden?; interactable? && @hidden ? true : false; end
  def cursor_react?; !hidden? && !NO_CURSOR.include?(@tile_id) && !@used; end
  def switch_on?; @on ? true : false; end
  def color; SS2AdvColor.new(@tint); end
  def isTile?(*ids); ids.include?(@tile_id); end
end

# A route arrow, coloured while lit.
class SS2AdvArrow
  attr_writer :lit

  def color; SS2AdvColor.new(@lit ? 200 : 0); end
end

# The icon a battle tile draws over its silhouette, cut from a strip at frame height y.
class SS2AdvIcon
  attr_reader :src_rect

  def initialize(y); @src_rect = SS2AdvRect.new(y); end
end

# A lair's map scene: its tiles by coordinates, the four route arrows, the adventure the corner counters show, the free
# view's cursor, and the game's paints of the crossroads line, the key legends and the cursor's panel; legend replaces
# the viewing legend's rows.
class AdventureMapScene
  attr_reader :ui_sprites, :map_sprites
  attr_accessor :adventure, :raid_battles, :player_tile, :on_route, :legend

  def initialize(tiles, player, raids, dark)
    @map_sprites = {}
    tiles.each { |t| @map_sprites["tile_#{t.coords[0]}_#{t.coords[1]}"] = t }
    @player_tile = player
    @raid_battles = raids
    @dark = dark
    @ui_sprites = {}
    4.times { |i| @ui_sprites["route_arrow_#{i}"] = SS2AdvArrow.new }
    @adventure = SS2AdvAdventure.new(:Basic, 3, 3, 0, 1, SS2AdvNamed.new("Cueva Brasa"))
  end

  def pbUpdateHearts(value = nil); @adventure.hearts = value if value; end
  def pbMapIntro(_show_title = true); :intro; end
  def title_card!; @ui_sprites["title"] = Object.new; end
  def pbUpdateKeys(value = nil); @adventure.keys += value if value; end
  def pbUpdateFloor; @ui_sprites["floor"] = SS2AdvText.new("B#{@adventure.floor}F") if @adventure.floor; end
  def pbTileExists?(x, y); !@map_sprites["tile_#{x}_#{y}"].nil?; end

  # The game's test: a tile the cursor reacts to, which the darkness hides unless it is a battle.
  def pbCursorReact?
    return false unless @cursor_tile.cursor_react?
    return true if @cursor_tile.isTile?(:Battle)
    !@dark.include?(@cursor_tile.coords)
  end

  def pbUpdate(_moving = false); end
  def light(dir); 4.times { |i| @ui_sprites["route_arrow_#{i}"].lit = (i == dir) }; end

  def pbUpdateRouteArrows(dir, _dirs)
    light(dir)
    pbDrawImagePositions(nil, [["Graphics/Pictures/Adventure/selection", 0, 310]])
    pbDrawTextPositions(nil, [["Choose your path!", 256, 324]])
    pbUpdateControls(:selecting)
  end

  def pbUpdateControls(mode)
    rows = case mode
           when :viewing
             @legend || [["[USE]", 4, 8], ["[BACK]", 4, 28], ["Toggle Pokemon", 82, 8], ["Return", 82, 28]]
           when :teleporting then [["[USE] Select Tile", 4, 8]]
           when :moving then [["ACTION: Fast Travel", 4, 362]]
           else [["ARROWS: Select", 4, 362], ["USE: Confirm", 256, 362]]
           end
    pbDrawTextPositions(nil, rows)
    :controls_drawn
  end

  def pbSelectRoute(dir, dirs)
    pbUpdateRouteArrows(dir, dirs)
    @on_route.call if @on_route
    dir
  end

  # The cursor's panel: the coordinates always; the tile's name and description where the cursor reacts to it.
  def pbUpdateCursor(_snap = false)
    t = @cursor_tile
    react = pbCursorReact?
    drawTextEx(nil, 18, 318, 476, 2, t.description) if react && t.description
    rows = [["#{t.coords[0]}, #{t.coords[1]}", 504, 8]]
    rows.push([t.tile.name, 504, 40]) if react
    pbDrawTextPositions(nil, rows)
  end

  def point_at(t)
    @cursor_tile = t
    pbUpdateCursor
  end
end

# The profile, loaded once over the stand-ins as the loader does (the hooks bind once per "Class#method").
eval(Harness.source(File.join(Harness::ROOT, "games/soulstones2/raid_adventure.rb")), TOPLEVEL_BINDING,
     File.join(Harness::ROOT, "games/soulstones2/raid_adventure.rb"))

class Ss2RaidAdventureGdTest < PokeAccessTest
  I18N = PokeAccess::I18n
  ADV = PokeAccess::SS2Adventure
  MALE = "\xE2\x99\x82"
  FEMALE = "\xE2\x99\x80"
  # The type strips' frames the map cuts a battle's icon from, as GameData::Type lists them.
  TYPE_ICONS = [["TypeFIRE", 0], ["TypeWATER", 1], ["TypeGRASS", 7], ["TypeICE", 8]]

  test "a party box says the name and sign, its share of hit points, that it holds an item and its training" do
    mon = SS2AdvMon.new("Charmander", 0, :hp => 30, :totalhp => 39, :item => "Baya Zidra", :ev => { :ATTACK => 252 })
    said = with_main_stats { in_menu { select_by_key(AdventurePartyDatabox.new(mon, :style => :Basic)) } }
    line = ["Charmander #{MALE}", I18N.t(:bt_hp_pct, :n => 76), I18N.t(:ss2_adv_holds),
            I18N.t(:ss2_adv_training, :s => "Ataque")].join(", ")
    assert_equal [[line, true]], said, "said as the arrow lands on it, interrupting"
  end

  test "a box selected again while it is selected says nothing" do
    in_menu do
      box = AdventurePartyDatabox.new(SS2AdvMon.new("Pichu", 1))
      select_by_key(box)
      assert_equal [], select_by_key(box)
    end
  end

  test "a fainted member is said fainted, with neither hit points nor status" do
    mon = SS2AdvMon.new("Pichu", 1, :hp => 0, :status => :POISON)
    said = in_menu { select_by_key(AdventurePartyDatabox.new(mon)) }
    assert_equal [["Pichu #{FEMALE}, #{I18N.t(:pk_fainted)}", true]], said
  end

  test "a member's status follows its hit points" do
    said = in_menu { select_by_key(AdventurePartyDatabox.new(SS2AdvMon.new("Pichu", 1, :status => :POISON))) }
    assert_equal [["Pichu #{FEMALE}, #{I18N.t(:bt_hp_pct, :n => 100)}, StatusPOISON", true]], said
  end

  test "a party box adds the icons its lair shows: the Z-crystal, the Gigantamax factor or the Tera type" do
    { :Basic => [I18N.t(:ss2_adv_holds)],
      :Ultra => [I18N.t(:dbk_item, :i => "Electrostal Z")],
      :Max => [I18N.t(:ss2_adv_holds), I18N.t(:ss2_adv_gmax)],
      :Tera => [I18N.t(:ss2_adv_holds), I18N.t(:ss2_adv_tera, :t => "TypeWATER")] }.each do |style, icons|
      mon = SS2AdvMon.new("Pikachu", 1, :item => "Electrostal Z")
      said = in_menu { select_by_key(AdventurePartyDatabox.new(mon, :style => style)) }
      line = (["Pikachu #{FEMALE}", I18N.t(:bt_hp_pct, :n => 100)] + icons).join(", ")
      assert_equal [[line, true]], said, "a #{style} lair"
    end
  end

  test "in a Dynamax lair a Pokemon without the Gigantamax factor shows no mark" do
    mon = SS2AdvMon.new("Pikachu", 1, :gmax => false)
    said = in_menu { select_by_key(AdventurePartyDatabox.new(mon, :style => :Max)) }
    assert_equal [["Pikachu #{FEMALE}, #{I18N.t(:bt_hp_pct, :n => 100)}", true]], said
  end

  test "what a box cannot read of its Pokemon is left out, and it is not taken for fainted" do
    { "whether it holds an item" => [:hasItem?, :Basic], "the Z-crystal it holds" => [:item, :Ultra],
      "its Gigantamax factor" => [:gmax_factor?, :Max], "whether it fainted" => [:fainted?, :Basic],
      "its efforts" => [:ev, :Basic] }.each do |what, (field, style)|
      kind = Class.new(SS2AdvMon) { define_method(field) { raise IOError, "unreadable" } }
      mon = kind.new("Pikachu", 1, :item => (field == :hasItem? || field == :item ? "Electrostal Z" : nil))
      said = with_main_stats { in_menu { select_by_key(AdventurePartyDatabox.new(mon, :style => style)) } }
      assert_equal [["Pikachu #{FEMALE}, #{I18N.t(:bt_hp_pct, :n => 100)}", true]], said, what
    end
  end

  test "a rental of two types says both" do
    mon = SS2AdvMon.new("Charizard", 0, :types => [:FIRE, :FLYING], :ability => nil, :moves => [])
    said = in_menu { select_by_key(AdventureRentalDatabox.new(mon)) }
    assert_equal [["Charizard #{MALE}, #{I18N.t(:mv_type, :t => "TypeFIRE/TypeFLYING")}", true]], said
  end

  test "a rental whose Pokemon shows no types, ability or moves says its name alone" do
    mon = SS2AdvMon.new("Ditto", 2, :types => [], :ability => nil, :moves => [])
    said = in_menu { select_by_key(AdventureRentalDatabox.new(mon)) }
    assert_equal [["Ditto", true]], said
  end

  test "the training icon names the first stat with effort when it is at the raid's limit, else says balanced" do
    { { :ATTACK => 252 } => [I18N.t(:ss2_adv_training, :s => "Ataque")],
      { :HP => 252, :SPEED => 40 } => [I18N.t(:ss2_adv_training, :s => "PS")],
      { :HP => 40, :SPEED => 252 } => [I18N.t(:ss2_adv_training_balanced)],
      { :HP => 40, :SPEED => 40 } => [I18N.t(:ss2_adv_training_balanced)],
      {} => [] }.each do |ev, training|
      assert_equal [(["Ditto"] + training).join(", ")], rental_lines(ev, 252), "efforts #{ev.inspect}"
    end
  end

  test "with no raid effort limit, any training is balanced" do
    assert_equal ["Ditto, #{I18N.t(:ss2_adv_training_balanced)}"], rental_lines({ :ATTACK => 252 }, nil)
  end

  test "an engine without the main stats to walk shows no training icon" do
    mon = SS2AdvMon.new("Ditto", 2, :types => [], :ability => nil, :moves => [], :ev => { :ATTACK => 252 })
    said = in_menu { select_by_key(AdventureRentalDatabox.new(mon)) }
    assert_equal [["Ditto", true]], said
  end

  test "a captured Pokemon says its name, its sign when it has one, and the shiny mark" do
    { SS2AdvMon.new("Eevee", 2, :shiny => true) => "Eevee, #{I18N.t(:pk_shiny)}",
      SS2AdvMon.new("Eevee", 0) => "Eevee #{MALE}" }.each do |mon, line|
      assert_equal [[line, true]], in_menu { select_by_key(AdventureRewardbox.new(mon)) }, line
    end
  end

  test "an item square says the item and the count it paints, or the item alone when it paints none" do
    { 3 => "Pocion, x3", 0 => "Pocion" }.each do |qty, line|
      said = in_menu { select_by_key(AdventureItembox.new(SS2AdvItem.new("Pocion"), :qty => qty)) }
      assert_equal [[line, true]], said, "a count of #{qty}"
    end
  end

  test "a machine's square says the move it teaches beside its name" do
    said = in_menu { select_by_key(AdventureItembox.new(SS2AdvItem.new("MT24", :THUNDERBOLT), :qty => 1)) }
    assert_equal [["MT24 MoveTHUNDERBOLT, x1", true]], said
  end

  test "a page turned under the selected square reads its new item, though the squares after it are refilled too" do
    in_menu do
      squares = [AdventureItembox.new(SS2AdvItem.new("Pocion"), :qty => 3),
                 AdventureItembox.new(SS2AdvItem.new("Eter"))]
      select_by_key(squares[0])
      said = turn_page(squares, [[SS2AdvItem.new("Elixir"), 2], [SS2AdvItem.new("Antidoto"), 1]], 0)
      assert_equal [["Elixir, x2", true]], said
    end
  end

  test "a square refilled while selected is read again once, however often it is selected again" do
    in_menu do
      square = AdventureItembox.new(SS2AdvItem.new("Pocion"), :qty => 3)
      select_by_key(square)
      square.setItemValues(SS2AdvItem.new("Eter"), 2)
      assert_equal [[["Eter, x2", true]], []], [select_by_key(square), select_by_key(square)]
    end
  end

  test "a stat or Tera type box says its painted word" do
    said = in_menu { select_by_key(AdventureAttributebox.new(nil, :rows => ["Tera Fire"])) }
    assert_equal [["Tera Fire", true]], said
  end

  test "a Dynamax box is queued, its sign beside the name and its arrow said as a change" do
    in_menu do
      AdventureDynamaxbox.new(nil, :rows => ["Pikachu", "Dynamax HP", "+3", "120 -> 135", MALE]).selected = true
      line = ["Pikachu", MALE, "Dynamax HP", "+3", I18N.t(:ss2_adv_change, :from => "120", :to => "135")].join(", ")
      assert_equal [[line, false]], SpeakCapture.log, "the menu walks these boxes by itself"
    end
  end

  test "a painted box selected again while it is selected says nothing" do
    in_menu do
      box = AdventureAttributebox.new(nil, :rows => ["Tera Fire"])
      select_by_key(box)
      assert_equal [], select_by_key(box)
    end
  end

  test "a box with nothing in it says nothing" do
    in_menu do
      [AdventurePartyDatabox, AdventureRentalDatabox, AdventureRewardbox, AdventureItembox, AdventureMovebox,
       AdventureAttributebox].each { |kind| assert_equal [], select_by_key(kind.new(nil)), kind.name }
    end
  end

  test "a box selected while the keys cannot be read is said at once, interrupting" do
    in_menu do
      box = AdventureRewardbox.new(SS2AdvMon.new("Ralts", 1))
      with_repeat(lambda { |_k| raise IOError, "no input" }) { box.selected = true }
      assert_equal [["Ralts #{FEMALE}", true]], SpeakCapture.log
    end
  end

  test "a box selected with an arrow or page key held is said at once, interrupting, but not with the use key held" do
    ralts = [["Ralts #{FEMALE}", true]]
    with_game_keys do
      { :UP => ralts, :DOWN => ralts, :LEFT => ralts, :RIGHT => ralts, :JUMPUP => ralts, :JUMPDOWN => ralts,
        :USE => [] }.each do |key, said|
        heard = in_menu { select_by_key(AdventureRewardbox.new(SS2AdvMon.new("Ralts", 1)), Input.const_get(key)) }
        assert_equal said, heard, "with #{key} held"
      end
    end
  end

  test "a menu opens with its heading and instruction, then the box the game selected before painting them, queued" do
    in_menu(:step => false) do |scene|
      AdventureRewardbox.new(SS2AdvMon.new("Ralts", 1)).selected = true
      scene.paint(["CAPTURED POKEMON", "Select a Pokemon to keep."])
      assert_equal [["CAPTURED POKEMON, Select a Pokemon to keep.", false], ["Ralts #{FEMALE}", false]],
                   SpeakCapture.log
    end
  end

  test "a box selected as a menu opens waits for its instruction even with a key down" do
    in_menu(:step => false) do |scene|
      with_key_down { AdventureRewardbox.new(SS2AdvMon.new("Ralts", 1)).selected = true }
      held = SpeakCapture.lines.dup
      scene.paint(["CAPTURED POKEMON", "Select a Pokemon to keep."])
      assert_equal [[], ["CAPTURED POKEMON, Select a Pokemon to keep.", "Ralts #{FEMALE}"]], [held, SpeakCapture.lines]
    end
  end

  test "the same words painted again say nothing" do
    in_menu do |scene|
      scene.paint(["CAPTURED POKEMON", "Select a Pokemon to keep."])
      scene.pbUpdate
      SpeakCapture.clear
      scene.paint(["CAPTURED POKEMON", "Select a Pokemon to keep."])
      assert_equal [], SpeakCapture.log
    end
  end

  test "an instruction changed in a step is said alone, and a box the game selects after it queues behind it" do
    in_menu do |scene|
      scene.paint(["CAPTURED POKEMON", "Select a Pokemon to keep."])
      scene.pbUpdate
      SpeakCapture.clear
      scene.paint(["CAPTURED POKEMON", "Select another."])
      AdventureRewardbox.new(SS2AdvMon.new("Ralts", 1)).selected = true
      assert_equal [["Select another.", false], ["Ralts #{FEMALE}", false]], SpeakCapture.log
    end
  end

  test "a repaint that only drops words says nothing, and a box the game selects after it still waits for the step" do
    in_menu do |scene|
      scene.paint(["SPOILS", "Choose an item."])
      scene.pbUpdate
      SpeakCapture.clear
      scene.paint(["SPOILS"])
      AdventureItembox.new(SS2AdvItem.new("Pocion"), :qty => 3).selected = true
      held = SpeakCapture.log.dup
      scene.pbUpdate
      assert_equal [[], [["Pocion, x3", false]]], [held, SpeakCapture.log], "before the step, then on it"
    end
  end

  test "a blank row painted among the words is left out" do
    in_menu do |scene|
      scene.paint(["SPOILS", "", "Choose an item."])
      assert_equal [["SPOILS, Choose an item.", false]], SpeakCapture.log
    end
  end

  test "a paint onto another bitmap says nothing" do
    in_menu do
      pbDrawTextPositions(Object.new, [["Elsewhere", 0, 0]])
      assert_equal [], SpeakCapture.log
    end
  end

  test "once a menu closes, its overlay's words are no longer read" do
    scene = AdventureMenuScene.new
    scene.pbStartScene
    scene.pbUpdate
    scene.pbEndScene
    SpeakCapture.clear
    scene.paint(["SPOILS"])
    assert_equal [], SpeakCapture.log
  end

  test "after a menu closes, even in its opening, a box selected is said at once, interrupting" do
    scene = AdventureMenuScene.new
    scene.pbStartScene
    scene.paint(["CAPTURED POKEMON", "Select a Pokemon to keep."])
    scene.pbEndScene
    SpeakCapture.clear
    AdventureRewardbox.new(SS2AdvMon.new("Ralts", 1)).selected = true
    assert_equal [["Ralts #{FEMALE}", true]], SpeakCapture.log
  end

  test "a text line the info key kept while a menu was open is dropped as it closes" do
    scene = AdventureMenuScene.new
    scene.pbStartScene
    PokeAccess::Info.set_info(:text, "Elige a quién cambiar.")
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "a box the game selects as its menu closes is said during the fade-out, queued" do
    scene = AdventureMenuScene.new
    scene.pbStartScene
    scene.pbUpdate
    SpeakCapture.clear
    AdventureRewardbox.new(SS2AdvMon.new("Ralts", 1)).selected = true
    scene.pbEndScene
    assert_equal [["Ralts #{FEMALE}", false]], SpeakCapture.log
  end

  test "a new menu forgets the key buttons the last one drew" do
    PokeAccess::Config.verbosity = :brief
    button = ["Graphics/Pictures/Adventure/buttons", 178, 244, 0, 0, 32, 32]
    in_menu { |scene| pbDrawImagePositions(scene.overlay, [button]) }
    in_menu do |scene|
      pbDrawTextPositions(scene.overlay, [["Label", 218, 254]])
      assert_equal [["Label", false]], SpeakCapture.log
    end
  end

  test "an exchange is read whole, though the menu said some of its words before" do
    in_menu do |scene|
      scene.paint(["RENTAL PARTY", "Select a rental Pokemon."])
      scene.pbUpdate
      SpeakCapture.clear
      scene.pbExchangeMenu(SS2AdvMon.new("Vulpix", 1))
      line = ["RENTAL PARTY", "Add it?", "New Pokemon!", vulpix, "View Summary", "Keep Party"].join(", ")
      assert_equal [[line, false], [first_member, false]], SpeakCapture.log
    end
  end

  test "a rental list the game refills says its new instruction, then the box it selected before painting it, queued" do
    in_menu do |scene|
      rental = AdventureRentalDatabox.new(SS2AdvMon.new("Vulpix", 1))
      select_by_key(rental)
      scene.pbUpdate
      SpeakCapture.clear
      rental.selected = false
      rental.pokemon = SS2AdvMon.new("Growlithe", 0)
      rental.selected = true
      scene.paint(["RENTAL PARTY", "Select 1 more rental Pokemon.", "Summary"])
      growlithe = ["Growlithe #{MALE}", I18N.t(:mv_type, :t => "TypeFIRE"), I18N.t(:dbk_ability, :a => "Mar Llamas"),
                   I18N.t(:sm_moves, :list => "Ascuas, Gruñido")].join(", ")
      assert_equal [["RENTAL PARTY, Select 1 more rental Pokemon., Summary", false], [growlithe, false]],
                   SpeakCapture.log
    end
  end

  test "a box the game selects with no key down waits for the step, which says it once, queued" do
    in_menu do |scene|
      AdventurePartyDatabox.new(SS2AdvMon.new("Pichu", 1)).selected = true
      held = SpeakCapture.log.dup
      2.times { scene.pbUpdate }
      assert_equal [], held, "before the step"
      assert_equal [["Pichu #{FEMALE}, #{I18N.t(:bt_hp_pct, :n => 100)}", false]], SpeakCapture.log, "after two steps"
    end
  end

  test "an empty box the game selects, or a painted one that paints nothing, keeps the box already held for the step" do
    [AdventurePartyDatabox.new(nil), AdventureAttributebox.new(nil, :rows => [])].each do |empty|
      in_menu do |scene|
        AdventurePartyDatabox.new(SS2AdvMon.new("Pichu", 1)).selected = true
        empty.selected = true
        scene.pbUpdate
        assert_equal [["Pichu #{FEMALE}, #{I18N.t(:bt_hp_pct, :n => 100)}", false]], SpeakCapture.log, empty.class.name
      end
    end
  end

  test "an exchange reads heading, question, the offer's label, the offer and button hints, then its first member" do
    in_menu(:step => false) do |scene|
      scene.pbExchangeMenu(SS2AdvMon.new("Vulpix", 1))
      line = ["RENTAL PARTY", "Add it?", "New Pokemon!", vulpix, "View Summary", "Keep Party"].join(", ")
      assert_equal [[line, false], [first_member, false]], SpeakCapture.log, "the member it selected first, queued"
    end
  end

  test "the record reads its left panel, then the members it recorded under their heading, then the hint" do
    { 3 => nil, 2 => [SS2AdvMon.new("Mon0", 2), SS2AdvMon.new("Mon1", 2)] }.each do |members, party|
      in_menu do |scene|
        scene.party = party
        scene.pbRecordMenu
        assert_equal [[record_line(members, ["Summary"]), false]], SpeakCapture.log, "a party of #{members}"
      end
    end
  end

  test "the record reads its party without the training icon its boxes do not show" do
    trained = (0..2).map { |i| SS2AdvMon.new("Mon#{i}", 2, :ev => { :ATTACK => 252 }) }
    with_main_stats do
      in_menu do |scene|
        scene.party = trained
        scene.pbRecordMenu
        assert_equal [[record_line(3, ["Summary"]), false]], SpeakCapture.log
      end
    end
  end

  test "an exchange reads its offer with the training icon its box shows" do
    mon = SS2AdvMon.new("Vulpix", 1, :ev => { :SPEED => 252 })
    with_main_stats do
      in_menu do |scene|
        scene.pbExchangeMenu(mon)
        offer = [vulpix, I18N.t(:ss2_adv_training, :s => "Velocidad")].join(", ")
        line = ["RENTAL PARTY", "Add it?", "New Pokemon!", offer, "View Summary", "Keep Party"].join(", ")
        assert_equal [[line, false], [first_member, false]], SpeakCapture.log
      end
    end
  end

  test "a pick in the exchange, which repaints its heading before trading the boxes, says nothing more" do
    in_menu do |scene|
      scene.picking = true
      scene.pbExchangeMenu(SS2AdvMon.new("Vulpix", 1))
      line = ["RENTAL PARTY", "Add it?", "New Pokemon!", vulpix, "View Summary", "Keep Party"].join(", ")
      assert_equal [[line, false], [first_member, false]], SpeakCapture.log
    end
  end

  test "an exchange whose offer holds no Pokemon reads its words without it" do
    in_menu do |scene|
      scene.pbExchangeMenu(nil)
      line = ["RENTAL PARTY", "Add it?", "New Pokemon!", "View Summary", "Keep Party"].join(", ")
      assert_equal [[line, false], [first_member, false]], SpeakCapture.log
    end
  end

  test "the bottom bar's hints, from its top edge down, are said last and left to right, whatever their paint order" do
    in_menu do |scene|
      scene.bar = [["Accept", 300, 352], ["Summary", 56, 364]]
      scene.pbRecordMenu
      assert_equal [[record_line(3, ["Summary", "Accept"]), false]], SpeakCapture.log
    end
  end

  test "with key hints left out, a menu says its heading and instruction without the bottom bar's keys" do
    PokeAccess::Config.verbosity = :brief
    in_menu do |scene|
      pbDrawTextPositions(scene.overlay, [["SPOILS", 0, 0], ["Choose an item.", 0, 20], ["USE: Take", 0, 360]])
      assert_equal [["SPOILS, Choose an item.", false]], SpeakCapture.log
    end
  end

  test "the bottom bar of key hints starts 32 pixels above the screen's bottom edge" do
    PokeAccess::Config.verbosity = :brief
    { 351 => [["Choose an item.", false]], 352 => [] }.each do |y, said|
      in_menu do |scene|
        pbDrawTextPositions(scene.overlay, [["Choose an item.", 0, y]])
        assert_equal said, SpeakCapture.log, "a row at y #{y}"
      end
    end
  end

  test "with key hints left out, an exchange drops the labels painted beside its key buttons" do
    PokeAccess::Config.verbosity = :brief
    in_menu do |scene|
      scene.pbExchangeMenu(SS2AdvMon.new("Vulpix", 1))
      line = ["RENTAL PARTY", "Add it?", "New Pokemon!", vulpix].join(", ")
      assert_equal [[line, false], [first_member, false]], SpeakCapture.log
    end
  end

  test "with key hints left out, only a label level with a key button and within 16 pixels right of it is dropped" do
    PokeAccess::Config.verbosity = :brief
    { [209, 254] => true, [210, 254] => false, [226, 254] => false, [227, 254] => true,
      [218, 243] => true, [218, 244] => false, [218, 276] => false, [218, 277] => true }.each do |(x, y), said|
      assert_equal said, label_said?("Graphics/Pictures/Adventure/buttons", :overlay, x, y), "a label at (#{x}, #{y})"
    end
  end

  test "with key hints left out, an icon that is no key button, or a button drawn elsewhere, hides no label" do
    PokeAccess::Config.verbosity = :brief
    assert_equal true, label_said?("Graphics/Pictures/Adventure/selection", :overlay, 218, 254), "another icon"
    assert_equal true, label_said?("Graphics/Pictures/Adventure/buttons", :elsewhere, 218, 254), "another bitmap"
  end

  test "with descriptions left out, the menu's description window is not said, and Ctrl+T says it after the square" do
    PokeAccess::Config.verbosity = :brief
    in_menu(:window => SS2AdvWindow.new("Restores 20 HP.", true)) do
      select_by_key(AdventureItembox.new(SS2AdvItem.new("Pocion"), :qty => 3))
      SpeakCapture.clear
      PokeAccess::InfoWindow.tick
      assert_equal [], SpeakCapture.log, "the window"
      assert_equal "Pocion, x3. Restores 20 HP.", PokeAccess::Info.row_text, "Ctrl+T"
    end
  end

  test "in full the menu's description window is said once, queued, frame after frame, and Ctrl+T keeps it once" do
    in_menu(:window => SS2AdvWindow.new("Restores 20 HP.", true)) do
      select_by_key(AdventureItembox.new(SS2AdvItem.new("Pocion"), :qty => 3))
      SpeakCapture.clear
      2.times { PokeAccess::InfoWindow.tick }
      assert_equal [["Restores 20 HP.", false]], SpeakCapture.log, "the window"
      assert_equal "Pocion, x3. Restores 20 HP.", PokeAccess::Info.row_text, "Ctrl+T"
    end
  end

  test "a menu with no description window is not filed as one whose window never showed" do
    in_menu { PokeAccess::InfoWindow.tick }
    refute_includes PokeAccess::InfoWindow.silent, "AdventureMenuScene.window"
  end

  test "a party box in brief and medium says the name and hit points, and in full its sign, item and icons" do
    mon = SS2AdvMon.new("Charmander", 0, :hp => 30, :totalhp => 39, :item => "Baya Zidra", :ev => { :ATTACK => 252 })
    said = with_main_stats { in_menu { vb_levels { select_by_key(AdventurePartyDatabox.new(mon, :style => :Tera)) } } }
    short = "Charmander, #{I18N.t(:bt_hp_pct, :n => 76)}"
    full = ["Charmander #{MALE}", I18N.t(:bt_hp_pct, :n => 76), I18N.t(:ss2_adv_holds),
            I18N.t(:ss2_adv_tera, :t => "TypeWATER"), I18N.t(:ss2_adv_training, :s => "Ataque")].join(", ")
    assert_equal [[[short, true]], [[short, true]], [[full, true]]], said
  end

  test "the info key says a party box's Pokemon, and Ctrl+T the box whole, whatever the level" do
    mon = SS2AdvMon.new("Charmander", 0, :hp => 30, :totalhp => 39, :item => "Baya Zidra")
    PokeAccess::Config.verbosity = :brief
    in_menu do
      select_by_key(AdventurePartyDatabox.new(mon, :style => :Tera))
      full = ["Charmander #{MALE}", I18N.t(:bt_hp_pct, :n => 76), I18N.t(:ss2_adv_holds),
              I18N.t(:ss2_adv_tera, :t => "TypeWATER")].join(", ")
      assert_equal PokeAccess::Info.pokemon_info(mon), PokeAccess::Info.info_text, "the info key"
      assert_equal full, PokeAccess::Info.row_text, "Ctrl+T"
    end
  end

  test "the info key says the Pokemon, item or move of the box last selected, each replacing the one before" do
    rental = SS2AdvMon.new("Eevee", 0)
    reward = SS2AdvMon.new("Vulpix", 1)
    move = SS2AdvMove.new("Ascuas", :FIRE, 25, 40, 100, 1)
    boxes = [AdventureRentalDatabox.new(rental), AdventureRewardbox.new(reward),
             AdventureItembox.new(SS2AdvItem.new("Pocion"), :qty => 3), AdventureMovebox.new(move)]
    kept = in_menu do
      boxes.map do |box|
        select_by_key(box)
        PokeAccess::Info.info_text
      end
    end
    assert_equal [PokeAccess::Info.pokemon_info(rental), PokeAccess::Info.pokemon_info(reward),
                  PokeAccess::Info.item_info(:POTION), PokeAccess::Info.move_info(move)], kept
  end

  test "a rental in brief says its name, in medium its types too, and Ctrl+T says it whole" do
    mon = SS2AdvMon.new("Charmander", 0, :item => "Baya Zidra", :ev => { :HP => 40 })
    with_main_stats do
      in_menu do
        said = vb_levels { select_by_key(AdventureRentalDatabox.new(mon, :style => :Tera)) }
        full = ["Charmander #{MALE}", I18N.t(:mv_type, :t => "TypeFIRE"), I18N.t(:dbk_ability, :a => "Mar Llamas"),
                I18N.t(:sm_moves, :list => "Ascuas, Gruñido"), I18N.t(:ss2_adv_holds),
                I18N.t(:ss2_adv_tera, :t => "TypeWATER"), I18N.t(:ss2_adv_training_balanced)].join(", ")
        PokeAccess::Config.verbosity = :brief
        select_by_key(AdventureRentalDatabox.new(mon, :style => :Tera))
        typed = "Charmander, #{I18N.t(:mv_type, :t => "TypeFIRE")}"
        assert_equal [[["Charmander", true]], [[typed, true]], [[full, true]]], said, "brief, medium and full"
        assert_equal full, PokeAccess::Info.row_text, "Ctrl+T in brief"
      end
    end
  end

  test "a captured Pokemon in brief and medium says its name, and in full its sign and shiny mark" do
    mon = SS2AdvMon.new("Eevee", 0, :shiny => true)
    said = in_menu { vb_levels { select_by_key(AdventureRewardbox.new(mon)) } }
    assert_equal [[["Eevee", true]], [["Eevee", true]], [["Eevee #{MALE}, #{I18N.t(:pk_shiny)}", true]]], said
  end

  test "Ctrl+T says an item square whatever the level" do
    PokeAccess::Config.verbosity = :brief
    in_menu do
      select_by_key(AdventureItembox.new(SS2AdvItem.new("Pocion"), :qty => 3))
      assert_equal "Pocion, x3", PokeAccess::Info.row_text
    end
  end

  test "a move to teach in brief says its name, in medium its type, in full the whole line, which Ctrl+T says" do
    move = SS2AdvMove.new("Ascuas", :FIRE, 25, 40, 100, 1)
    in_menu do
      said = vb_levels { select_by_key(AdventureMovebox.new(move)) }
      full = ["Ascuas", I18N.t(:mv_type, :t => "TypeFIRE"), I18N.t(:cat_special), I18N.t(:mv_power, :p => 40),
              I18N.t(:mv_acc, :a => 100), I18N.t(:mv_pp, :pp => 25, :tot => 25)].join(". ")
      PokeAccess::Config.verbosity = :brief
      select_by_key(AdventureMovebox.new(move))
      typed = "Ascuas. #{I18N.t(:mv_type, :t => "TypeFIRE")}"
      assert_equal [[["Ascuas", true]], [[typed, true]], [[full, true]]], said, "brief, medium and full"
      assert_equal full, PokeAccess::Info.row_text, "Ctrl+T in brief"
    end
  end

  test "a crossroads says the game's words, each path and where it leads, the lit arrow, then the key legend, queued" do
    map = lair([SS2AdvTile.new(:Chest, 2, 1), SS2AdvTile.new(:Pathway, 2, 3)])
    map.pbUpdateRouteArrows(0, [0, 1])
    line = ["Choose your path!", way(:dir_up, "Chest"), way(:dir_down), I18N.t(:ss2_adv_lit, :dir => I18N.t(:dir_up)),
            "ARROWS: Select, USE: Confirm"].join(". ")
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "with key hints left out, a crossroads says its paths without its key legend" do
    PokeAccess::Config.verbosity = :brief
    map = lair([SS2AdvTile.new(:Chest, 2, 1)])
    map.pbSelectRoute(0, [0])
    line = ["Choose your path!", way(:dir_up, "Chest"), I18N.t(:ss2_adv_lit, :dir => I18N.t(:dir_up))].join(". ")
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "the route choice still answers the direction the game's loop chose" do
    assert_equal 2, lair([SS2AdvTile.new(:Chest, 1, 2)]).pbSelectRoute(2, [2])
  end

  test "the arrow lit as a crossroads is drawn is not said again, though the last choice ended on another" do
    map = lair([SS2AdvTile.new(:Chest, 2, 1), SS2AdvTile.new(:Chest, 1, 2)])
    map.on_route = lambda do
      map.light(2)
      ADV.poll_route
    end
    map.pbSelectRoute(0, [0, 2])
    heard = nil
    map.on_route = lambda do
      SpeakCapture.clear
      ADV.poll_route
      heard = SpeakCapture.log.dup
    end
    map.pbSelectRoute(0, [0, 2])
    assert_equal [], heard
  end

  test "turning the arrow during the choice says the path it points down once, interrupting" do
    map = lair([SS2AdvTile.new(:Chest, 2, 1), SS2AdvTile.new(:Battle, 1, 2, :battle => 0)], [{ :rank => 2 }])
    { [0, 2] => way(:dir_left, "Battle, #{I18N.t(:ss2_raid_rank, :n => 2)}"),
      [2, 0] => way(:dir_up, "Chest") }.each do |(from, to), said|
      heard = nil
      map.on_route = lambda do
        SpeakCapture.clear
        map.light(to)
        2.times { ADV.poll_route }
        heard = SpeakCapture.log.dup
      end
      map.pbSelectRoute(from, [0, 2])
      assert_equal [[said, true]], heard, "from #{from} to #{to}, polled two frames"
    end
  end

  test "a turn polled while the map's arrows cannot be read says nothing" do
    map = lair([SS2AdvTile.new(:Chest, 2, 1), SS2AdvTile.new(:Chest, 1, 2)])
    heard = nil
    map.on_route = lambda do
      SpeakCapture.clear
      map.light(2)
      with_singleton(map, :ui_sprites, lambda { raise IOError, "disposed" }) { ADV.poll_route }
      heard = SpeakCapture.log.dup
    end
    map.pbSelectRoute(0, [0, 2])
    assert_equal [], heard
  end

  test "a crossroads whose tiles the map cannot tell still says its line, each path by its direction" do
    map = lair([SS2AdvTile.new(:Chest, 2, 1)])
    with_singleton(map, :pbTileExists?, lambda { |_x, _y| raise IOError, "no tiles" }) do
      map.pbUpdateRouteArrows(0, [0, 1])
    end
    line = ["Choose your path!", I18N.t(:dir_up), I18N.t(:dir_down), I18N.t(:ss2_adv_lit, :dir => I18N.t(:dir_up)),
            "ARROWS: Select, USE: Confirm"].join(". ")
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "with the choice over, the arrows are not watched" do
    map = lair([SS2AdvTile.new(:Chest, 2, 1), SS2AdvTile.new(:Chest, 1, 2)])
    map.pbSelectRoute(0, [0, 2])
    SpeakCapture.clear
    map.light(2)
    ADV.poll_route
    assert_equal [], SpeakCapture.log
  end

  test "a battle on a path says its rank, or that it is the boss, and the type its icon shows" do
    battle = [SS2AdvTile.new(:Battle, 2, 1, :battle => 0)]
    rank = I18N.t(:ss2_raid_rank, :n => 3)
    fire = I18N.t(:mv_type, :t => "TypeFIRE")
    water = I18N.t(:mv_type, :t => "TypeWATER")
    { "a ranked battle" => [{ :rank => 3 }, { 0 => 0 }, "Battle, #{rank}, #{fire}"],
      "the boss" => [{ :rank => 6 }, { 0 => 0 }, "Battle, #{I18N.t(:ss2_adv_boss)}, #{fire}"],
      "a battle with no rank" => [{}, { 0 => 0 }, "Battle, #{fire}"],
      "the strip's second frame" => [{ :rank => 3 }, { 0 => 28 }, "Battle, #{rank}, #{water}"],
      "a frame no type is cut from" => [{ :rank => 3 }, { 0 => 56 }, "Battle, #{rank}"],
      "an icon whose frame cannot be read" => [{ :rank => 3 }, { 0 => nil }, "Battle, #{rank}"],
      "no icon over it" => [{ :rank => 3 }, {}, "Battle, #{rank}"],
      "a battle the lair keeps no data for" => [nil, {}, "Battle"] }.each do |what, (raid, icons, said)|
      assert_equal way(:dir_up, said), path_said(0, battle, [raid].compact, :icons => icons), what
    end
  end

  test "a battle whose types the engine cannot list says its rank without a type" do
    map = lair([SS2AdvTile.new(:Battle, 2, 1, :battle => 0)], [{ :rank => 3 }])
    map.map_sprites["pkmntype_0"] = SS2AdvIcon.new(0)
    unlisted = lambda { |&_b| raise IOError, "no type list" }
    said = with_singleton(GameData::Type, :each, unlisted) { ADV.path_text(map, 0) }
    assert_equal way(:dir_up, "Battle, #{I18N.t(:ss2_raid_rank, :n => 3)}"), said
  end

  test "in a Tera lair a battle says the Tera type its icon shows, cut from 32-pixel frames" do
    battle = [SS2AdvTile.new(:Battle, 2, 1, :battle => 0)]
    said = path_said(0, battle, [{ :rank => 3 }], :icons => { 0 => 224 }, :style => :Tera)
    tera = I18N.t(:ss2_adv_tera, :t => "TypeGRASS")
    assert_equal way(:dir_up, "Battle, #{I18N.t(:ss2_raid_rank, :n => 3)}, #{tera}"), said, "the eighth frame, at 224"
  end

  test "in an Ultra lair a battle names the Z-crystal its Pokemon holds" do
    battle = [SS2AdvTile.new(:Battle, 2, 1, :battle => 0)]
    raid = { :rank => 3, :pokemon => SS2AdvRaidMon.new(:ELECTRIUMZ) }
    said = path_said(0, battle, [raid], :icons => { 0 => 0 }, :style => :Ultra)
    assert_equal way(:dir_up, "Battle, #{I18N.t(:ss2_raid_rank, :n => 3)}, ItemELECTRIUMZ"), said
  end

  test "a path names a warp's destination and a switch's position, off when it cannot be read" do
    unreadable = Class.new(SS2AdvTile) { def switch_on?; raise IOError, "no switch"; end }
    [[SS2AdvTile.new(:Warp, 2, 1, :warp => [7, 3]), I18N.t(:ss2_adv_warp, :name => "Warp", :x => 7, :y => 3)],
     [SS2AdvTile.new(:Warp, 2, 1), "Warp"],
     [SS2AdvTile.new(:Switch, 2, 1, :on => true), "Switch, #{I18N.t(:val_on)}"],
     [SS2AdvTile.new(:Switch, 2, 1, :on => false), "Switch, #{I18N.t(:val_off)}"],
     [unreadable.new(:Switch, 2, 1, :on => true), "Switch, #{I18N.t(:val_off)}"]].each do |tile, said|
      assert_equal way(:dir_up, said), path_said(0, [tile]), "#{tile.class.name || 'unreadable'}: #{said}"
    end
  end

  test "a path says the traps drawn on it, then what it leads to past its turns" do
    tiles = [SS2AdvTile.new(:HiddenTrap, 1, 2, :hidden => true), SS2AdvTile.new(:TurnNorth, 0, 2),
             SS2AdvTile.new(:Pathway, 0, 1), SS2AdvTile.new(:Chest, 0, 0)]
    assert_equal way(:dir_left, I18N.t(:ss2_adv_then, :a => "Hidden Trap", :b => "Chest")), path_said(2, tiles)
  end

  test "a path that ends past a lit trap names the trap" do
    tiles = [SS2AdvTile.new(:Pathway, 3, 2), SS2AdvTile.new(:HiddenTrap, 4, 2, :hidden => true)]
    assert_equal way(:dir_right, "Hidden Trap"), path_said(3, tiles)
  end

  test "a path goes over passages, used tiles and fought battles to the first tile that does something" do
    battle = way(:dir_right, "Battle, #{I18N.t(:ss2_raid_rank, :n => 3)}")
    raids = [{ :rank => 2, :battled => true }, { :rank => 3 }]
    { "a pathway" => SS2AdvTile.new(:Pathway, 3, 2), "the start point" => SS2AdvTile.new(:StartPoint, 3, 2),
      "a chest already opened" => SS2AdvTile.new(:Chest, 3, 2, :used => true),
      "a fought battle" => SS2AdvTile.new(:Battle, 3, 2, :battle => 0) }.each do |what, passed|
      assert_equal battle, path_said(3, [passed, SS2AdvTile.new(:Battle, 4, 2, :battle => 1)], raids), what
    end
  end

  test "each turn tile turns the path its own way" do
    turns = { :TurnNorth => [3, [3, 2], [3, 1], :dir_right], :TurnSouth => [3, [3, 2], [3, 3], :dir_right],
              :TurnWest => [0, [2, 1], [1, 1], :dir_up], :TurnEast => [0, [2, 1], [3, 1], :dir_up] }
    turns.each do |turn, (d, at, chest, dir)|
      tiles = [SS2AdvTile.new(turn, *at), SS2AdvTile.new(:Chest, *chest)]
      assert_equal way(dir, "Chest"), path_said(d, tiles), turn.to_s
    end
  end

  test "a turn tile with nothing where it points leaves the path going straight" do
    tiles = [SS2AdvTile.new(:TurnEast, 2, 1), SS2AdvTile.new(:Chest, 2, 0)]
    assert_equal way(:dir_up, "Chest"), path_said(0, tiles)
  end

  test "a path into the dark says only its direction, past a trap or a fought battle" do
    trap = [SS2AdvTile.new(:HiddenTrap, 3, 2, :hidden => true), SS2AdvTile.new(:Chest, 4, 2)]
    fought = [SS2AdvTile.new(:Battle, 3, 2, :battle => 0), SS2AdvTile.new(:Pathway, 4, 2), SS2AdvTile.new(:Chest, 5, 2)]
    { "a trap in the dark" => [trap, [], [[3, 2], [4, 2]]],
      "a fought battle" => [fought, [{ :rank => 2, :battled => true }], [[5, 2]]] }.each do |what, (tiles, raids, dark)|
      assert_equal I18N.t(:dir_right), path_said(3, tiles, raids, :dark => dark), what
    end
  end

  test "a battle in the dark is still named, as the game's cursor names one" do
    tiles = [SS2AdvTile.new(:Pathway, 3, 2), SS2AdvTile.new(:Battle, 4, 2, :battle => 0)]
    said = path_said(3, tiles, [{ :rank => 2 }], :dark => [[3, 2], [4, 2]])
    assert_equal way(:dir_right, "Battle, #{I18N.t(:ss2_raid_rank, :n => 2)}"), said
  end

  test "a path is followed for 64 tiles: what lies past them is not named, though the traps on the way still are" do
    { 64 => I18N.t(:ss2_adv_then, :a => "Hidden Trap", :b => "Chest"), 65 => "Hidden Trap" }.each do |far, what|
      tiles = [SS2AdvTile.new(:HiddenTrap, 3, 2, :hidden => true)] +
              (4...(2 + far)).map { |x| SS2AdvTile.new(:Pathway, x, 2) } + [SS2AdvTile.new(:Chest, 2 + far, 2)]
      assert_equal way(:dir_right, what), path_said(3, tiles), "a chest #{far} tiles away"
    end
  end

  test "a path that ends on nothing, has no tile at all or loops on its turns says only its direction" do
    loop_of_turns = [SS2AdvTile.new(:TurnEast, 2, 1), SS2AdvTile.new(:TurnNorth, 3, 1), SS2AdvTile.new(:TurnWest, 3, 0),
                     SS2AdvTile.new(:TurnSouth, 2, 0)]
    { "a dead end" => [1, [SS2AdvTile.new(:Pathway, 2, 3)], :dir_down],
      "no tile that way" => [3, [], :dir_right],
      "a loop of turns" => [0, loop_of_turns, :dir_up] }.each do |what, (d, tiles, dir)|
      assert_equal I18N.t(dir), path_said(d, tiles), what
    end
  end

  test "the free view says its key legend's two columns paired, then the tile under the cursor, both queued" do
    map = lair([])
    map.pbUpdateControls(:viewing)
    map.point_at(map.player_tile)
    assert_equal [["[USE] Toggle Pokemon, [BACK] Return", false], ["2, 2, Crossroad", false]], SpeakCapture.log
  end

  test "the same tile again says nothing, and a new tile interrupts" do
    chest = SS2AdvTile.new(:Chest, 0, 0)
    map = lair([chest])
    map.pbUpdateControls(:viewing)
    map.point_at(map.player_tile)
    map.pbUpdate(true)
    SpeakCapture.clear
    map.point_at(map.player_tile)
    same = SpeakCapture.log.dup
    map.point_at(chest)
    assert_equal [[], [["0, 0, Chest", true]]], [same, SpeakCapture.log]
  end

  test "opening the view again reads the tile again, though it is the last one heard" do
    map = lair([])
    map.pbUpdateControls(:viewing)
    map.point_at(map.player_tile)
    map.pbUpdate(true)
    SpeakCapture.clear
    map.pbUpdateControls(:viewing)
    map.point_at(map.player_tile)
    assert_equal ["[USE] Toggle Pokemon, [BACK] Return", "2, 2, Crossroad"], SpeakCapture.lines
  end

  test "the legend's paint still answers what the game's own does, in the view and out of it" do
    map = lair([])
    assert_equal [:controls_drawn, :controls_drawn], [map.pbUpdateControls(:viewing), map.pbUpdateControls(:moving)]
  end

  test "the walking legend is not the view's and says nothing" do
    lair([]).pbUpdateControls(:moving)
    assert_equal [], SpeakCapture.log
  end

  test "the teleport legend, and a viewing legend with an odd number of rows, are said as painted" do
    odd = [["[USE]", 4, 8], ["[BACK]", 4, 28], ["Toggle Pokemon", 82, 8]]
    cases = { "picking where to teleport" => [:teleporting, nil, "[USE] Select Tile"],
              "a viewing legend of three rows" => [:viewing, odd, "[USE], [BACK], Toggle Pokemon"] }
    cases.each do |what, (mode, rows, said)|
      map = lair([])
      map.legend = rows
      map.pbUpdateControls(mode)
      assert_equal [[said, false]], SpeakCapture.log, what
    end
  end

  test "a Crossroad the map tints is said not visited" do
    map = lair([])
    far = SS2AdvTile.new(:Crossroad, 6, 6)
    far.tint = 125
    map.point_at(far)
    assert_equal [["6, 6, Crossroad, #{I18N.t(:ss2_adv_unvisited)}", true]], SpeakCapture.log
  end

  test "with key hints left out, the view opens on the tile's name alone, interrupting" do
    PokeAccess::Config.verbosity = :brief
    chest = SS2AdvTile.new(:Chest, 0, 0)
    map = lair([chest])
    map.pbUpdateControls(:viewing)
    map.point_at(chest)
    assert_equal [["Chest", true]], SpeakCapture.log
  end

  test "in brief a tile of the same name elsewhere is said too" do
    PokeAccess::Config.verbosity = :brief
    chest = SS2AdvTile.new(:Chest, 0, 0)
    twin = SS2AdvTile.new(:Chest, 1, 0)
    map = lair([chest, twin])
    map.pbUpdateControls(:viewing)
    map.point_at(chest)
    SpeakCapture.clear
    map.point_at(twin)
    assert_equal [["Chest", true]], SpeakCapture.log
  end

  test "the info key keeps the view's coordinates whatever the level" do
    PokeAccess::Config.verbosity = :brief
    chest = SS2AdvTile.new(:Chest, 0, 0)
    map = lair([chest])
    map.pbUpdateControls(:viewing)
    map.point_at(chest)
    assert_equal "0, 0, Chest", PokeAccess::Info.info_text
  end

  test "in medium the view's tile is said with its coordinates" do
    PokeAccess::Config.verbosity = :medium
    chest = SS2AdvTile.new(:Chest, 0, 0)
    map = lair([chest])
    map.point_at(chest)
    assert_equal [["0, 0, Chest", true]], SpeakCapture.log
  end

  test "a tile the cursor does not react to is said by its coordinates alone, even in brief" do
    PokeAccess::Config.verbosity = :brief
    path = SS2AdvTile.new(:Pathway, 2, 1)
    map = lair([path])
    map.point_at(path)
    assert_equal [["2, 1", true]], SpeakCapture.log
  end

  test "a tile's description follows its name in full only" do
    { :full => "0, 0, Chest, Opens with a key.", :medium => "0, 0, Chest" }.each do |level, said|
      PokeAccess::Config.verbosity = level
      chest = SS2AdvTile.new(:Chest, 0, 0, :desc => "Opens with a key.")
      map = lair([chest])
      map.point_at(chest)
      assert_equal [[said, true]], SpeakCapture.log, level.to_s
    end
  end

  test "leaving the view takes its tile off the info key" do
    map = lair([])
    map.pbUpdateControls(:viewing)
    map.point_at(map.player_tile)
    map.pbUpdateControls(:moving)
    assert_nil PokeAccess::Info.info_text
  end

  test "opening a lair says the hearts and the floor, queued, and no key counter while there is none" do
    map = lair([])
    map.pbUpdateHearts
    map.pbUpdateKeys
    map.pbUpdateFloor
    assert_equal [[I18N.t(:ss2_adv_hearts, :n => 3, :max => 3), false], [I18N.t(:ss2_adv_floor, :f => "B1F"), false]],
                 SpeakCapture.log
  end

  test "a redraw with the same hearts says nothing" do
    map = lair([])
    map.pbUpdateHearts
    SpeakCapture.clear
    map.pbUpdateHearts
    assert_equal [], SpeakCapture.log
  end

  test "a heart lost and a key found are each said, queued" do
    map = lair([])
    map.pbUpdateHearts
    SpeakCapture.clear
    map.pbUpdateHearts(1)
    map.pbUpdateKeys(1)
    assert_equal [[I18N.t(:ss2_adv_hearts, :n => 1, :max => 3), false], [I18N.t(:ss2_adv_keys, :n => 1), false]],
                 SpeakCapture.log
  end

  test "the last key used is said too, as its icon goes" do
    map = lair([])
    map.pbUpdateKeys(1)
    SpeakCapture.clear
    map.pbUpdateKeys(-1)
    assert_equal [[I18N.t(:ss2_adv_keys, :n => 0), false]], SpeakCapture.log
  end

  test "a lair that is not Endless says no floor" do
    map = lair([])
    map.adventure.floor = nil
    map.pbUpdateFloor
    assert_equal [], SpeakCapture.log
  end

  test "a map with no adventure, or one that cannot give them, says neither hearts nor keys" do
    { "no adventure" => nil, "an adventure without them" => Object.new }.each do |what, adventure|
      [:pbUpdateHearts, :pbUpdateKeys].each do |update|
        map = lair([])
        map.adventure = adventure
        map.send(update)
        assert_equal [], SpeakCapture.log, "#{what}: #{update}"
      end
    end
  end

  test "a floor with no title card, as in a playtest, says none" do
    lair([]).pbMapIntro
    assert_equal [], SpeakCapture.log
  end

  test "the title card says the adventure's name then the lair's, queued, and the intro still answers" do
    with_lair_name("Basic Adventure") do
      map = lair([])
      map.title_card!
      assert_equal [:intro, [["Basic Adventure, Cueva Brasa", false]]], [map.pbMapIntro, SpeakCapture.log]
    end
  end

  test "a floor entered without its card says no title" do
    with_lair_name("Basic Adventure") do
      map = lair([])
      map.title_card!
      map.pbMapIntro(false)
      assert_equal [], SpeakCapture.log
    end
  end

  test "a title card says the names it has, and nothing with neither" do
    { "Cueva Brasa" => [["Cueva Brasa", false]], nil => [] }.each do |lair_map, said|
      map = lair([])
      map.adventure.map = lair_map && SS2AdvNamed.new(lair_map)
      map.title_card!
      map.pbMapIntro
      assert_equal said, SpeakCapture.log, "a map named #{lair_map.inspect} and no adventure name"
    end
  end

  private

  # Runs the block in an adventure menu, past its opening step unless :step is false, nothing said yet; the menu is
  # closed after. :window gives the menu its description window.
  def in_menu(opts = {})
    scene = AdventureMenuScene.new
    scene.add("window", opts[:window]) if opts[:window]
    scene.pbStartScene
    scene.pbUpdate unless opts[:step] == false
    SpeakCapture.clear
    yield scene
  ensure
    scene.pbEndScene if scene
  end

  # What selecting a box says with an arrow key, or the given key, held.
  def select_by_key(box, key = Input::RIGHT)
    SpeakCapture.clear
    with_key_down(key) { box.selected = true }
    SpeakCapture.log.dup
  end

  # What turning a page of spoils says, turned as the game turns one with an arrow key held: every square refilled
  # with its [item, count] of items, then each selected or not as it is the one at idx.
  def turn_page(squares, items, idx)
    SpeakCapture.clear
    with_key_down do
      squares.each_with_index { |square, i| square.setItemValues(*items[i]) }
      squares.each_with_index { |square, i| square.selected = (i == idx) }
    end
    SpeakCapture.log.dup
  end

  # Runs the block with a key held, an arrow unless given, as the player moving between boxes; a box selected with
  # none held is one the game selected by itself.
  def with_key_down(key = Input::RIGHT, &blk)
    with_repeat(lambda { |k| k == key }, &blk)
  end

  # Runs the block with the keys Soulstones 2's Input aliases beyond the stub's arrows: USE (C), JUMPUP (X) and
  # JUMPDOWN (Y).
  def with_game_keys(&blk)
    with_const(Input, :USE, Input::C) do
      with_const(Input, :JUMPUP, Input::X) { with_const(Input, :JUMPDOWN, Input::Y, &blk) }
    end
  end

  # Runs the block with Input.repeat? answering as rule does.
  def with_repeat(rule, &blk)
    with_singleton(Input, :repeat?, lambda { |k| rule.call(k) }, &blk)
  end

  # Runs the block with the main stats the training icon walks (PS, Ataque, Velocidad) and the raid's effort limit,
  # none when limit is nil.
  def with_main_stats(limit = 252)
    stat = Struct.new(:id, :name)
    stats = [stat.new(:HP, "PS"), stat.new(:ATTACK, "Ataque"), stat.new(:SPEED, "Velocidad")]
    pokemon = Object.const_defined?(:Pokemon) ? ::Pokemon : Class.new
    with_const(Object, :Pokemon, pokemon) do
      with_const(pokemon, :RAID_EV_STAT_LIMIT, limit) do
        with_singleton(GameData::Stat, :each_main_battle, lambda { |&b| stats.each(&b) }) { yield }
      end
    end
  end

  # Runs the block with obj's singleton method meth replaced by body, the one obj had (if any) put back after.
  def with_singleton(obj, meth, body)
    meta = obj.singleton_class
    had = meta.instance_methods(false).include?(meth)
    meta.send(:alias_method, :ss2_adv_saved, meth) if had
    obj.define_singleton_method(meth, &body)
    yield
  ensure
    meta.send(:remove_method, meth)
    if had
      meta.send(:alias_method, meth, :ss2_adv_saved)
      meta.send(:remove_method, :ss2_adv_saved)
    end
  end

  # Runs the block with mod's constant name set to value (left out for nil), the one mod had (if any) put back after.
  def with_const(mod, name, value)
    had = mod.const_defined?(name, false)
    saved = had ? mod.send(:remove_const, name) : nil
    mod.const_set(name, value) unless value.nil?
    yield
  ensure
    mod.send(:remove_const, name) if mod.const_defined?(name, false)
    mod.const_set(name, saved) if had
  end

  # The lines a rental of a Pokemon showing only these efforts says, with the main stats and the given effort limit.
  def rental_lines(ev, limit)
    mon = SS2AdvMon.new("Ditto", 2, :types => [], :ability => nil, :moves => [], :ev => ev)
    with_main_stats(limit) { in_menu { select_by_key(AdventureRentalDatabox.new(mon)) } }.map { |text, _i| text }
  end

  # The record's line: its left panel, the party heading and the members (Mon0, Mon1...) under it, then the bar's hints.
  def record_line(members, hints)
    party = (0...members).map do |i|
      ["Mon#{i}", I18N.t(:mv_type, :t => "TypeFIRE"), I18N.t(:dbk_ability, :a => "Mar Llamas"),
       I18N.t(:sm_moves, :list => "Ascuas, Gruñido")].join(", ")
    end
    (["RECORD DATA", "Adventure Map:", "Lair", "Floor Reached:", "5", "Battles Won:", "9", "Endless party:"] +
     party + hints).join(", ")
  end

  # Vulpix as the menus' offer and refills say it.
  def vulpix
    ["Vulpix #{FEMALE}", I18N.t(:mv_type, :t => "TypeFIRE"), I18N.t(:dbk_ability, :a => "Mar Llamas"),
     I18N.t(:sm_moves, :list => "Ascuas, Gruñido")].join(", ")
  end

  # The menus' default first member, Mon0, as its party box says it at full health.
  def first_member
    "Mon0, #{I18N.t(:bt_hp_pct, :n => 100)}"
  end

  # Whether a label painted at (x, y) is said, in a menu where an icon was drawn at (178, 244) on its overlay or on
  # another bitmap.
  def label_said?(icon, where, x, y)
    in_menu do |scene|
      pbDrawImagePositions(where == :overlay ? scene.overlay : Object.new, [[icon, 178, 244, 0, 0, 32, 32]])
      pbDrawTextPositions(scene.overlay, [["Label", x, y]])
      SpeakCapture.lines == ["Label"]
    end
  end

  # A lair map with the player on a Crossroad at (2, 2) among tiles, a frame of it played, nothing said yet.
  # param dark the tiles the darkness hides, as [x, y]
  def lair(tiles, raids = [], dark = [])
    player = SS2AdvTile.new(:Crossroad, 2, 2)
    map = AdventureMapScene.new([player] + tiles, player, raids, dark)
    map.pbUpdate
    SpeakCapture.clear
    map
  end

  # What the path in direction d says on a lair of these tiles; opts: :dark tiles, the lair's :style, and :icons
  # as {battle index => the frame height its icon is cut at}.
  def path_said(d, tiles, raids = [], opts = {})
    map = lair(tiles, raids, opts.fetch(:dark, []))
    map.adventure.style = opts[:style] if opts[:style]
    (opts[:icons] || {}).each { |id, y| map.map_sprites["pkmntype_#{id}"] = SS2AdvIcon.new(y) }
    with_type_icons { ADV.path_text(map, d) }
  end

  # A path's words: its direction, and what it leads to when there is something to name.
  def way(dir, what = nil)
    what ? I18N.t(:ss2_adv_path, :dir => I18N.t(dir), :what => what) : I18N.t(dir)
  end

  # Runs the block with GameData::Type listing TYPE_ICONS by the frame each is cut from.
  def with_type_icons(&blk)
    types = TYPE_ICONS.map { |name, pos| SS2AdvType.new(name, pos) }
    with_singleton(GameData::Type, :each, lambda { |&b| types.each(&b) }, &blk)
  end

  # Runs the block with GameData::RaidType giving every adventure this lair name.
  def with_lair_name(name, &blk)
    raid_type = Class.new
    raid_type.define_singleton_method(:get) { |_style| Struct.new(:lair_name).new(name) }
    with_const(GameData, :RaidType, raid_type, &blk)
  end
end
