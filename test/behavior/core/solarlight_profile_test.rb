# The Pokemon Solar Light & Lunar Dark profile loaded whole, over doubles with the shape of its scripts: the Neo pause
# menu's entries, its Safari box and its return from a screen; the Easy Badge Case's opening; Strength by the badge
# alone; its passability. In a process of its own, since its overrides would reach every other test here.
class SolarlightProfileTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil

    # The following Pokemon's switch, as 0216_Following Pokemon.rb names it.
    Following_Activated_Switch = 627

    # The moves the party knows and the badges the game's own check passes, as the game asks for them.
    $party_moves = []
    $badge_ok = false
    BADGEFORSTRENGTH = 3
    def pbCheckMove(move); $party_moves.include?(move) ? :a_pokemon : nil; end
    def pbCheckHiddenMoveBadge(_badge = -1, _showmsg = true); $badge_ok; end
    Object.send(:public, :pbCheckMove, :pbCheckHiddenMoveBadge)

    # Neo PauseMenu's entry table (0226_ModularMenu.rb): the names its refresh leaves, the player's own for the card.
    module MenuHandlers
      NAMES = { :POKEDEX => "Pokédex", :POKEMON => "Pokémon", :BAG => "Bag", :TRAINER => "Red", :SAVE => "Save" }
      def self.getName(ref); NAMES[ref]; end
    end

    # The pause menu's scene: the opening paints the Safari box (@box, rows as pbDrawTextPositions takes them), then
    # refreshes and updates, as the game's pbStartScene does.
    class PokemonPauseMenu_Scene
      attr_accessor :index, :entries

      def initialize(index, box = [])
        @index = index
        @box = box
      end

      def pbStartScene
        pbDrawTextPositions(nil, @box)
        refresh
        update
      end

      def refresh; @entries = [:POKEDEX, :POKEMON, :BAG, :TRAINER, :SAVE]; end
      def update; :frame; end
      def pbEndScene; :closed; end
    end

    # The badge case (0145_Easy Badge Case.rb): its opening draws the front and fades in.
    class PokemonBadgecase_Scene
      def pbStartScene; pbDrawBadgecaseFront; end
      def pbDrawBadgecaseFront; :drawn; end
      def pbEndScene; :closed; end
    end
  RUBY

  PLAY = <<-'RUBY'
    # The badge names the Fancy Badges ceremony paints, by index.
    def with_badge_names
      Object.const_set(:FANCY_BADGE_NAMES, ["Thorn Badge", "Darkness Badge", "Lightning Badge"])
      yield
    ensure
      Object.send(:remove_const, :FANCY_BADGE_NAMES)
    end

    # The badge case's opening line with the player holding these badges, and what the info key keeps.
    def badge_case(held)
      $Trainer.badges = held
      [said { PokemonBadgecase_Scene.new.pbStartScene }, PokeAccess::Info.info_text]
    end

    # Whether the party can use Strength with this badge state and this bag.
    def strength(badge, bag)
      $badge_ok = badge
      was = $PokemonBag
      $PokemonBag = Object.new
      $PokemonBag.define_singleton_method(:pbQuantity) { |it| bag.include?(it) ? 1 : 0 }
      $PokemonBag.define_singleton_method(:pbHasItem?) { |it| bag.include?(it) }
      PokeAccess::FieldMoves.can?(:STRENGTH)
    ensure
      $PokemonBag = was
      $badge_ok = false
    end

    probe(:profile_name) { PokeAccess::Game.profile_name }
    probe(:plain_passability) { PokeAccess::World::Probe.plain? }
    probe(:pause_box) do
      scene = PokemonPauseMenu_Scene.new(2, [["Steps: 120/600", 16, 60, 0, nil, nil], ["Balls: 30", 16, 110, 0, nil, nil]])
      said { scene.pbStartScene; scene.update; scene.update }
    end
    probe(:pause_moves) do
      $Trainer.define_singleton_method(:name) { "Red" }
      scene = PokemonPauseMenu_Scene.new(0)
      scene.pbStartScene
      said { scene.update; scene.index = 3; scene.update }
    end
    probe(:pause_return) do
      scene = PokemonPauseMenu_Scene.new(1)
      scene.pbStartScene
      scene.update
      [said { scene.update }, said { PokeAccess::MenuReturn.enter!; PokeAccess::MenuReturn.leave!; scene.update }]
    end
    probe(:pause_closed) do
      scene = PokemonPauseMenu_Scene.new(1)
      scene.pbStartScene
      scene.update
      scene.pbEndScene
      said { PokeAccess::MenuReturn.enter!; PokeAccess::MenuReturn.leave!; scene.update }
    end
    probe(:badges_named) { with_badge_names { badge_case([true, false, true]) } }
    probe(:badges_counted) { badge_case([true, true]) }
    probe(:badges_none) { badge_case([]) }
    probe(:strength) { [strength(true, []), strength(false, [:STRENGTHGLOVES]), strength(false, [])] }
    probe(:field_items) do
      items = PokeAccess::FieldMoves.instance_variable_get(:@items)
      [:CUT, :ROCKSMASH, :STRENGTH, :SURF, :DIVE, :WATERFALL, :FLASH, :FLY].map { |m| [m.to_s, (items[m] || []).map { |i| i.to_s }] }
    end
    probe(:surf_company) do
      kind, lets = PokeAccess::Pathfinder.instance_variable_get(:@surf_company)
      Object.const_set(:Following_Activated_Switch, 77) unless defined?(Following_Activated_Switch)
      $game_switches[Following_Activated_Switch] = true
      on = lets.call
      $game_switches[Following_Activated_Switch] = false
      [kind.to_s, on, lets.call]
    end
    probe(:waytide) do
      maps = [288, 289, 290, 291, 293, 294, 295]
      defs = PokeAccess::World::Mechanics.instance_variable_get(:@defs)
      maps.map do |m|
        spec = defs[m] && defs[m][0] && defs[m][0][1]
        spec ? [spec[:avoids].to_a.map { |a| a.keys }.flatten, spec[:arrival_hint].to_s, spec[:arrival_once]] : nil
      end
    end
  RUBY

  profile "solarlight", WORLD, PLAY

  test "loads whole, with every plugin it declares, and binds what it declares" do
    assert_equal [[], []], [played(:load_errors), played(:missing_hooks)]
    assert_equal "solarlight", played(:profile_name)
  end

  test "its passability reads nothing an event sets" do
    assert_equal true, played(:plain_passability)
  end

  test "the pause menu says the Safari box it paints, then the focused entry with its place once, both queued" do
    assert_equal [["Steps: 120/600, Balls: 30", false], ["Bag, 3 de 5", false]], played(:pause_box)
  end

  test "a move along the pause menu says the new entry, the trainer card's by the player's name and the card" do
    assert_equal [["Pokédex, 1 de 5", false], ["Red, #{t(:tc_title)}, 4 de 5", true]], played(:pause_moves)
  end

  test "back from a screen an entry opened the focused entry is said again, and not before" do
    assert_equal [[], [["Pokémon, 2 de 5", false]]], played(:pause_return)
  end

  test "once the pause menu closes a return says nothing" do
    assert_equal [], played(:pause_closed)
  end

  test "the badge case says the badges held by the names the game gives them, kept for the info key" do
    line = "#{t(:badgecase_title)}. #{t(:tcard_badge_list, :list => 'Thorn Badge, Lightning Badge')}"
    assert_equal [[[line, false]], line], played(:badges_named)
  end

  test "with no badge names the badge case says how many are held, none included" do
    assert_equal "#{t(:badgecase_title)}. #{t(:tr_badges, :n => 2)}", played(:badges_counted)[1]
    assert_equal "#{t(:badgecase_title)}. #{t(:tr_badges, :n => 0)}", played(:badges_none)[1]
  end

  test "Strength takes the badge alone or the gloves, and neither is not enough" do
    assert_equal [true, true, false], played(:strength)
  end

  test "each field move takes the tool the game gives for it" do
    assert_equal [["CUT", ["CLIPPERS"]], ["ROCKSMASH", ["HAMMER"]], ["STRENGTH", ["STRENGTHGLOVES"]], ["SURF", ["SURFBOARD"]],
                  ["DIVE", ["SNORKLE"]], ["WATERFALL", ["BOARDMOTOR"]], ["FLASH", ["FLASHLIGHT"]], ["FLY", ["SERVICEWHISTLE"]]],
                 played(:field_items)
  end

  test "surfing lets the following Pokemon along, by the game's switch, and no other dependent" do
    assert_equal ["dependents", true, false], played(:surf_company)
  end

  test "Waytide's floor switch is kept off the walks, its rule said on the first arrival alone, on its seven maps" do
    assert_equal [[[1], "solar_waytide_rule", true]] * 7, played(:waytide)
  end
end
