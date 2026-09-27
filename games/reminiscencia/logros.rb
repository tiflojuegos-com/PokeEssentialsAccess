module PokeAccess
  # Reminiscencia's achievements screen paints, beside every achievement, the two EV limits the achievements raise
  # (showTexts, its last drawTextEx); said once per visit, after the first achievement the screen reads.
  module ReminLogros
    @pending = nil

    # Keeps the limits showTexts painted, split at its line break, the first time this screen paints them.
    # param pairs the rows showTexts painted (PaintCapture.sample)
    def self.note(scene, pairs)
      return if PokeAccess.ivar(scene, :@access_ev_noted)
      row = (pairs || []).select { |r| r[1] == :dtex }.last
      return unless row
      text = row[0].to_s.split(/\r?\n/).map { |l| PokeAccess.clean(l) }.reject { |l| l.empty? }.join(". ")
      return if text.empty?
      scene.instance_variable_set(:@access_ev_noted, true)
      @pending = text
    end

    # Once per frame, after the achievements reader: says the kept limits, queued behind its line.
    def self.flush
      return unless @pending
      t = @pending
      @pending = nil
      PokeAccess.speak(t, false)
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  around("Logros_Scene", :showTexts, :optional => true) do |scene, nxt, _a|
    ret = nil
    pairs = PokeAccess::PaintCapture.sample { ret = nxt.call }
    PokeAccess::ReminLogros.note(scene, pairs)
    ret
  end
  poll_each_frame { PokeAccess::ReminLogros.flush }
end
