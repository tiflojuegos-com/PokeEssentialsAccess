module PokeAccess
  module Util
    # Groups indices 0...n with union-find, joining i and j when the block says they belong together; returns
    # the groups as Arrays of indices. O(n^2) merge tests, fine for the small sets it serves.
    def self.union_groups(n)
      return [] if n <= 0
      parent = (0...n).to_a
      root = lambda do |i|
        while parent[i] != i; parent[i] = parent[parent[i]]; i = parent[i]; end
        i
      end
      (0...n).each do |i|
        ((i + 1)...n).each { |j| parent[root.call(i)] = root.call(j) if yield(i, j) }
      end
      groups = {}
      (0...n).each { |i| (groups[root.call(i)] ||= []).push(i) }
      groups.values
    end
  end
end
