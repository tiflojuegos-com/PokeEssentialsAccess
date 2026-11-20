# Tests that hold for the rest of a visit once true, so a phase tied to a box of tiles opens, and says its rule, once
# per visit rather than on each return to the box. A visit is the list of the map's mechanic instances, built anew on
# each arrival; while it is being built the test is asked as it stands.
module PokeAccess
  module UraniumVisit
    def self.since(key)
      visit = PokeAccess::World::Mechanics.built_instances
      return (yield ? true : false) unless visit
      @seen ||= {}
      @seen[key] = [visit, false] unless @seen[key] && @seen[key][0].equal?(visit)
      @seen[key][1] = true if !@seen[key][1] && yield
      @seen[key][1]
    end
  end
end
