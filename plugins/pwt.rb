module PokeAccess
  # The PWT scoreboard (AdvancedWorldTournament#displayScoreboard), read once its names are painted: each as
  # written, a beaten entrant (no longer in the running list) said so.
  module PWT
    def self.open(tourney)
      @tourney = tourney
      PokeAccess::PaintCapture.arm(:pwt_board)
    end

    def self.close
      @tourney = nil
      PokeAccess::PaintCapture.take(:pwt_board)
    end

    # From the frame poller: the board paints its names before the fade that follows, whose frames pass here.
    def self.poll
      return unless @tourney && PokeAccess::PaintCapture.pending?(:pwt_board)
      names = (PokeAccess::PaintCapture.take(:pwt_board, :positions) || []).map { |n| PokeAccess.clean(n) }
      t = board_text(@tourney, names)
      PokeAccess.speak(t, false) if t
    end

    # The board as a line: the names in the order painted, the beaten ones marked.
    def self.board_text(tourney, names)
      list = PokeAccess.ivar(tourney, :@trainer_list_int) || []
      running = (PokeAccess.ivar(tourney, :@trainer_list) || []).map { |t| t[0] }
      me = PokeAccess.ivar(tourney, :@player_index_int)
      rows = []
      names.each_with_index do |name, i|
        out = i != me && list[i] && !running.include?(list[i][0])
        rows.push(out ? "#{name}, #{PokeAccess::I18n.t(:pwt_out)}" : name)
      end
      rows.empty? ? nil : PokeAccess::I18n.t(:pwt_board, :list => rows.join("; "))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("AdvancedWorldTournament", :displayScoreboard, :optional => true) do |tourney, nxt, _a|
  PokeAccess::PWT.open(tourney)
  begin
    nxt.call
  ensure
    PokeAccess::PWT.close
  end
end
PokeAccess::Keys.on_frame { PokeAccess::PWT.poll }
