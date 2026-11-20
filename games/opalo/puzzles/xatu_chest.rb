# Opalo's chest of the Ruinas Secretas (map 366): its Xatu gives three riddles in turn (switches 679, 681 and 683), each
# answered at a spot with no graphic that paints two digits of the code (switches 680, 682 and 684): a haystack of Pueblo
# Kona (map 310), the pulpit of the Capilla de la Luz (map 278) and a big "T" of Ciudad Mistral (map 328). With the assist,
# the spot of the riddle open is listed. The digits are said by painted_pictures.rb, and the code by the core at the chest.
PokeAccess::Game.define("opalo") do
  [[310, [19, 4], 679, 680], [278, [16, 8], 681, 682], [328, [49, 5], 683, 684]].each do |map, at, asked, seen|
    mechanic(:state, map, :part => :xatu) do
      auto
      spot :at => at, :label => :op_xatu_clue, :assist => true,
           :when => lambda { $game_switches[asked] && !$game_switches[seen] }
    end
  end
end
