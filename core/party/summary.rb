module PokeAccess
  # Summary screen, shared helpers. The per-engine summary readers live alongside (gen-6 in
  # core/party/gen6/summary_g6.rb, modern in core/party/v21/summary_v21.rb); these methods are the parts both share,
  # so a profile with a custom summary can reuse them without pulling in an engine-specific scene.
  module Summary
    @single_page = false

    # True when the summary is showing an EGG. Both eras give that its own page (drawPageOneEgg), and the
    # page for a hatched pokemon is not merely wrong for it, it is a spoiler: species, types and ability
    # are exactly what the screen refuses to show until it hatches.
    def self.egg?(pk)
      return false unless pk
      (pk.egg? rescue (pk.isEgg? rescue false)) ? true : false
    rescue StandardError
      false
    end

    # Speaks the egg page as PAINTED: the memo labels, the item, where the egg came from and how close it
    # is to hatching -- the last two being the only thing on the screen a player is waiting for, and both
    # written as a formatted paragraph rather than a label.
    #
    # Called from the page DISPATCHER of each era, not from drawPageOneEgg, and called on EVERY page so the
    # capture is always taken: left armed it would keep collecting every string the next screen paints.
    # Deduped on the scene because the modern dispatcher redraws on cursor moves.
    def self.say_egg_page(scene, pk)
      rows = PokeAccess::PaintCapture.take(:summary_egg)
      return unless egg?(pk)
      t = PokeAccess::PaintCapture.text(rows)
      t = PokeAccess::I18n.t(:sm_egg) if t.to_s.strip.empty?
      return if t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(scene, :summary_egg, t.to_s)
      PokeAccess.speak_clean(t, false)
    rescue StandardError
      nil
    end

    # The spoken name and description of a ribbon, from the modern Ribbon GameData or gen-6's PBRibbons.
    # Both ribbon cursors read through here: the modern page, and Awakening's, the one gen-6 summary that
    # keeps a cursor over its ribbons.
    def self.ribbon_text(id)
      return nil unless id
      r = (GameData::Ribbon.get(id) rescue nil)
      return PokeAccess::Util.join_parts([(r.name rescue nil), (r.description rescue nil)]) if r
      name = (PBRibbons.getName(id) rescue nil)
      return nil if name.nil? || name.to_s.empty?
      PokeAccess::Util.join_parts([name, (PBRibbons.getDescription(id) rescue nil)])
    end

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

# The egg page of the summary, captured rather than composed: what it says is the trainer memo, where the
# egg came from and how close it is to hatching, and every per-language build words those itself.
#
# Armed on the page DISPATCHER, which is the only place it CAN be armed from. No game calls drawPageOneEgg
# from outside: the six gen-6 games reach it from drawPageOne and the nine modern ones from drawPage, and
# both of those carry the page reader's own after-hook, which runs its original under the reentrancy guard
# -- so a hook on the inner method was skipped whole and the egg page said nothing at all, in any of the
# fifteen. Both dispatcher names are tried on both spellings, because the pairing is the era's and not the
# class name's, and the take lives in the dispatcher's after-hook (say_egg_page).
PokeAccess::Hooks.variants(["PokemonSummaryScene", "PokemonSummary_Scene"], :drawPageOne, "summary_egg") do |cname|
  arm = lambda { PokeAccess::PaintCapture.arm(:summary_egg) }
  a = PokeAccess::Hooks.before_hook(cname, :drawPageOne, :optional => true) { arm.call }
  b = PokeAccess::Hooks.before_hook(cname, :drawPage, :optional => true) { arm.call }
  a || b
end
