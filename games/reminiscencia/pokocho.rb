module PokeAccess
  # Reminiscencia's Pokocho maker (class Poffin, stirred with the mouse): its START picture as the countdown ends and
  # its DONE picture as it shows, the warnings it flashes as the pot burns or overflows (drawTextAnnouncement), and
  # the results table showResult repaints every frame until confirmed, said once row by row.
  module ReminPokocho
    # Says a results table when it differs from the last one said for this maker.
    # param pairs the rows showResult painted (PaintCapture.sample)
    def self.results(scene, pairs)
      t = PokeAccess::PaintCapture.lines(pairs).join(". ")
      PokeAccess.speak(t, false) if !t.empty? && PokeAccess::Cursor.changed?(scene, :rem_pokocho, t)
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  after("Poffin", :announceStart, :optional => true) do |_s, _r, _a|
    PokeAccess.speak(PokeAccess::I18n.t(:rem_pokocho_start), true)
  end
  before("Poffin", :announceFinish, :optional => true) do |_s, _a|
    PokeAccess.speak(PokeAccess::I18n.t(:rem_pokocho_done), true)
  end
  around("Poffin", :drawTextAnnouncement, :optional => true) do |_s, nxt, _a|
    PokeAccess::PaintCapture.speak_around(:rem_pokocho_warn, true) { nxt.call }
  end
  around("Poffin", :showResult, :optional => true) do |scene, nxt, _a|
    ret = nil
    pairs = PokeAccess::PaintCapture.sample { ret = nxt.call }
    PokeAccess::ReminPokocho.results(scene, pairs)
    ret
  end
end
