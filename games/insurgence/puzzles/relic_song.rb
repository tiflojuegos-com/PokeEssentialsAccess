# The Relic Song notes (events named Music_Note_Relic, 25 on 24 maps): a note drawn on a wall or a rock whose first page
# does nothing. The Relic Song, from the Quartz Flute's menu (useRelicSong), turns self switch D on for every note within
# one tile of the player, diagonals too, but not under the player; the note's next page then opens what it hides, and
# most go back to their first page on leaving the map. Each is listed, with what it opens for the assist, while its first
# page is live and the switch its entry may name is off (what the Telnor Cave and Mt. Rose Base notes open stays). The
# Settlement Foxtrot note (map 447) says something, so it is named. The song looks only at ids up to the map's count of
# events, which leaves out map 808's note.
PokeAccess::Game.define("insurgence") do
  notes = {
    22 => [[9, :ins_relic_items, 591]], 82 => [[29, :ins_relic_portal]], 123 => [[43, :ins_relic_room]],
    151 => [[13, :ins_relic_ring]], 152 => [[48, :ins_relic_item]], 174 => [[46, :ins_relic_room]],
    232 => [[9, :ins_relic_portal]], 400 => [[28, :ins_relic_cave, 592]], 401 => [[16, :ins_relic_room]],
    404 => [[6, :ins_relic_portal]], 415 => [[22, :ins_relic_room]], 441 => [[10, :ins_relic_climb]],
    445 => [[56, :ins_relic_room]], 447 => [[14, :ins_relic_cave]],
    455 => [[50, :ins_relic_portal], [51, :ins_relic_portal]], 478 => [[10, :ins_relic_portal]],
    523 => [[23, :ins_relic_room]], 530 => [[78, :ins_relic_portal]], 555 => [[3, :ins_relic_room]],
    672 => [[6, :ins_relic_portal]], 673 => [[3, :ins_relic_portal]], 674 => [[2, :ins_relic_portal]],
    688 => [[9, :ins_relic_portal]], 807 => [[4, :ins_relic_portal]]
  }
  speaking = 447
  first_page = lambda do |id|
    ev = $game_map.events[id]
    rev = ev && PokeAccess.ivar(ev, :@event)
    page = ev && PokeAccess.ivar(ev, :@page)
    !page.nil? && !rev.nil? && page.equal?(rev.pages[0])
  end
  label = lambda do |opens|
    lambda { PokeAccess::Puzzles.assist? ? [:ins_relic_note_hint, { :what => PokeAccess::I18n.t(opens) }] : :ins_relic_note }
  end
  notes.each do |map, list|
    mechanic(:state, map, :part => :relic) do
      auto
      list.each do |id, opens, done|
        live = lambda { first_page.call(id) && !(done && $game_switches[done]) }
        if map == speaking
          name id, label.call(opens), :when => lambda { |_ev| live.call }
        else
          spot :event => id, :label => label.call(opens), :when => live
        end
      end
    end
  end
end
