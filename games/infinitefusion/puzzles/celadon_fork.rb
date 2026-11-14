# Choosing a passage still uses the original Yes/No interaction and Erika's authored movement.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 449, :part => :celadon_fork) do
    auto
    spot :event => 9, :label => :if_sewers_right_passage, :onto => true,
         :when => lambda { PokeAccess::InfiniteFusionSewersFork.pending?(9) }
    spot :event => 11, :label => :if_sewers_left_passage, :onto => true,
         :when => lambda { PokeAccess::InfiniteFusionSewersFork.pending?(11) }
  end
end
