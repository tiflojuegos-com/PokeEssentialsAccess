module PokeAccess
  # Sevii's move detail (PokemonSummaryScene#drawMoveSelection) paints each move's contest category under its type
  # icon, read off contestmoves.dat at the contest move it finds by the move's name.
  module SeviiSummary
    # The contest move the detail finds for a move name, as its loop does: the first one named so (the match turns
    # the loop's name into a number, which no later name equals), or nil.
    def self.contest_id(name)
      (1..::PBContestMoves.maxValue).find { |j| ::PBContestMoves.getName(j) == name }
    end

    # The contest category the move detail's icon shows for a summary move, or nil for any other reading or a
    # move with no contest move.
    def self.type_note(reading, name)
      return nil unless reading == :summary_move && name && !name.to_s.empty?
      id = contest_id(name.to_s)
      return nil unless id
      key = PokeAccess::SeviiContests::CATEGORY_KEYS[::PBContestMoveData.new(id).contestType.to_i]
      key ? PokeAccess::I18n.t(:if2_ct_category, :t => PokeAccess::I18n.t(key)) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("sevii") do
  override("PokeAccess::MoveInfo", :type_note) do |_mod, original, args|
    PokeAccess::SeviiSummary.type_note(args[0], args[1]) || original.call
  end
end
