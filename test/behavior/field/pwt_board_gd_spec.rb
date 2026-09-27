# Emerald's PWT scoreboard is read once as painted, the beaten entrants (their pictures faded) marked.
Suite.define("pwt: the scoreboard is read with the beaten entrants marked") do
  t = PokeAccess::I18n
  tourney = Object.new
  tourney.instance_variable_set(:@trainer_list_int, [[:A, []], [:B, []], [:C, []]])
  tourney.instance_variable_set(:@trainer_list, [[:A, []], [:C, []]])
  tourney.instance_variable_set(:@player_index_int, 0)
  PokeAccess::PWT.open(tourney)
  begin
    SpeakCapture.clear
    pbDrawTextPositions(nil, [["Yo", 34, 38], ["Bruno", 34, 102], ["Clara", 34, 166]])
    PokeAccess::PWT.poll
    PokeAccess::PWT.poll
  ensure
    PokeAccess::PWT.close
  end
  eq "once, the beaten one marked", SpeakCapture.lines,
     [t.t(:pwt_board, :list => "Yo; Bruno, #{t.t(:pwt_out)}; Clara")]
end
