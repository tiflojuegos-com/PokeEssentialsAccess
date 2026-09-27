# Relict's Destiny Tower floors (games/relict/tower.rb), gamedata pass: the events Create events.rb copies onto a
# floor named by what their sprite draws and filed as objects, the stairs held back until the minimap shows them, and
# the Event Indicators bubble said as a mark. The profile's overrides are loaded for each suite and taken back after.
module RelictTowerSpec
  SEAMS = [:target_name, :event_category, :tag_hidden?]
  PATH = File.expand_path("../../../games/relict/tower.rb", File.dirname(__FILE__))

  # The name a seam's pre-load form is kept under while the profile is loaded.
  def self.saved(meth)
    "relict_spec_#{meth.to_s.delete('?')}".to_sym
  end

  # Runs the block with the profile's locator overrides loaded, and takes them back after; a reload's constants
  # are the same ones, so their warnings are silenced.
  def self.with_tower
    meta = (class << PokeAccess::Locator; self; end)
    SEAMS.each { |m| meta.send(:alias_method, saved(m), m) }
    verbose = $VERBOSE
    begin
      $VERBOSE = nil
      load PATH
      $VERBOSE = verbose
      yield
    ensure
      $VERBOSE = verbose
      SEAMS.each do |m|
        meta.send(:alias_method, m, saved(m))
        meta.send(:remove_method, saved(m))
      end
    end
  end

  # A floor event as Create events.rb leaves it: a template's page (touch, one script call) under a copy's name.
  def self.floor_event(id, name, sprite, script = "getItemDungeonEvent")
    page = TestPage.new(:trigger => 1, :sprite => sprite, :list => [TestCmd.new(355, [script]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => 5 + id, :y => 5, :name => name, :pages => [page])
    $game_map.events[id] = ev
    ev
  end

  # The locator's list for one category, rebuilt now.
  def self.listed(cat)
    loc = PokeAccess::Locator
    loc.instance_variable_set(:@cat, loc.active_categories.index(cat))
    loc.rebuild_targets
    loc.instance_variable_get(:@targets)
  end

  # Runs the block on a map with (or without) the dungeonDisplay flag and the minimap's sawStairs as given.
  def self.on_floor(flagged, saw)
    meta = Object.new
    meta.define_singleton_method(:has_flag?) { |f| flagged && f == "dungeonDisplay" }
    $game_map.define_singleton_method(:metadata) { meta }
    $PokemonGlobal.define_singleton_method(:sawStairs) { saw }
    yield
  ensure
    class << $game_map; remove_method(:metadata) rescue nil; end
    class << $PokemonGlobal; remove_method(:sawStairs) rescue nil; end
  end

  # An indicator sprite as Event Indicators keeps it, per event id, on the map's spriteset.
  Indicator = Struct.new(:visible, :gone) do
    def disposed?; gone; end
  end

  # Runs the block with the scene's spriteset carrying these indicator sprites.
  def self.with_indicators(sprites)
    set = Object.new
    set.define_singleton_method(:event_indicator_sprites) { sprites }
    $scene.define_singleton_method(:spriteset) { |*_a| set }
    yield
  ensure
    class << $scene; remove_method(:spriteset) rescue nil; end
  end
end

Suite.define("relict tower: a floor's items and gold are objects named by the class their sprite draws") do
  t = PokeAccess::I18n
  loc = PokeAccess::Locator
  potion = RelictTowerSpec.floor_event(12, "item_copy12_POTION", "item_potion")
  gold = RelictTowerSpec.floor_event(13, "gold_copy13_GOLD_130", "item_gold", "getGoldDungeonEvent")
  ball = RelictTowerSpec.floor_event(14, "item_copy14_ULTRABALL", "item_ball")
  starter = RelictTowerSpec.floor_event(4, "pokeball0", "item_ball", "askPokeStarter(0)")
  eq "the core reads the copy's own name, symbol and all", loc.target_name(potion), "item_copy12_POTION"
  eq "and files it with the people", loc.event_category(potion), :people
  RelictTowerSpec.with_tower do
    eq "with item names on, the item it gives, as any item on the ground",
       loc.target_name(potion), t.t(:loc_object_named, :name => PokeAccess::Data.item_name(:POTION))
    eq "the gold by what its sprite shows, never the amount in its name", loc.target_name(gold), t.t(:rel_item_gold)
    eq "a starter's ball by its sprite", loc.target_name(starter), t.t(:rel_item_ball)
    PokeAccess::Config.name_items = false
    eq "item names off: the class the sprite draws", loc.target_name(potion), t.t(:rel_item_potion)
    eq "a ball's class", loc.target_name(ball), t.t(:rel_item_ball)
    PokeAccess::Config.name_items = true
    eq "all of them are objects", [potion, gold, ball, starter].map { |e| loc.event_category(e) }.uniq, [:objects]
    listed = RelictTowerSpec.listed(:objects)
    truthy "and the objects list holds them", [potion, gold, ball, starter].all? { |e| listed.include?(e) }
    falsy "while the people list does not", RelictTowerSpec.listed(:people).include?(gold)
    gold.character_name = ""
    eq "picked up (its sprite cleared), still its class, never its internal name", loc.target_name(gold),
       t.t(:rel_item_gold)
    falsy "and out of the list", RelictTowerSpec.listed(:objects).include?(gold)
  end
end

Suite.define("relict tower: a dialogue Pokemon is named by the species its sprite draws") do
  loc = PokeAccess::Locator
  poke = RelictTowerSpec.floor_event(15, "dialogue_poke_copy15_SLOWKING_1", "Followers/SLOWKING_1", "dialoguePokeEvent")
  RelictTowerSpec.with_tower do
    eq "its species, form included in the symbol", loc.target_name(poke), PokeAccess::Data.species_name(:SLOWKING_1)
    eq "still among the people", loc.event_category(poke), :people
  end
end

Suite.define("relict tower: the stairs stay out of the locator and the sonar until the minimap shows them") do
  loc = PokeAccess::Locator
  stairs = RelictTowerSpec.floor_event(1, "stairs", "stairs", "pbCommonEvent(3)")
  RelictTowerSpec.with_tower do
    RelictTowerSpec.on_floor(true, false) do
      truthy "unseen on a tower floor, hidden", loc.tag_hidden?(stairs)
      falsy "left out of the list", RelictTowerSpec.listed(:all).include?(stairs)
      eq "and silent on the sonar", PokeAccess::Audio3D.type_of(stairs), nil
    end
    RelictTowerSpec.on_floor(true, true) do
      falsy "once seen, back", loc.tag_hidden?(stairs)
      truthy "in the list", RelictTowerSpec.listed(:all).include?(stairs)
    end
    RelictTowerSpec.on_floor(false, false) do
      falsy "a map without the tower's minimap never hides them", loc.tag_hidden?(stairs)
    end
  end
end

Suite.define("relict tower: the Event Indicators bubble is said with the name while it shows") do
  t = PokeAccess::I18n
  loc = PokeAccess::Locator
  azelf = World.event(:kind => :npc, :id => 2, :name => "azelf", :sprite => "Azelf")
  poke = RelictTowerSpec.floor_event(16, "dialogue_poke_copy16_MAGIKARP", "Followers/MAGIKARP", "dialoguePokeEvent")
  shown = RelictTowerSpec::Indicator.new(true, false)
  sprites = []
  sprites[2] = shown
  sprites[16] = RelictTowerSpec::Indicator.new(false, false)
  RelictTowerSpec.with_tower do
    RelictTowerSpec.with_indicators(sprites) do
      eq "a shown bubble marks the name", loc.target_name(azelf), "azelf, #{t.t(:rel_indicator)}"
      eq "a hidden one does not", loc.target_name(poke), PokeAccess::Data.species_name(:MAGIKARP)
      shown.gone = true
      eq "nor does a disposed one", loc.target_name(azelf), "azelf"
    end
    eq "and without the plugin's sprites, nothing changes", loc.target_name(azelf), "azelf"
  end
end
