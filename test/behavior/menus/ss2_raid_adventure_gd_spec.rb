# Soulstones 2's raid adventures: each choice a box sprite, each instruction an overlay paint, a crossroads an
# arrow's colour. The stand-ins keep only what the readers touch. Gamedata pass.
SS2_ADV_MALE = "\xE2\x99\x82"

class SS2AdvMon
  attr_reader :name, :gender, :hp, :totalhp, :status, :level
  def initialize(name, gender, opts = {})
    @name = name; @gender = gender; @hp = opts[:hp] || 10; @totalhp = opts[:totalhp] || 10; @level = opts[:level] || 20
    @status = opts[:status] || :NONE; @item_name = opts[:item]; @shiny = opts[:shiny]; @ev = opts[:ev] || {}
  end
  def ev; Hash.new(0).merge(@ev); end
  def types; [:FIRE]; end
  def ability; Struct.new(:name).new("Mar Llamas"); end
  def moves; [Struct.new(:name).new("Ascuas"), Struct.new(:name).new("Gruñido")]; end
  def fainted?; @hp <= 0; end
  def hasItem?; !@item_name.nil?; end
  def item; Struct.new(:name).new(@item_name); end
  def shiny?; @shiny ? true : false; end
  def tera_type; :WATER; end
  def gmax_factor?; true; end
end

class SS2AdvBoxBase
  attr_reader :statIcon
  attr_accessor :x, :y
  def initialize(content, opts = {})
    @pokemon = content; @item = content; @move = content
    @style = opts[:style]; @statIcon = opts[:icon] || 0; @quantity = opts[:qty] || 0; @rows = opts[:rows]
    @x = opts[:x] || 166; @y = opts[:y] || 44
    @selected = false
  end
  def selected=(value)
    return if @selected == value
    @selected = value
    pbDrawTextPositions(nil, @rows.map { |r| [r, 0, 0] }) if @rows && value
  end
  def setItemValues(item, qty = 0); @item = item; @quantity = qty; end
  def pokemon=(pk); @pokemon = pk; end
end

# The main stats and RAID_EV_STAT_LIMIT the training icon reads (one stat at the limit, or balanced), put in place
# for the adventure suites only.
module SS2AdvStats
  def self.install
    stat = Struct.new(:id, :name)
    stats = [stat.new(:HP, "PS"), stat.new(:ATTACK, "Ataque"), stat.new(:SPEED, "Velocidad")]
    @had_each = GameData::Stat.respond_to?(:each_main_battle)
    GameData::Stat.define_singleton_method(:each_main_battle) { |&b| stats.each(&b) } unless @had_each
    @made_pokemon = !Object.const_defined?(:Pokemon)
    Object.const_set(:Pokemon, Class.new) if @made_pokemon
    @made_limit = !::Pokemon.const_defined?(:RAID_EV_STAT_LIMIT)
    ::Pokemon.const_set(:RAID_EV_STAT_LIMIT, 252) if @made_limit
  end

  def self.uninstall
    class << GameData::Stat; remove_method :each_main_battle; end unless @had_each
    ::Pokemon.send(:remove_const, :RAID_EV_STAT_LIMIT) if @made_limit && !@made_pokemon
    Object.send(:remove_const, :Pokemon) if @made_pokemon
  end
end

class SS2AdvOverlay
  attr_reader :bitmap
  def initialize; @bitmap = Object.new; end
end

class SS2AdvMenu
  def initialize; @sprites = { "overlay" => SS2AdvOverlay.new }; end
  def pbStartScene(_style = :Basic); end
  def pbEndScene; end
  def pbUpdate; end
  # The exchange as the game lays it out: heading, question, the offer's label, the offer and two button hints.
  def pbExchangeMenu(pk)
    @sprites["pokemon"] = AdventureRentalDatabox.new(pk, :style => :Basic, :x => 166, :y => 140)
    pbDrawImagePositions(@sprites["overlay"].bitmap,
                         [["Graphics/Pictures/Adventure/buttons", 178, 244, 0, 0, 32, 32],
                          ["Graphics/Pictures/Adventure/buttons", 290, 244, 32, 0, 32, 32]])
    pbDrawTextPositions(@sprites["overlay"].bitmap,
                        [["RENTAL PARTY", 79, 8], ["Add it?", 337, 12], ["New Pokemon!", 218, 102],
                         ["View Summary", 218, 254], ["Keep Party", 330, 254]])
  end
  # The record, painted heading, party heading and hint first, then the data down the left panel.
  def pbRecordMenu
    3.times do |i|
      @sprites["rental_#{i}"] = AdventureRentalDatabox.new(SS2AdvMon.new("Mon#{i}", 2), :x => 166, :y => 44 + 96 * i)
    end
    rows = [["RECORD DATA", 79, 8], ["Endless party:", 337, 12], ["Summary", 56, 364]]
    [["Adventure Map:", "Lair"], ["Floor Reached:", "5"], ["Battles Won:", "9"]].each_with_index do |(k, v), i|
      rows.push([k, 10, 64 + 96 * i], [v, 10, 96 + 96 * i])
    end
    pbDrawTextPositions(@sprites["overlay"].bitmap, rows)
  end
  def add(key, sprite); @sprites[key] = sprite; end
  def paint(words); pbDrawTextPositions(@sprites["overlay"].bitmap, words.map { |w| [w, 0, 0] }); end
end

class SS2AdvTile
  NAMES = { :Battle => "Battle", :Chest => "Chest", :Pathway => "Pathway", :Crossroad => "Crossroad",
            :TurnNorth => "Turn North", :HiddenTrap => "Hidden Trap", :Warp => "Warp", :Switch => "Switch" }
  attr_reader :tile_id, :battle_id, :coords, :warp_point
  attr_accessor :tint
  def initialize(id, x, y, opts = {})
    @tile_id = id; @coords = [x, y]; @battle_id = opts[:battle]; @hidden = opts[:hidden]
    @warp_point = opts[:warp]; @on = opts[:on]; @tint = 0
  end
  def tile; Struct.new(:name).new(NAMES[@tile_id]); end
  def interactable?; true; end
  def hidden?; @hidden ? true : false; end
  def switch_on?; @on ? true : false; end
  def color; Struct.new(:alpha).new(@tint); end
  def isTile?(*ids); ids.include?(@tile_id); end
end

class SS2AdvArrow
  attr_writer :lit
  def color; Struct.new(:alpha).new(@lit ? 200 : 0); end
end

class SS2AdvIcon
  attr_reader :src_rect
  def initialize(row); @src_rect = Struct.new(:y).new(row); end
end

class SS2AdvMap
  attr_reader :ui_sprites, :map_sprites, :adventure
  attr_accessor :raid_battles, :player_tile, :on_route
  def initialize(tiles, player, raids, dark)
    @map_sprites = {}
    tiles.each { |t| @map_sprites["tile_#{t.coords[0]}_#{t.coords[1]}"] = t }
    @player_tile = player; @raid_battles = raids; @dark = dark
    @ui_sprites = {}
    4.times { |i| @ui_sprites["route_arrow_#{i}"] = SS2AdvArrow.new }
    @adventure = Struct.new(:style, :hearts, :max_hearts, :keys, :floor, :map).new(:Basic, 3, 3, 0, 1,
                                                                               Struct.new(:name).new("Cueva Brasa"))
  end
  def pbUpdateHearts(value = nil); @adventure.hearts = value if value; end
  def pbMapIntro(_show_title = true); :intro; end
  def title_card!; @ui_sprites["title"] = Object.new; end
  def pbUpdateKeys(value = nil); @adventure.keys += value if value; end
  def pbUpdateFloor; @ui_sprites["floor"] = Struct.new(:text).new("B#{@adventure.floor}F"); end
  def pbTileExists?(x, y); !@map_sprites["tile_#{x}_#{y}"].nil?; end
  def pbCursorReact?; !@dark.include?(@cursor_tile.coords) && !@cursor_tile.isTile?(:Pathway); end
  def pbUpdate(_moving = false); end
  def light(dir); 4.times { |i| @ui_sprites["route_arrow_#{i}"].lit = (i == dir) }; end
  def pbUpdateRouteArrows(dir, _dirs)
    light(dir)
    pbDrawTextPositions(nil, [["Choose your path!", 0, 0]])
    pbUpdateControls(:selecting)
  end
  def pbUpdateControls(mode)
    rows = if mode == :viewing
             [["[USE]", 4, 8], ["[BACK]", 4, 28], ["Toggle Pokemon", 82, 8], ["Return", 82, 28]]
           else
             [["ARROWS: Select", 4, 0], ["USE: Confirm", 256, 0]]
           end
    pbDrawTextPositions(nil, rows)
  end
  def pbSelectRoute(dir, dirs); pbUpdateRouteArrows(dir, dirs); @on_route.call if @on_route; dir; end
  def pbUpdateCursor(_snap = false)
    t = @cursor_tile
    pbDrawTextPositions(nil, [["#{t.coords[0]}, #{t.coords[1]}", 0, 0], [t.tile.name, 0, 0]])
  end
  def point_at(t); @cursor_tile = t; pbUpdateCursor; end
end

# Holds an arrow down for the block; a box selected with no arrow down is one the game selected by itself.
def ss2_adv_key_down
  class << Input
    alias_method :ss2_adv_repeat, :repeat?
    def repeat?(k); k == Input::RIGHT; end
  end
  yield
ensure
  class << Input
    alias_method :repeat?, :ss2_adv_repeat
    remove_method :ss2_adv_repeat
  end
end

# One class per name, made once: the profile binds at its single load, so every suite hands it the same classes.
SS2_ADV_CLASSES = {
  :AdventureMenuScene => SS2AdvMenu, :AdventureMapScene => SS2AdvMap,
  :AdventurePartyDatabox => Class.new(SS2AdvBoxBase), :AdventureRentalDatabox => Class.new(SS2AdvBoxBase),
  :AdventureRewardbox => Class.new(SS2AdvBoxBase), :AdventureItembox => Class.new(SS2AdvBoxBase),
  :AdventureMovebox => Class.new(SS2AdvBoxBase), :AdventureAttributebox => Class.new(SS2AdvBoxBase),
  :AdventureDynamaxbox => Class.new(SS2AdvBoxBase)
}

# Puts the adventure classes in place, loads the profile over them once, runs the block, and takes them away.
def ss2_adventure
  saved = {}
  SS2_ADV_CLASSES.each_key { |c| saved[c] = Object.const_get(c) if Object.const_defined?(c) }
  SS2_ADV_CLASSES.each do |c, k|
    Object.send(:remove_const, c) if Object.const_defined?(c)
    Object.const_set(c, k)
  end
  unless $ss2_adv_loaded
    load File.expand_path("../../../games/soulstones2/raid_adventure.rb", File.dirname(__FILE__))
    $ss2_adv_loaded = true
  end
  SS2AdvStats.install
  yield
ensure
  SS2AdvStats.uninstall
  SS2_ADV_CLASSES.each_key do |c|
    Object.send(:remove_const, c) if Object.const_defined?(c)
    Object.const_set(c, saved[c]) if saved[c]
  end
end

Suite.define("ss2 adventure: each box is read as it becomes the selected one, from what it shows") do
  t = PokeAccess::I18n
  ss2_adventure do
    ss2_adv_key_down do
    scene = AdventureMenuScene.new
    scene.pbStartScene
    scene.pbUpdate
    mon = SS2AdvMon.new("Charmander", 0, :hp => 30, :totalhp => 39, :item => "Baya Zidra", :ev => { :ATTACK => 252 })
    party = AdventurePartyDatabox.new(mon, :style => :Basic)
    party.selected = true
    eq "a party member: name and sign, the share its bar fills, that it holds something, and its training",
       SpeakCapture.log,
       [["Charmander #{SS2_ADV_MALE}, #{PokeAccess::Battle.hp_phrase(30, 39, true)}, #{t.t(:ss2_adv_holds)}, " \
         "#{t.t(:ss2_adv_training, :s => "Ataque")}", true]]
    SpeakCapture.clear
    party.selected = true
    silent "the selected box selected again says nothing"

    SpeakCapture.clear
    zmon = SS2AdvMon.new("Pikachu", 1, :item => "Electrostal Z")
    AdventurePartyDatabox.new(zmon, :style => :Ultra).selected = true
    match "an Ultra lair's box shows the Z-crystal itself, so it is named", SpeakCapture.lines.join(" "),
          /#{Regexp.escape(t.t(:dbk_item, :i => "Electrostal Z"))}/

    SpeakCapture.clear
    spread = SS2AdvMon.new("Charmander", 0, :item => "Baya Zidra", :ev => { :HP => 40, :SPEED => 40 })
    AdventureRentalDatabox.new(spread, :style => :Tera).selected = true
    eq "a rental: types, ability, moves, its item, the Tera type and the balanced training icon", SpeakCapture.lines,
       [["Charmander #{SS2_ADV_MALE}", t.t(:mv_type, :t => "TypeFIRE"), t.t(:dbk_ability, :a => "Mar Llamas"),
         t.t(:sm_moves, :list => "Ascuas, Gruñido"), t.t(:ss2_adv_holds), t.t(:ss2_adv_tera, :t => "TypeWATER"),
         t.t(:ss2_adv_training_balanced)].join(", ")]

    SpeakCapture.clear
    AdventureRewardbox.new(SS2AdvMon.new("Eevee", 2, :shiny => true)).selected = true
    eq "a captured Pokemon: no sign for a genderless one, and the shiny mark", SpeakCapture.lines,
       ["Eevee, #{t.t(:pk_shiny)}"]

    SpeakCapture.clear
    potion = Struct.new(:name, :is_machine?).new("Pocion", false)
    square = AdventureItembox.new(potion, :qty => 3)
    square.selected = true
    eq "an item square with the count it paints", SpeakCapture.lines, ["Pocion, x3"]

    SpeakCapture.clear
    square.setItemValues(Struct.new(:name, :is_machine?).new("Eter", false), 2)
    square.selected = true
    eq "a page turned under a square that stays selected reads its new item", SpeakCapture.lines, ["Eter, x2"]
    SpeakCapture.clear
    square.selected = true
    silent "and only once"

    SpeakCapture.clear
    AdventureAttributebox.new(nil, :rows => ["Tera Fire"]).selected = true
    eq "a stat or Tera type box is its painted word", SpeakCapture.lines, ["Tera Fire"]

    SpeakCapture.clear
    AdventureDynamaxbox.new(nil, :rows => ["Pikachu", "Dynamax HP", "+3", "120 -> 135", SS2_ADV_MALE]).selected = true
    eq "a Dynamax box, which the menu walks by itself: queued, the sign beside the name, the arrow a change",
       SpeakCapture.log,
       [["Pikachu, #{SS2_ADV_MALE}, Dynamax HP, +3, #{t.t(:ss2_adv_change, :from => "120", :to => "135")}", false]]
    scene.pbEndScene
    end
  end
end

Suite.define("ss2 adventure: a menu opens with its instruction, then its box; later boxes answer their keys") do
  ss2_adventure do
    scene = AdventureMenuScene.new
    scene.pbStartScene
    first = AdventureRewardbox.new(SS2AdvMon.new("Ralts", 1))
    second = AdventureRewardbox.new(SS2AdvMon.new("Kirlia", 1))
    SpeakCapture.clear
    first.selected = true
    scene.paint(["CAPTURED POKEMON", "Select a Pokemon to keep."])
    eq "the heading and instruction first, though the game selected the box before painting them, both queued",
       SpeakCapture.log, [["CAPTURED POKEMON, Select a Pokemon to keep.", false], ["Ralts \xE2\x99\x80", false]]

    SpeakCapture.clear
    scene.pbUpdate
    scene.paint(["CAPTURED POKEMON", "Select a Pokemon to keep."])
    silent "the same words painted again say nothing"

    first.selected = false
    ss2_adv_key_down { second.selected = true }
    eq "a box moved to by a key interrupts", SpeakCapture.log, [["Kirlia \xE2\x99\x80", true]]

    SpeakCapture.clear
    scene.pbUpdate
    scene.paint(["CAPTURED POKEMON", "Select another."])
    second.selected = false
    first.selected = true
    eq "an instruction changed in the same step is not cut by the box after it", SpeakCapture.log.map { |l| l[1] },
       [false, false]
    eq "and it comes alone, the heading being the same", SpeakCapture.log[0][0], "Select another."

    SpeakCapture.clear
    scene.pbUpdate
    pbDrawTextPositions(Object.new, [["Elsewhere", 0, 0]])
    silent "a paint onto any other bitmap is not the overlay"

    SpeakCapture.clear
    scene.pbUpdate
    rental = AdventureRentalDatabox.new(SS2AdvMon.new("Vulpix", 1))
    ss2_adv_key_down { rental.selected = true }
    SpeakCapture.clear
    scene.pbUpdate
    rental.selected = false
    rental.pokemon = SS2AdvMon.new("Growlithe", 0)
    rental.selected = true
    scene.paint(["RENTAL PARTY", "Select 1 more rental Pokemon.", "Summary"])
    eq "a rental list the game refills by itself says its new instruction, then the box it selected before " \
       "painting it, both queued behind the pick's own message",
       SpeakCapture.log, [["RENTAL PARTY, Select 1 more rental Pokemon., Summary", false],
                          [PokeAccess::SS2Adventure.rental_text(rental), false]]

    SpeakCapture.clear
    scene.pbUpdate
    member = AdventurePartyDatabox.new(SS2AdvMon.new("Pichu", 1))
    member.selected = true
    silent "a box the game selects with no key down waits for the step"
    scene.pbUpdate
    eq "and a step that paints nothing says it when it ends, queued", SpeakCapture.log, [["Pichu \xE2\x99\x80, " \
       "#{PokeAccess::Battle.hp_phrase(10, 10, true)}", false]]

    SpeakCapture.clear
    scene.pbUpdate
    scene.pbExchangeMenu(SS2AdvMon.new("Vulpix", 1))
    offer = PokeAccess::SS2Adventure.rental_text(PokeAccess.sprite(scene, "pokemon"), true)
    eq "an exchange reads as it is laid out: the heading, the question, the label over the offer, the offer, " \
       "then the two button hints drawn over it", SpeakCapture.lines,
       [["RENTAL PARTY", "Add it?", "New Pokemon!", offer, "View Summary", "Keep Party"].join(", ")]
    scene.pbEndScene
  end
end

Suite.define("ss2 adventure: the record reads its data, then the party under its heading, and the hint last") do
  ss2_adventure do
    scene = AdventureMenuScene.new
    scene.pbStartScene
    scene.pbUpdate
    SpeakCapture.clear
    scene.pbRecordMenu
    party = (0..2).map { |i| PokeAccess::SS2Adventure.rental_text(PokeAccess.sprite(scene, "rental_#{i}"), false) }
    eq "left panel first, then the party column, then the bottom bar", SpeakCapture.lines,
       [(["RECORD DATA", "Adventure Map:", "Lair", "Floor Reached:", "5", "Battles Won:", "9", "Endless party:"] +
         party + ["Summary"]).join(", ")]
    scene.pbEndScene
  end
end

Suite.define("ss2 adventure: a crossroads says each path and where it leads, and the path the arrow turns to") do
  t = PokeAccess::I18n
  mark = lambda { |ty| Struct.new(:name, :icon_position).new(ty, ty == "TypeFIRE" ? 0 : 1) }
  GameData::Type.define_singleton_method(:each) { |&b| [mark.call("TypeFIRE"), mark.call("TypeWATER")].each(&b) }
  begin
    ss2_adventure do
      player = SS2AdvTile.new(:Crossroad, 2, 2)
      tiles = [player,
               SS2AdvTile.new(:Pathway, 2, 1), SS2AdvTile.new(:Battle, 2, 0, :battle => 0),
               SS2AdvTile.new(:HiddenTrap, 1, 2, :hidden => true), SS2AdvTile.new(:TurnNorth, 0, 2),
               SS2AdvTile.new(:Pathway, 0, 1), SS2AdvTile.new(:Chest, 0, 0),
               SS2AdvTile.new(:Battle, 3, 2, :battle => 1), SS2AdvTile.new(:Pathway, 4, 2), SS2AdvTile.new(:Chest, 5, 2),
               SS2AdvTile.new(:Pathway, 2, 3)]
      raids = [{ :rank => 3 }, { :rank => 2, :battled => true }]
      map = AdventureMapScene.new(tiles, player, raids, [[5, 2]])
      map.map_sprites["pkmntype_0"] = SS2AdvIcon.new(0)
      up = t.t(:ss2_adv_path, :dir => t.t(:dir_up),
               :what => "Battle, #{t.t(:ss2_raid_rank, :n => 3)}, #{t.t(:mv_type, :t => "TypeFIRE")}")
      left = t.t(:ss2_adv_path, :dir => t.t(:dir_left), :what => t.t(:ss2_adv_then, :a => "Hidden Trap", :b => "Chest"))

      map.on_route = lambda do
        SpeakCapture.clear
        PokeAccess::SS2Adventure.poll_route
        silent_now = SpeakCapture.lines.empty?
        map.light(2)
        PokeAccess::SS2Adventure.poll_route
        $ss2_adv_turned = [silent_now, SpeakCapture.log]
      end
      eq "the choice keeps its own return", map.pbSelectRoute(0, [0, 1, 2, 3]), 0
      truthy "the arrow lit on arrival is the one already said", $ss2_adv_turned[0]
      eq "turning the arrow says that path, interrupting", $ss2_adv_turned[1], [[left, true]]

      SpeakCapture.clear
      map.pbUpdateRouteArrows(0, [0, 1, 2, 3])
      eq "the crossroads line: the game's words, each path (a battle's rank and the type over its silhouette; " \
         "the trap drawn on the way, then past a turn; past a fought battle into the dark, and a dead end, by " \
         "direction only), the lit one, then the legend",
         SpeakCapture.log,
         [[["Choose your path!", up, t.t(:dir_down), left, t.t(:dir_right), t.t(:ss2_adv_lit, :dir => t.t(:dir_up)),
            "ARROWS: Select, USE: Confirm"].join(". "), false]]

      SpeakCapture.clear
      map.light(3)
      PokeAccess::SS2Adventure.poll_route
      silent "with the choice over, the arrows are not watched, whichever one is lit"
    end
  ensure
    class << GameData::Type; remove_method :each; end
    $ss2_adv_turned = nil
  end
end

Suite.define("ss2 adventure: a path names a warp's destination and a switch's position, and not a trap in the dark") do
  t = PokeAccess::I18n
  ss2_adventure do
    player = SS2AdvTile.new(:Crossroad, 2, 2)
    tiles = [player, SS2AdvTile.new(:Warp, 2, 1, :warp => [7, 3]),
             SS2AdvTile.new(:Switch, 1, 2, :on => true),
             SS2AdvTile.new(:HiddenTrap, 3, 2, :hidden => true), SS2AdvTile.new(:Chest, 4, 2)]
    map = AdventureMapScene.new(tiles, player, [], [[3, 2], [4, 2]])
    eq "a warp says where it leads, as the cursor writes it", PokeAccess::SS2Adventure.path_text(map, 0),
       t.t(:ss2_adv_path, :dir => t.t(:dir_up), :what => t.t(:ss2_adv_warp, :name => "Warp", :x => 7, :y => 3))
    eq "a switch says its position", PokeAccess::SS2Adventure.path_text(map, 2),
       t.t(:ss2_adv_path, :dir => t.t(:dir_left), :what => "Switch, #{t.t(:val_on)}")
    eq "a trap the dark hides is not said, nor what lies past it in the dark", PokeAccess::SS2Adventure.path_text(map, 3),
       t.t(:dir_right)
  end
end

Suite.define("ss2 adventure: the free map view says its keys, then the tile under the cursor") do
  ss2_adventure do
    player = SS2AdvTile.new(:Crossroad, 2, 2)
    chest = SS2AdvTile.new(:Chest, 0, 0)
    map = AdventureMapScene.new([player, chest], player, [], [])
    SpeakCapture.clear
    map.pbUpdateControls(:viewing)
    map.point_at(player)
    eq "the legend's two columns paired back up, and the tile after it, both queued", SpeakCapture.log,
       [["[USE] Toggle Pokemon, [BACK] Return", false], ["2, 2, Crossroad", false]]

    SpeakCapture.clear
    map.pbUpdate(true)
    map.point_at(player)
    silent "the same tile again says nothing"
    map.point_at(chest)
    eq "a new tile interrupts", SpeakCapture.log, [["0, 0, Chest", true]]

    SpeakCapture.clear
    map.pbUpdate(true)
    map.pbUpdateControls(:viewing)
    map.point_at(chest)
    eq "opening the view again reads the tile again, though it is the last one heard", SpeakCapture.lines,
       ["[USE] Toggle Pokemon, [BACK] Return", "0, 0, Chest"]

    SpeakCapture.clear
    map.pbUpdateControls(:moving)
    silent "the walking legend is not the view's and says nothing"

    SpeakCapture.clear
    map.pbUpdate(true)
    far = SS2AdvTile.new(:Crossroad, 6, 6)
    far.tint = 125
    map.point_at(far)
    eq "picking where to teleport, a Crossroad the map tints is said not visited", SpeakCapture.lines,
       ["6, 6, Crossroad, #{PokeAccess::I18n.t(:ss2_adv_unvisited)}"]
  end
end

Suite.define("ss2 adventure: the corner counters are said when they change") do
  t = PokeAccess::I18n
  ss2_adventure do
    player = SS2AdvTile.new(:Crossroad, 2, 2)
    map = AdventureMapScene.new([player], player, [], [])
    SpeakCapture.clear
    map.pbUpdateHearts
    map.pbUpdateKeys
    map.pbUpdateFloor
    eq "opening: the hearts and the floor, queued; no key counter while there is none", SpeakCapture.log,
       [[t.t(:ss2_adv_hearts, :n => 3, :max => 3), false], [t.t(:ss2_adv_floor, :f => "B1F"), false]]

    SpeakCapture.clear
    map.pbUpdateHearts
    silent "a redraw with the same hearts says nothing"
    map.pbUpdateHearts(1)
    map.pbUpdateKeys(1)
    eq "a heart lost and a key found", SpeakCapture.lines,
       [t.t(:ss2_adv_hearts, :n => 1, :max => 3), t.t(:ss2_adv_keys, :n => 1)]

    SpeakCapture.clear
    map.pbUpdateKeys(-1)
    eq "the last key used is said too, as its icon goes", SpeakCapture.lines, [t.t(:ss2_adv_keys, :n => 0)]
  end
end

Suite.define("ss2 adventure: the lair's title card is said as the map opens") do
  ss2_adventure do
    made = !GameData.const_defined?(:RaidType)
    GameData.const_set(:RaidType, Class.new) if made
    GameData::RaidType.define_singleton_method(:get) { |_s| Struct.new(:lair_name).new("Basic Adventure") }
    begin
      player = SS2AdvTile.new(:Crossroad, 2, 2)
      map = AdventureMapScene.new([player], player, [], [])
      SpeakCapture.clear
      map.pbMapIntro
      silent "a floor with no title card (a playtest) says none"
      map.title_card!
      eq "the intro keeps its own return", map.pbMapIntro, :intro
      eq "the adventure's name, then the lair's, queued", SpeakCapture.log, [["Basic Adventure, Cueva Brasa", false]]
      SpeakCapture.clear
      map.pbMapIntro(false)
      silent "and a floor entered without the card says nothing"
    ensure
      class << GameData::RaidType; remove_method :get; end
      GameData.send(:remove_const, :RaidType) if made
    end
  end
end

Suite.define("ss2 adventure: each box at its reading's level, the info key keeping what the level leaves out") do
  t = PokeAccess::I18n
  ss2_adventure do
    ss2_adv_key_down do
      scene = AdventureMenuScene.new
      scene.pbStartScene
      scene.pbUpdate
      hp = PokeAccess::Battle.hp_phrase(30, 39, true)
      mon = SS2AdvMon.new("Charmander", 0, :hp => 30, :totalhp => 39, :item => "Baya Zidra", :ev => { :ATTACK => 252 })
      party = vb_levels do
        box = AdventurePartyDatabox.new(mon, :style => :Tera)
        SpeakCapture.clear
        box.selected = true
        SpeakCapture.last
      end
      eq "a party box in brief: the name and the hit points", party[0], "Charmander, #{hp}"
      eq "and medium adds nothing a party box paints", party[1], party[0]
      match "full: the sign, the item and the icons", party[2],
            /#{SS2_ADV_MALE}.*#{Regexp.escape(t.t(:ss2_adv_tera, :t => "TypeWATER"))}/
      PokeAccess::Config.verbosity = :brief
      AdventurePartyDatabox.new(mon, :style => :Tera).selected = true
      PokeAccess::Config.verbosity = :full
      match "the info key says the Pokemon", PokeAccess::Info.info_text.to_s, /\ACharmander/
      eq "and Ctrl+T the box whole, whatever the level", PokeAccess::Info.row_text, party[2]

      spread = SS2AdvMon.new("Charmander", 0, :item => "Baya Zidra", :ev => { :HP => 40, :SPEED => 40 })
      rental = vb_levels do
        box = AdventureRentalDatabox.new(spread, :style => :Tera)
        SpeakCapture.clear
        box.selected = true
        SpeakCapture.last
      end
      eq "a rental in brief: the name", rental[0], "Charmander"
      eq "medium: and its types", rental[1], "Charmander, #{t.t(:mv_type, :t => "TypeFIRE")}"
      eq "Ctrl+T says the rental whole", PokeAccess::Info.row_text, rental[2]

      eevee = SS2AdvMon.new("Eevee", 0, :shiny => true)
      reward = vb_levels do
        box = AdventureRewardbox.new(eevee)
        SpeakCapture.clear
        box.selected = true
        SpeakCapture.last
      end
      eq "a captured Pokemon in brief and medium: its name", reward[0, 2], %w[Eevee Eevee]
      eq "full: the sign and the shiny mark", reward[2], "Eevee #{SS2_ADV_MALE}, #{t.t(:pk_shiny)}"

      PokeAccess::Config.verbosity = :brief
      potion = Struct.new(:name, :is_machine?).new("Pocion", false)
      AdventureItembox.new(potion, :qty => 3).selected = true
      eq "Ctrl+T says an item square", PokeAccess::Info.row_text, "Pocion, x3"
      PokeAccess::Config.verbosity = :full

      mv = Struct.new(:name, :type, :total_pp, :base_damage, :accuracy, :category).new("Ascuas", :FIRE, 25, 40, 100, 1)
      moves = vb_levels do
        box = AdventureMovebox.new(mv)
        SpeakCapture.clear
        box.selected = true
        SpeakCapture.last
      end
      eq "a move to teach in brief: its name", moves[0], "Ascuas"
      eq "medium: and its type", moves[1], "Ascuas. #{t.t(:mv_type, :t => "TypeFIRE")}"
      truthy "full: the whole line", moves[2].length > moves[1].length
      eq "Ctrl+T says the whole line", PokeAccess::Info.row_text, moves[2]
      scene.pbEndScene
    end
  end
end

Suite.define("ss2 adventure: a menu's footer keys, a crossroads' legend and the view's keys go with the hints") do
  ss2_adventure do
    PokeAccess::Config.verbosity = :brief
    begin
      scene = AdventureMenuScene.new
      scene.pbStartScene
      scene.pbUpdate
      SpeakCapture.clear
      pbDrawTextPositions(scene.instance_variable_get(:@sprites)["overlay"].bitmap,
                          [["SPOILS", 0, 0], ["Choose an item.", 0, 20], ["USE: Take", 0, 360]])
      eq "brief: the heading and the instruction, not the keys of the bottom bar", SpeakCapture.lines,
         ["SPOILS, Choose an item."]
      SpeakCapture.clear
      scene.pbUpdate
      scene.pbExchangeMenu(SS2AdvMon.new("Vulpix", 1))
      said = SpeakCapture.lines.join(" ")
      truthy "nor the labels painted beside the exchange's key buttons",
             said.include?("New Pokemon!") && !said.include?("View Summary") && !said.include?("Keep Party")
      scene.pbEndScene

      player = SS2AdvTile.new(:Crossroad, 2, 2)
      chest = SS2AdvTile.new(:Chest, 2, 1)
      map = AdventureMapScene.new([player, chest], player, [], [])
      SpeakCapture.clear
      map.pbSelectRoute(0, [0])
      line = SpeakCapture.lines.first.to_s
      truthy "a crossroads says its paths without its key legend", line.include?("Choose your path!") && !line.include?("ARROWS")

      twin = SS2AdvTile.new(:Chest, 1, 0)
      far = SS2AdvTile.new(:Chest, 0, 0)
      view = AdventureMapScene.new([player, far, twin], player, [], [])
      SpeakCapture.clear
      view.pbUpdateControls(:viewing)
      view.point_at(far)
      eq "the view opens without its legend, on the tile's name without its coordinates", SpeakCapture.lines, ["Chest"]
      eq "the info key keeps the coordinates", PokeAccess::Info.info_text, "0, 0, Chest"
      SpeakCapture.clear
      view.pbUpdate(true)
      view.point_at(twin)
      eq "a tile of the same name elsewhere is said too", SpeakCapture.lines, ["Chest"]
      PokeAccess::Config.verbosity = :medium
      SpeakCapture.clear
      view.pbUpdate(true)
      view.point_at(far)
      eq "medium: with its coordinates", SpeakCapture.lines, ["0, 0, Chest"]
      view.pbUpdateControls(:moving)
      eq "leaving the view takes the tile off the info key", PokeAccess::Info.info_text, nil
    ensure
      PokeAccess::Config.verbosity = :full
    end
  end
end

Suite.define("ss2 adventure: the menu's description window waits for full, and the info key keeps it") do
  ss2_adventure do
    ss2_adv_key_down do
      scene = AdventureMenuScene.new
      scene.add("window", Struct.new(:text, :visible).new("Restores 20 HP.", true))
      scene.pbStartScene
      scene.pbUpdate
      PokeAccess::Config.verbosity = :brief
      begin
        AdventureItembox.new(Struct.new(:name, :is_machine?).new("Pocion", false), :qty => 3).selected = true
        SpeakCapture.clear
        PokeAccess::InfoWindow.tick
        silent "brief: the description window is not said"
        eq "and Ctrl+T says it after the square", PokeAccess::Info.row_text, "Pocion, x3. Restores 20 HP."
        PokeAccess::Config.verbosity = :full
        SpeakCapture.clear
        PokeAccess::InfoWindow.tick
        spoke "full: the window is said", /Restores 20 HP/
        eq "and Ctrl+T keeps saying it after the square", PokeAccess::Info.row_text, "Pocion, x3. Restores 20 HP."
      ensure
        PokeAccess::Config.verbosity = :full
        scene.pbEndScene
      end
    end
  end
end
