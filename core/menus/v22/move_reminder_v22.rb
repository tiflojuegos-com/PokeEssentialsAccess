module PokeAccess
  # The move-line formatter summary_v22 calls. Formatting only: a cursor hook here would double-read the relearner.
  module MoveReminderV22
    # A move id's detail via MoveInfo.by_id at the summary move reading's level, or the id as a string.
    def self.move_line(id)
      (PokeAccess::MoveInfo.by_id(id, :summary_move) rescue nil) || id.to_s
    end
  end
end
