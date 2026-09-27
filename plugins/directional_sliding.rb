module PokeAccess
  # Directional Sliding (Soulstones 2): terrain flags slide the player on while they can move that way over sliding
  # ground or ice; a sliding tile met on the way starts its own slide, then the first goes on, 94 chained at most.
  module DirectionalSliding
    FLAGS = [[:slide_up, 8], [:slide_right, 6], [:slide_down, 2], [:slide_left, 4]]
    CHAIN_CAP = 94

    # The direction the terrain at (x,y) slides the player, or nil.
    def self.dir_at(x, y)
      t = PokeAccess::Terrain.raw(x, y)
      FLAGS.each { |flag, d| return d if PokeAccess::Terrain.flag?(t, flag) }
      nil
    end

    # True if (x,y) keeps a slide going: sliding ground or ice.
    def self.sliding_ground?(x, y)
      !dir_at(x, y).nil? || PokeAccess::Terrain.ice_at?(x, y)
    end

    # Where a slide from (x,y) in direction d stops, as [x, y], or false when it would not stop.
    # param chain [slides started so far], shared by the slides a slide sets off
    def self.slide(x, y, d, chain = [0])
      pf = PokeAccess::Pathfinder
      dd = PokeAccess::DIR_DELTA[d]
      steps = 0
      loop do
        break unless pf.passable_at?(x, y, d)
        break unless sliding_ground?(x, y)
        steps += 1
        return false if steps > pf::ARRIVAL_CAP
        x += dd[0]; y += dd[1]
        nd = dir_at(x, y)
        next if nd.nil? || chain[0] >= CHAIN_CAP
        chain[0] += 1
        r = slide(x, y, nd, chain)
        return false unless r
        x, y = r
      end
      [x, y]
    end
  end
end

PokeAccess::Pathfinder.arrival_rule do |x, y, _d|
  nd = PokeAccess::DirectionalSliding.dir_at(x, y)
  nd ? PokeAccess::DirectionalSliding.slide(x, y, nd) : nil
end
