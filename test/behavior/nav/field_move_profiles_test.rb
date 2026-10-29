# The field-move rules profiles override FieldMoves.can? with, read off each game's scripts: Realidea's switch and
# badge count, Revival's three ways to surf, the rv engine's story switches, Uranium's power cell for L and the HM
# Catalogue's pages, and the rule on surfing with company their Surf follows. Each file is loaded for its test alone,
# and what it overrode is put back.
class FieldMoveProfilesTest < PokeAccessTest
  test "realidea cuts by switch 142 and breaks rocks by two badges, with no Pokemon" do
    with_file("games", "realidea", "field_moves.rb") do
      with_party(false, 1) do
        assert_equal false, fm.can?(:CUT)
        $game_switches[142] = true
        assert_equal true, fm.can?(:CUT)
        assert_equal false, fm.can?(:ROCKSMASH)
      end
      with_party(false, 2) { assert_equal true, fm.can?(:ROCKSMASH) }
    end
  end

  test "the rv engine refuses every field move to someone else, and Surf where the story forbids it" do
    fm.instance_variable_get(:@tools).delete(:SURF)
    with_file("games", "rv_common", "field_moves_rv.rb") do
      with_party(true, 8) do
        assert_equal [true, true], [fm.can?(:CUT), fm.can?(:SURF)]
        $game_switches[:Cant_Surf] = true
        assert_equal [true, false], [fm.can?(:CUT), fm.can?(:SURF)]
        $game_switches[:NotPlayerCharacter] = true
        assert_equal false, fm.can?(:CUT)
      end
      assert_equal false, surf_with_dependent, "its Kernel.pbSurf refuses with a dependent event along"
    end
  end

  test "uranium pushes boulders as L with a power cell and no badge" do
    made = !Object.const_defined?(:BADGEFORSTRENGTH)
    Object.const_set(:BADGEFORSTRENGTH, 3) if made
    tr = PokeAccess::Engine.player
    tr.define_singleton_method(:outfit) { 1 }
    with_file("games", "uranium", "field_moves.rb") do
      with_party(false, 0) do
        with_bag([]) { assert_equal false, fm.can?(:STRENGTH) }
        with_bag([:POWERCELL]) { assert_equal true, fm.can?(:STRENGTH) }
      end
      assert_equal false, surf_with_dependent, "its Kernel.pbSurf refuses with a dependent event along"
    end
  ensure
    class << tr; remove_method :outfit; end
    Object.send(:remove_const, :BADGEFORSTRENGTH) if made
  end

  test "revival surfs with any one of the Surf badge, a Pokemon that knows Surf and the Lapras whistle" do
    items = Hash[fm.instance_variable_get(:@items).map { |k, v| [k, v.dup] }]
    badge = fm.method(:badge_ok?)
    cases = [[false, false, [], false], [true, false, [], true], [false, true, [], true],
             [false, false, [:SILBATOLAPRAS], true]]
    with_file("games", "revival", "field_moves.rb") do
      cases.each do |won, knows, bag, want|
        fm.define_singleton_method(:badge_ok?) { |_m| won }
        with_party(knows, 0) do
          with_bag(bag) { assert_equal want, fm.can?(:SURF), "badge #{won}, knows #{knows}, bag #{bag.inspect}" }
        end
      end
    end
  ensure
    fm.define_singleton_method(:badge_ok?, badge) if badge
    fm.instance_variable_set(:@items, items) if items
  end

  test "reminiscencia refuses to surf with a dependent event along, as its Kernel.pbSurf does" do
    with_file("games", "reminiscencia", "field_moves.rb") { assert_equal false, surf_with_dependent }
  end

  test "the hm catalogue rules the field moves by its pages alone" do
    catalogue = Class.new { class << self; attr_accessor :surf, :cut; end }
    Object.const_set(:HM_Catalogue, catalogue)
    begin
      with_file("plugins", "hm_catalogue.rb") do
        with_party(true, 8) do
          assert_equal [false, false], [fm.can?(:SURF), fm.can?(:CUT)]
          catalogue.surf = true
          assert_equal [true, false], [fm.can?(:SURF), fm.can?(:CUT)]
          assert_equal true, fm.can?(:FLASH)
        end
        assert_equal true, surf_with_dependent(true), "its pbSurf asks nothing of who walks along"
      end
    ensure
      Object.send(:remove_const, :HM_Catalogue)
    end
  end

  private

  def fm; PokeAccess::FieldMoves; end

  # Loads a profile or plugin file for the block, with no rule on surfing with company but the one it declares, then
  # puts back the FieldMoves methods it overrode, the profiles it defined and the rule on company.
  def with_file(*parts)
    keep = [:can?, :clear?, :clearer, :name].map { |m| [m, fm.method(m)] }
    profiles = PokeAccess::Game.profiles.dup
    company = PokeAccess::Pathfinder.instance_variable_get(:@surf_company)
    PokeAccess::Pathfinder.instance_variable_set(:@surf_company, nil)
    load File.join(Harness::ROOT, *parts)
    yield
  ensure
    keep.each { |m, meth| fm.define_singleton_method(m, meth) }
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@surf_company, company)
  end

  # What Pathfinder.surf_with_company? answers with a dependent event walking along (pbHasDependentEvents?), for a
  # player that has, with v20, the check of that version too (can_ride_vehicle_with_follower?), refusing.
  def surf_with_dependent(v20 = false)
    was = $game_player
    $game_player = Object.new
    $game_player.define_singleton_method(:pbHasDependentEvents?) { true }
    $game_player.define_singleton_method(:can_ride_vehicle_with_follower?) { false } if v20
    PokeAccess::Pathfinder.surf_with_company?
  ensure
    $game_player = was
  end

  # Runs the block with a party that knows every field move or none and this many badges won.
  def with_party(knows, badges)
    keep = fm.method(:knows?)
    was = $Trainer.badges
    fm.define_singleton_method(:knows?) { |_m| knows }
    $Trainer.badges = [true] * badges + [false] * (8 - badges)
    yield
  ensure
    fm.define_singleton_method(:knows?, keep)
    $Trainer.badges = was
  end

  # Runs the block with a bag holding just these items.
  def with_bag(items)
    was = $PokemonBag
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |it| items.include?(it) ? 1 : 0 }
    yield
  ensure
    $PokemonBag = was
  end
end
