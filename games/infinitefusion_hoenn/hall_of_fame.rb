# Hoenn's end-of-part Hall of Fame (HallOfFameSimple_Scene), a subclass that paints its own welcome and completion
# box, so the core reader is bound to it too; between the two it paints a line with the date and game mode
# (writeInfo), said queued as painted.
PokeAccess::Game.define("infinitefusion_hoenn") do
  hall_of_fame("HallOfFameSimple_Scene")
  around("HallOfFameSimple_Scene", :writeInfo, :optional => true) do |_s, nxt, _a|
    PokeAccess::PaintCapture.speak_around(:if2_hof_info, false) { nxt.call }
  end
end
