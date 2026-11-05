# The Pokemon Keishou profile loaded whole under the GameData engine, over doubles with the shape of its scripts: its keys,
# its passability, the plugins it declares, the stats page's IVs and EVs, the Enhanced UI's egg groups and happiness, the
# Tera Type, the crafting bench's count, the quest marks, the Rock Climb, the breakable ice and the field moves its Advanced
# Items hands to items. In a process of its own, its overrides would reach every other test here.
class KeishouProfileTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    # The methods the release's plugins add to the stock scene, and its settings.
    module Battle; end
    class Battle::Scene
      def pbFightMenu_EnhancedUI(_battler, _cw); nil; end
    end
    module Settings
      SUMMARY_EGG_GROUPS = true
      SUMMARY_HAPPINESS_METER = true
      SUMMARY_TERA_TYPES = true
      STORAGE_TERA_TYPES = true
    end

    # A Pokemon as BW Summary Screen and the plugins read it.
    KPoke = Struct.new(:hp, :totalhp, :iv, :ev, :tera_type, :happiness, :species_data, :attack, :defense, :spatk, :spdef, :speed) do
      def egg?; false; end
      def shadowPokemon?; false; end
      def genderless?; false; end
    end
    KSpecies = Struct.new(:egg_groups)

    # The bench's scene, as far as the line asks.
    class KeishouBench; end

    # The map's events and the indicators over them, as Spriteset_Map holds them by event id.
    KIndicator = Struct.new(:type, :visible) do
      def disposed?; false; end
    end
    KEvent = Struct.new(:id, :map_id)

    # Its copy of Advanced Items, as 00_Config.rb and 03_Item Handler.rb have it.
    module AdvancedItemsFieldMoves
      SURF_CONFIG = { :internal_name => :SURFITEM, :active => true, :needed_badge => 0, :needed_switches => [] }
      ROCKCLIMB_CONFIG = { :internal_name => :ROCKCLIMBITEM, :active => true, :needed_badge => 0, :needed_switches => [] }
    end

    def pbCanUseItem(item); $kbag.include?(item[:internal_name]); end
  RUBY

  PLAY = <<-'RUBY'
    pk = KPoke.new(10, 20, Hash.new(31), Hash.new(4), :FIRE, 255, KSpecies.new([:Monster]), 1, 2, 3, 4, 5)

    probe(:profile_name) { PokeAccess::Game.profile_name }
    probe(:key_letters) { PokeAccess::KeyHints.table }
    probe(:plain_passability) { PokeAccess::World::Probe.plain? }
    probe(:plugins) do
      [:HackingMinigame, :CharmCase, :PunchBagV12, :EnhancedUIV1, :TerastalPhenomenon, :ZudLairMap, :ZudRaidDens,
       :ZudRaidDatabase, :ItemCrafting, :QuestUI].reject { |m| PokeAccess.const_defined?(m) }
    end
    probe(:fire) { PokeAccess::Data.type_name(:FIRE) }
    probe(:stats) { PokeAccess::SummaryGameData.stats_extras(pk) }
    probe(:iv_ev) { PokeAccess::SummaryGameData.iv_ev_text(pk) }
    probe(:memo) { PokeAccess::SummaryGameData.memo_extras(pk) }
    probe(:header) { PokeAccess::Summary.header_icons(pk) }
    probe(:pc) { PokeAccess::Party.pc_details(pk) }

    $bag = Object.new
    def $bag.quantity(item); item == :POTION ? 3 : 0; end
    probe(:bench) { PokeAccess::ItemCrafting.detail_line(KeishouBench.new, [:POTION, []], 0, 1, nil) }

    ev = KEvent.new(4, 1)
    other = KEvent.new(5, 1)
    third = KEvent.new(6, 1)
    egg = KEvent.new(7, 1)
    $game_map = Object.new
    def $game_map.events; @events; end
    $game_map.instance_variable_set(:@events, { 4 => ev, 5 => other, 6 => third, 7 => egg })
    set = Object.new
    def set.event_indicator_sprites; @sprites; end
    set.instance_variable_set(:@sprites, [nil, nil, nil, nil, KIndicator.new("questmain", true), KIndicator.new("question", true),
                                          KIndicator.new("quest", false), KIndicator.new("egg", true)])
    $scene = Object.new
    $scene.define_singleton_method(:spriteset) { |_id| set }
    probe(:quest_marks) { [ev, other, third, egg].map { |e| PokeAccess::KeishouQuestMarks.mark(e) } }

    $kbag = []
    player = PokeAccess::Engine.player
    player.define_singleton_method(:get_pokemon_with_move) { |_m| :pk } if player
    moves = PokeAccess::FieldMoves
    probe(:without_item) { [moves.can?(:SURF), moves.can?(:ROCKCLIMB)] }
    $kbag = [:SURFITEM, :ROCKCLIMBITEM]
    probe(:with_item) { [moves.can?(:SURF), moves.can?(:ROCKCLIMB)] }
    probe(:clearer) { [moves.clearer(:move => :SURF), moves.item_name(:SURFITEM)] }

    ice = lambda do |name, script|
      ev = Struct.new(:name).new(name)
      ev.instance_variable_set(:@list, script ? [Struct.new(:code, :parameters).new(111, [12, script])] : [])
      ev
    end
    probe(:ice) do
      [ice.call("SmashIce", "pbIceSmash"), ice.call("SmashIce", nil), ice.call("Counter", "pbIceSmash")].map do |ev|
        [PokeAccess::Locator.ruled_name(ev), PokeAccess::Routes::Effects.gate_facet(Struct.new(:ev).new(ev))]
      end
    end

    probe(:carrier) do
      g = $PokemonGlobal
      def g.rockclimbing; true; end
      PokeAccess::Control.instance_variable_get(:@carriers).find { |c| c[0] == :rock_climb }[1].call
    end
  RUBY

  profile "keishou", WORLD, PLAY, "gamedata"

  test "the profile loads whole under its engine, every hook of it bound or optional" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
  end

  test "it stamps its name, names the RGSS letters its signs ask for, and keeps the probe's answers past an event" do
    assert_equal "keishou", played(:profile_name)
    assert_equal PokeAccess::KeyHints::RGSS_LETTERS, played(:key_letters)
    assert_equal true, played(:plain_passability)
  end

  test "it carries the readers it declares" do
    assert_equal [], played(:plugins)
  end

  test "the stats page says the IVs and EVs BW Summary Screen writes" do
    assert_equal [played(:iv_ev)], played(:stats)
    refute_nil played(:iv_ev)
  end

  test "the memo page says the egg groups, and the summary and the PC the Tera Type" do
    assert_equal [t(:sum_egg_groups, :g => "Monster")], played(:memo)
    assert_includes played(:header), t(:ss2_adv_tera, :t => played(:fire))
    assert_includes played(:pc), t(:ss2_adv_tera, :t => played(:fire))
  end

  test "the crafting bench's line ends with how many of the result the bag holds" do
    assert_includes played(:bench), t(:ura_bmart_have, :list => 3)
  end

  test "a quest marker that shows is said, and the Day Care's egg: a question mark is not, nor a hidden one" do
    assert_equal [t(:evind_quest), nil, nil, t(:evind_egg)], played(:quest_marks)
  end

  test "its field moves go by their items, whatever the party knows, and an obstacle names the item" do
    assert_equal [false, false], played(:without_item)
    assert_equal [true, true], played(:with_item)
    named, item = played(:clearer)
    assert_equal item, named
  end

  test "the ice is named and gated by its Ice Pick while it stands, and a broken one by nothing" do
    standing, broken, other = played(:ice)
    assert_equal [t(:loc_ice_block), [:loc_ice_block, nil, :ICEBARRIEREITEM]], standing
    assert_equal [nil, nil], broken
    assert_nil other[0], "an event of another name keeps its own"
  end

  test "a climb in progress is a forced move" do
    assert_equal true, played(:carrier)
  end
end
