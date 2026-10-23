# A push a search imagines sets the characters that walk behind the player aside (Following Pokemon EX's follower
# refuses a pushed boulder its tile), and puts them back where they stood; a push asked of the map as it stands keeps
# them in the way.

class ProbeFollowersTest < PokeAccessTest
  test "sets a follower aside while it asks a push a search imagines" do
    with_follower(3, 5) do |pet|
      assert_equal true, PokeAccess::World::Probe.event_movable?(boulder(pet), 3, 4, 2, [3, 4, 3, 3])
      assert_equal [3, 5], [pet.x, pet.y]
    end
  end

  test "keeps a follower in the way of a push asked as the map stands" do
    with_follower(3, 5) do |pet|
      assert_equal false, PokeAccess::World::Probe.event_movable?(boulder(pet), 3, 4, 2)
    end
  end

  private

  class Pet
    attr_accessor :x, :y
    def initialize(x, y); @x = x; @y = y; end
  end

  class Factory
    def initialize(pet); @pet = pet; end
    def each_follower; yield @pet, :follower; end
  end

  def with_follower(x, y)
    pet = Pet.new(x, y)
    fac = Factory.new(pet)
    $game_temp.define_singleton_method(:followers) { fac }
    yield pet
  ensure
    class << $game_temp; remove_method :followers; end
  end

  def boulder(pet)
    ev = Object.new
    ev.instance_variable_set(:@pet, pet)
    def ev.x; @x || 3; end
    def ev.y; @y || 4; end
    def ev.through; false; end
    def ev.through=(_v); end
    def ev.passable?(x, y, d)
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0))
      ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      !(@pet.x == nx && @pet.y == ny)
    end
    ev
  end
end
