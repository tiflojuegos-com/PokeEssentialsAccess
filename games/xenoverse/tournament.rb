module PokeAccess
  # The Apollo tournament's bracket (0250_Tournament, PWT#showChart, from the boards of map 622): a picture of the
  # first round's trainers in pairs (@firstPool), those already beaten dimmed (absent from @pool), a VIP not yet met
  # hidden. Says the pairs still to fight and who is out, once, as the picture opens; arrows only scroll it.
  module XenoverseTournament
    # The bracket's line: the pairs of the trainers still in, then those out.
    def self.bracket(pwt)
      first = PokeAccess.ivar(pwt, :@firstPool)
      pool = PokeAccess.ivar(pwt, :@pool)
      return nil unless first.is_a?(Array) && pool.is_a?(Array)
      inside = pool.map { |e| name(e) }
      pairs = []
      inside.each_slice(2) do |a, b|
        pairs.push(b ? PokeAccess::I18n.t(:xenoverse_versus, :a => a, :b => b) : a)
      end
      out = first.reject { |e| pool.any? { |p| p.equal?(e) } }.map { |e| name(e) }
      parts = [PokeAccess::I18n.t(:xenoverse_bracket)] + pairs
      unless out.empty?
        parts.push(PokeAccess::I18n.t(:xenoverse_bracket_out, :list => PokeAccess::Routes::Text.and_list(out)))
      end
      PokeAccess.sentences(parts)
    end

    # A trainer of the pool by name: the player, a VIP the player has not met as unknown, else the entry's name.
    def self.name(entry)
      return PokeAccess.clean($Trainer.name.to_s) if entry.equal?($Trainer)
      return PokeAccess::I18n.t(:dex_unknown) if hidden_vip?(entry)
      PokeAccess.clean((entry[1] rescue "").to_s)
    end

    # Whether the bracket draws the entry as a hidden VIP, as showChart tests it.
    def self.hidden_vip?(entry)
      vip = (VIPLIST.rassoc(entry[2]) rescue nil)
      vip && !($Trainer.vips.include?(vip) rescue true) ? true : false
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  around("PWT", :showChart) do |pwt, call_next, _args|
    text = PokeAccess::XenoverseTournament.bracket(pwt)
    if text
      PokeAccess::Info.set_info(:text, text)
      PokeAccess.speak(text, true)
    end
    begin
      call_next.call
    ensure
      PokeAccess::Info.clear_text
    end
  end
end
