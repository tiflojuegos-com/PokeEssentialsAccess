module PokeAccess
  # The Battle Arena's judgment, stock in every era (PokeBattle_Scene and Battle::Scene#updateJudgment): after three
  # turns the referee judges three categories, and each repaint of the judgment box marks the newest one with a picture
  # per side, a win, a loss or a tie. Its only text is the names, the category labels and the totals, so each
  # category's marks are said, with the label it paints, after the referee's line that judges it.
  module ArenaJudgment
    # The category labels as the box paints them, top to bottom: the column of its VS row, between that row and the
    # judgment row; nil when the paint has another shape.
    def self.labels(rows)
      placed = (rows || []).select { |r| r[2] && r[3] }
      return nil if placed.length < 5
      column = placed.select { |r| r[2] == placed[1][2] }.sort_by { |r| r[3] }
      column.length >= 5 ? column[1, 3].map { |r| PokeAccess.clean(r[0].to_s) } : nil
    end

    # Category i's marks, the left side's (the player's) first: who wins and who loses it, or a tie; led by its label.
    def self.result(i, labels, battler1, battler2, ratings1, ratings2)
      a = ratings1[i].to_i
      b = ratings2[i].to_i
      marks = a == b ? PokeAccess::I18n.t(:arena_tie) : [mark(battler1, a > b), mark(battler2, b > a)].join(", ")
      label = labels ? labels[i] : nil
      label ? "#{label}: #{marks}" : marks
    end

    # One side's mark: the battler, by its name, winning or losing the category.
    def self.mark(battler, won)
      PokeAccess::I18n.t(won ? :arena_win : :arena_lose, :name => (battler.name rescue "?").to_s)
    end

    # The box repainted with phase categories judged (args as updateJudgment's): the newest one's marks, kept for
    # the referee's next line; rows is what the repaint painted.
    def self.judged(args, rows)
      phase = args[1]
      return unless phase.is_a?(Integer) && phase >= 1 && phase <= 3
      PokeAccess.after_next_line(result(phase - 1, labels(rows), args[2], args[3], args[4], args[5]))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Engine.scene_classes("PokeBattle_Scene", "Battle::Scene").each do |cn|
  PokeAccess::Hooks.around_hook(cn, :updateJudgment, :optional => true) do |_scene, nxt, args|
    r = nil
    rows = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::ArenaJudgment.judged(args, rows)
    r
  end
end
