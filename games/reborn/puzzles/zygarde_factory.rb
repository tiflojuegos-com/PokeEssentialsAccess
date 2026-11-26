# The Twilight Factory (map 846): machines with no graphic. The cell counter 82 at (55,38) raises a shutter per ten
# Zygarde cells (variable 590, shutters on 695); the assembler 8 at (22,23) builds a Zygarde from ten active cells
# (variable 591), the disassembler 19 at (21,23) turns one back. The core reads the tile puzzle of 101 at (34,7).
PokeAccess::Game.define("reborn") do
  mechanic(:state, 846, :part => :machines) do
    auto
    name 82, :rbe_tf_counter
    name 8, :rbe_tf_assembler
    name 19, :rbe_tf_disassembler
  end
end
