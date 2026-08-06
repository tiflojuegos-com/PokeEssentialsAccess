module PokeAccess
  # Summary screen, shared helpers. The per-engine summary readers live alongside (gen-6 in
  # core/party/gen6/summary_g6.rb, modern in core/party/v21/summary_v21.rb); these methods are the parts both share,
  # so a profile with a custom summary can reuse them without pulling in an engine-specific scene.
  module Summary
    @single_page = false

    # Yields (name, pp, total_pp) for each real move of a pokemon (skips empty slots). The ONE move walk
    # both summary pages share: it resolves the name via the object then the per-engine Data adapter, and
    # total pp under either engine's spelling (totalpp gen-6, total_pp modern) -- so the assembly around
    # it stays engine-blind. Deliberately NOT a data-shape abstraction: version differences keep living in
    # the Data providers; this only walks and normalises names.
    def self.each_real_move(pk)
      (pk.moves rescue []).each do |m|
        next unless m && (m.id rescue nil) && m.id != 0
        nm = (m.name rescue nil)
        nm = (PokeAccess::Data.move_name(m.id) rescue nil) if nm.nil? || nm.to_s.empty?
        nm = PokeAccess::I18n.t(:info_move) if nm.nil? || nm.to_s.empty?
        pp = (m.pp rescue nil)
        tot = PokeAccess.attr_of(m, :totalpp, :total_pp)
        yield(nm.to_s, pp, tot)
      end
    end

    # Lists a pokemon's moves with their pp, over each_real_move.
    def self.moves_text(pk)
      return nil unless pk && pk.moves
      out = []
      each_real_move(pk) do |nm, pp, tot|
        t = nm
        t += ". " + PokeAccess::I18n.t(:mv_pp, :pp => pp, :tot => tot) if pp && tot
        out.push(t)
      end
      out.empty? ? PokeAccess::I18n.t(:sm_no_moves) : PokeAccess::I18n.t(:sm_moves, :list => out.join(", "))
    rescue StandardError
      nil
    end

    # Whether this game's summary is a single redrawn page (set true by a profile with such a summary),
    # suppressing the generic per-page reads.
    def self.single_page; @single_page; end

    # Marks the summary as single-page (called from a game file).
    def self.single_page=(v); @single_page = v; end
  end
end
