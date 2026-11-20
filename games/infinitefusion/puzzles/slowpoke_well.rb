# Slowpoke Well (map 340): four Shellders plug the drain (events 5, 9, 11, 12). The four Slowpoke (graphic 079s, named
# StrengthBoulder like the rocks) are pushed into the hole: the first to (17,14), the rest to (16,14) where the first
# Shellder sat. Each one that lands frees the next Shellder and adds one to var 158; at 4 the well drains.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 340) do
    auto
    name(/\A079s/, :if_jo_slowpoke)
    name [5, 9, 11, 12], :if_jo_shellder
    count :if_jo_shellders, :var => 158, :of => 4
    arrival_hint :if_jo_slowpoke_rule
    spot :at => [17, 14], :label => :if_jo_slowpoke_goal, :assist => true, :when => lambda { $game_variables[158].to_i == 0 }
    spot :at => [16, 14], :label => :if_jo_slowpoke_goal, :assist => true, :when => lambda { $game_variables[158].to_i > 0 }
  end
end
