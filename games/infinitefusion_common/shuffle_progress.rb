# The randomizer's progress bar (ShuffleProgressBar), which paints what it is shuffling and a percentage while the
# game blocks: both as it opens, then the percentage it paints on reaching each quarter, queued.
module PokeAccess
  module IFShuffleProgress
    # Speaks a repaint of the bar's text when it reaches a quarter it had not reached yet.
    # param rows what the repaint painted: the bar's text, then its percentage
    def self.drawn(bar, progress, rows)
      quarter = (progress.to_f * 4).floor
      last = PokeAccess.ivar(bar, :@access_quarter)
      return if last && quarter <= last
      bar.instance_variable_set(:@access_quarter, quarter)
      said = last ? rows[1, 1] : rows
      PokeAccess.speak(PokeAccess.sentences(said || []), false)
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  around("ShuffleProgressBar", :drawProgressText, :optional => true) do |bar, nxt, args|
    PokeAccess::PaintCapture.arm(:if_shuffle)
    begin
      nxt.call
    ensure
      rows = (PokeAccess::PaintCapture.take(:if_shuffle) || []).map { |r| PokeAccess.clean(r.to_s) }
      PokeAccess::IFShuffleProgress.drawn(bar, args[0], rows)
    end
  end
end
