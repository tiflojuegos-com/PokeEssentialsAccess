# Awakening's continue panel: its own painted lines are read by the core, with the save's map (painted at the
# end of the route's row) as a line of its own; the finished endings, four icons with no word, are said here.
module PokeAccess
  module AwakeningLoad
    ENDINGS = [[2, :awk_end_order], [1, :awk_end_chaos], [3, :awk_end_neutral]]

    # Where the map's name is painted (188*2, right-aligned); every other cell of the panel stands left of it.
    PLACE_X = 300

    # The completed endings (three by checkNewGamePlus, the true one by Data/realfin.dat), or nil when none;
    # check and exist can be stubbed by a spec.
    def self.endings(check = nil, exist = nil)
      check ||= lambda { |n| (checkNewGamePlus(n) rescue false) }
      exist ||= lambda { |p| File.exist?(p) }
      done = ENDINGS.select { |n, _key| check.call(n) }.map { |_n, key| PokeAccess::I18n.t(key) }
      done.push(PokeAccess::I18n.t(:awk_end_true)) if exist.call("Data/realfin.dat")
      done.empty? ? nil : PokeAccess::I18n.t(:awk_endings, :list => done.join(", "))
    end

    # The panel's lines with the map's name off the route's row, after it.
    def self.lines(pairs)
      place = pairs.select { |p| p[2].to_i >= PLACE_X }
      PokeAccess::PaintCapture.lines(pairs - place) + place.map { |p| PokeAccess.clean(p[0].to_s) }.reject { |t| t.empty? }
    end
  end
end

PokeAccess::Game.define("awakening") do
  override(PokeAccess::LoadPanel, :extras) { |_mod, _original, _args| [PokeAccess::AwakeningLoad.endings] }
  override(PokeAccess::LoadPanel, :lines_of) { |_mod, _original, args| PokeAccess::AwakeningLoad.lines(args[0]) }
end
