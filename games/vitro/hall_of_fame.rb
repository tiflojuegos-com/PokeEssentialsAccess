# Vitro's entry to the Hall of Fame is JessWishes' (SalonDeFama.registrar, 0279_Hall de la Fama), in its HGSS style: an animation
# that takes no key, with each text in a window of its own, written as it is about to show: the heading, each member with its
# sex sign, level, trainer and where it was found, and at the end the congratulations and the trainer. Each is said as written,
# queued, while the ceremony runs. Its record in the PC is the stock screen's.
module PokeAccess
  module VitroHallOfFame
    @open = false

    # Runs the ceremony, its windows' texts being said.
    def self.watching
      @open = true
      @last = nil
      yield
    ensure
      @open = false
    end

    # Says a text a window is given while the ceremony runs, once: a window sets its text again as it is resized. Each of
    # its centred blocks is a line of its own.
    def self.written(text)
      return unless @open
      line = PokeAccess.clean(text.to_s.gsub(/<\/ac>/i, " "))
      return if line.empty? || line == @last
      @last = line
      PokeAccess.speak(line, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  around("Jess_SalonFama", :jsGen4_HGSS, :optional => true) do |_scene, nxt, _a|
    PokeAccess::VitroHallOfFame.watching { nxt.call }
  end
  after("Window_AdvancedTextPokemon", :text=, :optional => true) do |_window, _r, args|
    PokeAccess::VitroHallOfFame.written(args[0])
  end
end
