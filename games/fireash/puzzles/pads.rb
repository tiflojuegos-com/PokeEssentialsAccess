# Fire Ash's gyms of pads, ladders and doors name each one the same way: told apart, with the assist alone, when it
# is on a shortest way to the leader; the list may be a callable, for a way that changes with the game's state.
module PokeAccess
  module FireAshPads
    # A name lambda: the close label with the assist for the events in towards, the plain one for the rest.
    def self.namer(towards, plain, close)
      lambda do |ev|
        list = towards.respond_to?(:call) ? towards.call : towards
        PokeAccess::Puzzles.assist? && list.include?(ev.id) ? close : plain
      end
    end
  end
end
