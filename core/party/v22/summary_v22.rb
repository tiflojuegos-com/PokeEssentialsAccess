module PokeAccess
  # v22 summary screen (UI::PokemonSummaryVisuals): @page is a symbol (:info, :memo, :skills, :moves, :ribbons,
  # :egg_memo, :detailed_moves), @pokemon the one shown; the text comes from SummaryGameData.
  module SummaryV22
    # The current page's display name from its PAGE_HANDLERS entry.
    def self.page_name(page)
      h = (UI::PokemonSummaryVisuals::PAGE_HANDLERS[page] rescue nil)
      (h && h[:name]) ? (h[:name].call rescue nil) : nil
    rescue StandardError
      nil
    end

    # The spoken body for a page, from the SummaryGameData builders (egg_memo_text for an egg's memo).
    def self.body_for(pk, page)
      case page
      when :info             then PokeAccess::SummaryGameData.info_text(pk)
      when :memo             then PokeAccess::SummaryGameData.memo_text(pk)
      when :egg_memo         then PokeAccess::SummaryGameData.egg_memo_text(pk)
      when :skills           then PokeAccess::SummaryGameData.stats_text(pk)
      when :moves, :detailed_moves then PokeAccess::SummaryGameData.moves_text(pk)
      when :ribbons          then PokeAccess::SummaryGameData.ribbons_text(pk)
      end
    rescue StandardError
      nil
    end

    # Speaks the current page's name and body, deduped by [page, party_index].
    # param with_pkmn true to lead with the Pokemon's name, level and hp (a switch with up/down)
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
      t = PokeAccess::Util.join_parts(parts)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # The focused move in full: the move at @move_index, or in the extra slot the move being learned (@new_move,
    # an object in v22, passed to move_line by id).
    def self.move_at(vis, mi)
      pk = PokeAccess.ivar(vis, :@pokemon)
      nm = PokeAccess.ivar(vis, :@new_move)
      if nm && mi == Pokemon::MAX_MOVES
        PokeAccess::MoveReminderV22.move_line(nm.is_a?(Symbol) ? nm : (nm.id rescue nm))
      else
        PokeAccess::SummaryGameData.move_detail(pk, (pk.moves[mi] rescue nil))
      end
    rescue StandardError
      nil
    end
  end
end

if PokeAccess::Engine.has?("UI::PokemonSummaryVisuals")
  # Switching Pokemon: the page led by the new Pokemon's glance; the guard skips the refresh nested inside.
  PokeAccess::Hooks.after_hook("UI::PokemonSummaryVisuals", :set_party_index) do |vis, _ret, _args|
    PokeAccess::SummaryV22.speak(vis, true)
  end
  # Turning pages, and refresh for the first page on opening (a refresh nested in a page turn is skipped).
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
      PokeAccess.speak(t, true)
    end
  end
  # The focused ribbon while navigating the ribbons page (deduped by @ribbon_index): its name, and in full its
  # description, which the info key keeps.
  PokeAccess::Hooks.after_hook("UI::PokemonSummaryVisuals", :refresh_ribbon_cursor) do |vis, _ret, _args|
    ri = PokeAccess.ivar(vis, :@ribbon_index)
    if ri && PokeAccess::Cursor.changed?(vis, :ribbon_idx, ri)
      pk  = PokeAccess.ivar(vis, :@pokemon)
      rid = pk ? (pk.ribbons[ri] rescue nil) : nil
      rd  = rid ? (GameData::Ribbon.get(rid) rescue nil) : nil
      if rd
        parts = [[(rd.name rescue rid.to_s).to_s, :brief], [(rd.description rescue "").to_s, :full]]
        PokeAccess.speak_clean(PokeAccess::Verbosity.info_line(:ribbon, parts, ". "), true)
      end
    end
  end
end
