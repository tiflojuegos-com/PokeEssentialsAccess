# World Frontier's credits (Creditos, CreditosWF::Scene), which replace the stock roll with creditos.txt scrolling
# between walking trainers: read whole and queued once the text is built, as the core reads the stock roll. C or X
# pauses the scroll to ask whether to leave: the reading stops so the question is heard at once, and declining reads
# on from the first line still on screen, where the scroll resumes; it stops when the roll ends or is left.
module PokeAccess
  module WfCredits
    # The lines the roll has still to show: the scrolling ones from the first still on screen, then the closing ones,
    # without their heading marks.
    def self.raw_lines(scene)
      lines = PokeAccess.ivar(scene, :@lines) || []
      rest = lines[first_on_screen(scene, lines)..-1] || []
      (rest + (PokeAccess.ivar(scene, :@closing_lines) || [])).map { |l| l.to_s.sub(/\A<[th]>/, "") }
    end

    # The first scrolling line whose bottom is still below the top of the screen, from where the text sprite sits and
    # each line's height as the scene lays them out; 0 before the scroll starts or when either is unknown.
    def self.first_on_screen(scene, lines)
      y = (PokeAccess.ivar(scene, :@text).y rescue nil)
      return 0 unless y.is_a?(Numeric)
      lines.each_with_index do |l, i|
        h = (scene.line_spec(l.to_s)[:h] rescue nil)
        return 0 unless h.is_a?(Numeric)
        y += h
        return i if y > 0
      end
      lines.length
    end

    # The question to leave opens: the roll being read stops, so it is heard at once.
    def self.pause
      PokeAccess::Credits.finish
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # The player stays: the roll is read on from where the scroll resumes.
    def self.resume(scene)
      PokeAccess::Credits.arm
      PokeAccess::Credits.roll(scene)
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  override("PokeAccess::Credits", :raw_lines) do |_mod, original, args|
    scene = args[0]
    if defined?(::CreditosWF::Scene) && scene.is_a?(::CreditosWF::Scene)
      PokeAccess::WfCredits.raw_lines(scene)
    else
      original.call
    end
  end
  after("CreditosWF::Scene", :build_text) do |scene, _r, _a|
    PokeAccess::Credits.arm
    PokeAccess::Credits.roll(scene)
  end
  around("CreditosWF::Scene", :ask_to_leave) do |scene, nxt, _a|
    PokeAccess::WfCredits.pause
    leave = nxt.call
    PokeAccess::WfCredits.resume(scene) unless leave
    leave
  end
  # A container: the roll's frames, and the question to leave, run inside it.
  after("CreditosWF::Scene", :run, :hook_container => true) { |_scene, _r, _a| PokeAccess::Credits.finish }
end
