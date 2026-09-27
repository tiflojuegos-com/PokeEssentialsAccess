# Realidea's copy of the BW Hall of Fame lost the back key on the PC viewer's record list, which only a click on its
# cancel button leaves: back stands for that click while the viewer's selection loop runs with no record picked.
module PokeAccess
  module ReaHallOfFame
    @pc = nil

    def self.watch(scene); @pc = scene; end
    def self.unwatch; @pc = nil; end

    # True when the viewer asks whether its cancel button was clicked, on a frame back was pressed with no record
    # picked.
    def self.cancel?(obj)
      scene = @pc
      return false unless scene && obj && !PokeAccess.ivar(scene, :@selectedrecord)
      obj.equal?(PokeAccess.sprite(scene, "cancelbuttom")) && Input.trigger?(Input::B) ? true : false
    rescue StandardError
      false
    end
  end
end

PokeAccess::Game.define("realidea") do
  around("HallOfFameScene", :pbPCSelection, :optional => true) do |s, nxt, _a|
    PokeAccess::ReaHallOfFame.watch(s)
    begin
      nxt.call
    ensure
      PokeAccess::ReaHallOfFame.unwatch
    end
  end
  around("Game_Mouse", :leftClick?, :optional => true) do |_m, nxt, args|
    PokeAccess::ReaHallOfFame.cancel?(args[0]) || nxt.call
  end
end
