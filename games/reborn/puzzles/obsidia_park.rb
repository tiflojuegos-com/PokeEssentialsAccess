# Obsidia Park (map 269): a maze of trees cut in a fixed order, each setting variable 642 to where its cut leaves the
# vines (events 12, 11, 10, 7, 8, 17 and 4, the opening scene first raising it to 4); the next is the only tree in
# reach. With the assist, it is listed.
module PokeAccess
  module RebornObsidiaPark
    TREES = [[12, 8], [11, 12], [10, 17], [7, 20], [8, 24], [17, 29], [4, 34]]

    # The park's progress, variable 642.
    def self.value; $game_variables[642].to_i; end

    # The tree to cut next, by the value its cut leaves; nil once all are cut.
    def self.next_tree
      tree = TREES.find { |_id, done| value < done }
      tree && tree[0]
    end
  end
end

PokeAccess::Game.define("reborn") do
  park = PokeAccess::RebornObsidiaPark
  mechanic(:state, 269) do
    auto
    name park::TREES.map { |id, _done| id }, lambda { |ev| park.next_tree == ev.id ? :rba_cm_next_tree : nil },
         :assist => true
    hint :rba_cm_hint
    active { !park.next_tree.nil? }
    solved { park.next_tree.nil? }
  end
end
