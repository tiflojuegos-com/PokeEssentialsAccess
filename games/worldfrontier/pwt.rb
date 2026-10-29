# World Frontier's tournament bracket (FrentePWTBracket.show, the Estadio Mundial's board): a tree of name boxes, the
# eliminated ones greyed out and the paths of who went on lit, with the tournament's title above and its round below.
# Said as it opens, before the referee's line: the title, the round, who is still in and who is out, in slot order.
module PokeAccess
  module WfBracket
    # The board's reading for a tournament (FrentePWT): title, round label, then the names by whether they are out.
    def self.board(pwt)
      names = (0...pwt.participant_count).map { |i| [pwt.participant_name(i).to_s, (pwt.eliminated[i] rescue false)] }
      inside = names.reject { |_n, out| out }.map { |n, _o| n }
      outside = names.select { |_n, out| out }.map { |n, _o| n }
      parts = [pwt.data[:title].to_s, pwt.round_label.to_s]
      parts.push(PokeAccess::I18n.t(:wf_pwt_in, :list => inside.join(", "))) unless inside.empty?
      parts.push(PokeAccess::I18n.t(:wf_pwt_out, :list => outside.join(", "))) unless outside.empty?
      PokeAccess.sentences(parts)
    end
  end
end

PokeAccess::Hooks.wrap_singleton("FrentePWTBracket", :show, "worldfrontier_pwt_bracket", :before) do |args, _r|
  t = PokeAccess::WfBracket.board(args[0])
  PokeAccess::Info.set_info(:text, PokeAccess.clean(t))
  PokeAccess.speak_clean(t, true)
end
