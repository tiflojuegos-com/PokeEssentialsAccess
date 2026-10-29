# The BW Summary Screen's pictures on the stats page, drawn by pbDisplayIVRating and pbDisplayEVRating (which the Level
# Based Mixed EV System redraws in the same rows): a letter grade per stat for its IVs and, where the page draws them,
# a bar of six steps per stat for its EVs, orange once the EV total is at its limit. What each draw painted is kept for
# the Pokemon on the page and said after its stats.
module PokeAccess
  module BWSummary
    # The stats in the page's rows, top to bottom.
    STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
    # A grade picture and its letter; an EV bar picture, its step (01 a sliver under the first) and its limit colour.
    GRADE = /Rating([SABCDF])\z/
    BAR = /EVbar(\d+)(_max)?\z/

    # Keeps what a draw of kind (:iv or :ev) painted, for the Pokemon on the scene's page; the grades open every draw
    # of the page, so they drop the bars a draw before kept.
    def self.note(scene, kind, rows)
      @drawn = {} if kind == :iv || @drawn.nil?
      @drawn[kind] = [PokeAccess.ivar(scene, :@pokemon), rows]
    end

    # The rows the last draw of kind painted for pk, taken once; nil for another Pokemon's or none.
    def self.take(kind, pk)
      d = (@drawn || {}).delete(kind)
      (d && d[0].equal?(pk)) ? d[1] : nil
    end

    # The pictures matching re, one per stat row (top to bottom), as [stat, match]; nil unless there is one per stat.
    def self.by_stat(rows, re)
      hits = (rows || []).select { |r| r[0].to_s =~ re && r[2].is_a?(Numeric) }.sort_by { |r| r[2] }
      return nil unless hits.length == STATS.length
      (0...STATS.length).map { |i| [STATS[i], hits[i][0].to_s.match(re)] }
    end

    # The IV grades as one sentence, each stat with its letter; nil without one grade per stat.
    def self.grades(rows)
      cells = by_stat(rows, GRADE)
      return nil unless cells
      list = cells.map { |stat, m| "#{PokeAccess::Data.stat_name(stat)} #{m[1]}" }
      PokeAccess::I18n.t(:mui_iv_ratings, :list => list.join(", "))
    end

    # The EV bars as one sentence, each stat's filled steps of six (a sliver under the first), then the limit their
    # colour shows: an orange bar short of full; nil without one bar per stat.
    def self.bars(rows)
      cells = by_stat(rows, BAR)
      return nil unless cells
      list = cells.map do |stat, m|
        name = PokeAccess::Data.stat_name(stat)
        next PokeAccess::I18n.t(:bw_ev_bar_low, :stat => name) if m[1] == "01"
        PokeAccess::I18n.t(:bw_ev_bar, :stat => name, :n => m[1].to_i)
      end
      line = PokeAccess::I18n.t(:bw_ev_bars, :list => list.join(", "))
      limit = cells.any? { |_stat, m| m[2] && m[1] != "6" }
      limit ? "#{line} #{PokeAccess::I18n.t(:bw_ev_limit)}" : line
    end

    # The sentences the stats page adds after pk's stats: the grades and the bars its last draw painted.
    def self.extras(pk)
      [grades(take(:iv, pk)), bars(take(:ev, pk))].compact
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end
  end
end

[[:pbDisplayIVRating, :iv], [:pbDisplayEVRating, :ev]].each do |meth, kind|
  PokeAccess::Hooks.around_hook("PokemonSummary_Scene", meth, :optional => true) do |scene, nxt, _a|
    r = nil
    rows = PokeAccess::PaintCapture.icon_rows { r = nxt.call }
    begin
      PokeAccess::BWSummary.note(scene, kind, rows)
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end
    r
  end
end

PokeAccess::Hooks.override(PokeAccess::SummaryGameData, :stats_extras, :tag => "bw_summary") do |_m, original, args|
  original.call + PokeAccess::BWSummary.extras(args[0])
end
