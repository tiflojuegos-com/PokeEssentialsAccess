# Royal's egg-move tutor replaces the move reminder's main without calling it, so the reminder's opening read
# is given to its own main. The profile file is loaded over a stand-in of the class, removed afterwards.
Suite.define("royal: the egg-move tutor reads its first move on opening") do
  made = !UI.const_defined?(:EggMoveTutor)
  UI.const_set(:EggMoveTutor, Class.new { def main; :taught; end }) if made
  begin
    load File.expand_path("../../../games/royal/egg_tutor.rb", File.dirname(__FILE__))
    tutor = UI::EggMoveTutor.new
    tutor.instance_variable_set(:@moves, [[:TACKLE, nil], [:EMBER, nil]])
    SpeakCapture.clear
    eq "main runs as before", tutor.main, :taught
    eq "and the first move is read as it opens", SpeakCapture.lines, [PokeAccess::UIV21.move_from_entry([:TACKLE, nil])]
  ensure
    UI.send(:remove_const, :EggMoveTutor) if made
  end
end
