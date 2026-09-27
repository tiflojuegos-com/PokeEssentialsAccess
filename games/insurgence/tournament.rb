module PokeAccess
  # Insurgence's Pokemon World Tournament (PokemonWorldTournament, 182_Pokemon_World_Tournament.rb), an older copy of
  # Luka's script than the one plugins/pwt.rb reads: createScoreBoard paints the eight entrants at once before each
  # round, the beaten ones faded, and the announcer never names them. The board is said, queued, as painted.
  module InsurgenceTournament
    # The board as a line: the names in the order painted, a faded one (not the player's, and missing from the running
    # list createScoreBoard was given) marked as out; nil when none was painted.
    # param running the list createScoreBoard was given, [trainer, name, ...] rows still in the tournament
    def self.board_text(tourney, names, running)
      list = PokeAccess.ivar(tourney, :@trainer_list_int) || []
      left = (running || []).map { |t| t[0] }
      me = PokeAccess.ivar(tourney, :@player_index_int)
      rows = []
      names.each_with_index do |name, i|
        out = i != me && list[i] && !left.include?(list[i][0])
        rows.push(out ? "#{name}, #{PokeAccess::I18n.t(:pwt_out)}" : name)
      end
      rows.empty? ? nil : PokeAccess::I18n.t(:pwt_board, :list => rows.join("; "))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("insurgence") do
  around("PokemonWorldTournament", :createScoreBoard) do |t, nxt, args|
    PokeAccess::PaintCapture.arm(:ins_pwt_board)
    begin
      r = nxt.call
    ensure
      names = (PokeAccess::PaintCapture.take(:ins_pwt_board, :positions) || []).map { |n| PokeAccess.clean(n) }
    end
    text = PokeAccess::InsurgenceTournament.board_text(t, names, args[0])
    PokeAccess.speak(text, false) if text
    r
  end
end
