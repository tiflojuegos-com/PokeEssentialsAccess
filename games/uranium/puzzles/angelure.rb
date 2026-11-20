# Angelure after the story. The resort's dance floor (map 224): the console (event 8) starts a sequence on four pads, the
# same $Simon game as the Virtual Dimension's, played by events 3 to 6 (colours 0 to 3) laid out two by two. The theatre's
# pirate (map 273, event 30) asks for a password a script compares with three words, so the core cannot tell which one
# is the answer.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 224, :part => :dance) do
    auto
    name 3, :ura_rp_pad_bottom_left
    name 4, :ura_rp_pad_top_left
    name 5, :ura_rp_pad_top_right
    name 6, :ura_rp_pad_bottom_right
    name 8, :ura_rp_dance_console
    (3..6).each do |id|
      spot :event => id, :label => :ura_po_simon_next, :assist => true,
           :when => lambda { PokeAccess::UraniumSimon.next_tile == id }
    end
  end

  mechanic(:state, 273) do
    auto
    answer 30, "saga"
  end
end
