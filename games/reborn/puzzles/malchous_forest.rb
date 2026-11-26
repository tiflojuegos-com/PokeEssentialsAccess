# Malchous Forest Park (map 132): the vines on the way to Jasper's old gym draw back as three trees are cut in order,
# each setting variable 654 (events 63, 72 and 56); event 57 is a side way of its own (variable 653). With the assist,
# the next tree is listed.
module PokeAccess
  module RebornMalchous
    TREES = [[63, 4], [72, 8], [56, 14]]

    # The vines' stage, variable 654.
    def self.value; $game_variables[654].to_i; end

    # The tree to cut next, by the value its cut leaves; nil once all are cut.
    def self.next_tree
      tree = TREES.find { |_id, done| value < done }
      tree && tree[0]
    end
  end
end

PokeAccess::Game.define("reborn") do
  forest = PokeAccess::RebornMalchous
  mechanic(:state, 132) do
    auto
    name forest::TREES.map { |id, _done| id }, lambda { |ev| forest.next_tree == ev.id ? :rba_cm_next_tree : nil },
         :assist => true
    hint :rba_cm_hint
    active { !forest.next_tree.nil? }
    solved { forest.next_tree.nil? }
  end
end
