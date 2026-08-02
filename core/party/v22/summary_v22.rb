module PokeAccess
  # v22 summary screen (Essentials v22: UI::PokemonSummaryVisuals). Pages are symbols in @page
  # (:info/:memo/:skills/:moves/:ribbons/:egg_memo/:detailed_moves), changed by go_to_next_page /
  # go_to_previous_page; the shown Pokemon is @pokemon, switched by set_party_index. The per-page spoken
  # content is the agnostic SummaryGameData (the modern GameData API is identical), mapped from the v22 symbol.
  module SummaryV22
    # The current page's display name from its PAGE_HANDLERS entry.
    def self.page_name(page)
      h = (UI::PokemonSummaryVisuals::PAGE_HANDLERS[page] rescue nil)
      (h && h[:name]) ? (h[:name].call rescue nil) : nil
    rescue StandardError
      nil
    end

    # The spoken body for a page, reusing the v21 per-page builders.
    def self.body_for(pk, page)
      case page
      when :info             then PokeAccess::SummaryGameData.info_text(pk)
      when :memo, :egg_memo  then PokeAccess::SummaryGameData.memo_text(pk)
      when :skills           then PokeAccess::SummaryGameData.stats_text(pk)
      when :moves, :detailed_moves then PokeAccess::SummaryGameData.moves_text(pk)
      when :ribbons          then PokeAccess::SummaryGameData.ribbons_text(pk)
      end
    rescue StandardError
      nil
    end

    # Speaks the current page (name + body), prefixed with the Pokemon glance when the shown Pokemon just
    # changed. Deduped by [page, party_index] so an in-page redraw stays silent. param with_pkmn whether to
    # prepend the Pokemon name/level/hp (used when switching Pokemon with up/down)
    def self.speak(vis, with_pkmn)
      pk = PokeAccess.ivar(vis, :@pokemon)
      return unless pk
      PokeAccess::Info.set_info(:pokemon, pk)
      page = PokeAccess.ivar(vis, :@page)
      key = [page, PokeAccess.ivar(vis, :@party_index)]
      return unless PokeAccess::Cursor.changed?(vis, :sum_key, key)
      parts = []
      parts.push(PokeAccess::I18n.t(:pk_glance, :name => pk.name, :level => pk.level, :hp => pk.hp, :tot => pk.totalhp)) if with_pkmn
      parts.push(page_name(page))
      parts.push(body_for(pk, page))
      t = parts.compact.reject { |s| s.to_s.empty? }.join(". ")
      PokeAccess.speak(t, true) unless t.empty?
    rescue StandardError
      nil
    end

    # Detail of the focused move on the moves page: the move object at @move_index, or the move being
    # learned (@new_move, a Pokemon::Move object in v22) in the extra slot. move_line expects a move id, so
    # pass @new_move.id (it is an object here, not an id, which made the learn slot silent before).
    def self.move_at(vis, mi)
      pk = PokeAccess.ivar(vis, :@pokemon)
      nm = PokeAccess.ivar(vis, :@new_move)
      if nm && mi == Pokemon::MAX_MOVES
        PokeAccess::MoveReminderV22.move_line(nm.respond_to?(:id) ? nm.id : nm)
      else
        PokeAccess::SummaryGameData.move_detail(pk, (pk.moves[mi] rescue nil))
      end
    rescue StandardError
      nil
    end
  end
end

if PokeAccess::Engine.has?("UI::PokemonSummaryVisuals")
  # set_party_index changes the shown Pokemon and then calls refresh INTERNALLY. The hook engine's
  # reentrancy guard skips that nested refresh hook (a DIFFERENT method than set_party_index), so it neither
  # speaks the page without the glance nor consumes the [page, party_index] dedup: set_party_index's own
  # after-hook, running after the original returns, voices the switch WITH the new Pokemon's glance.
  PokeAccess::Hooks.after_hook("UI::PokemonSummaryVisuals", :set_party_index) do |vis, _ret, _args|
    PokeAccess::SummaryV22.speak(vis, true)
  end
  # :refresh is also bound so the FIRST page is read on open (initialize -> refresh, without any go_to_*_page
  # call); go_to_next_page / go_to_previous_page each call refresh internally too, but the guard skips that
  # nested refresh so only the page-nav hook speaks. None of these prepend the glance (page moves, not a
  # Pokemon switch); the [page, party_index] dedup keeps an in-page redraw silent.
  [:go_to_next_page, :go_to_previous_page, :refresh].each do |m|
    PokeAccess::Hooks.after_hook("UI::PokemonSummaryVisuals", m) do |vis, _ret, _args|
      PokeAccess::SummaryV22.speak(vis, false)
    end
  end
  # Per-move detail while navigating the moves page (deduped by @move_index).
  PokeAccess::Hooks.after_hook("UI::PokemonSummaryVisuals", :refresh_move_cursor) do |vis, _ret, _args|
    mi = PokeAccess.ivar(vis, :@move_index)
    if mi && PokeAccess::Cursor.changed?(vis, :move_idx, mi)
      t = PokeAccess::SummaryV22.move_at(vis, mi)
      PokeAccess.speak(t, true) if t && !t.to_s.empty?
    end
  end
  # Per-ribbon detail while navigating the ribbons page (deduped by @ribbon_index); the page body only
  # announces the count, so this voices each focused ribbon's name and description.
  PokeAccess::Hooks.after_hook("UI::PokemonSummaryVisuals", :refresh_ribbon_cursor) do |vis, _ret, _args|
    ri = PokeAccess.ivar(vis, :@ribbon_index)
    if ri && PokeAccess::Cursor.changed?(vis, :ribbon_idx, ri)
      pk  = PokeAccess.ivar(vis, :@pokemon)
      rid = pk ? (pk.ribbons[ri] rescue nil) : nil
      rd  = rid ? (GameData::Ribbon.get(rid) rescue nil) : nil
      if rd
        nm = (rd.name rescue rid.to_s); desc = (rd.description rescue "")
        t = (desc && !desc.to_s.empty?) ? "#{nm}. #{desc}" : nm.to_s
        PokeAccess.speak_clean(t, true)
      end
    end
  end
end
