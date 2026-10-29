module PokeAccess
  # Rejuvenation's own Hall of Fame (HallOfFameScene): in the PC, C on a member selects it and opens its infobox under
  # the record's header, three pages C turns (drawInfobox by @infobox: the member with its type icons, item, nature
  # and ability; its moves, each after its type's icon, under a label; its EVs and IVs), and B ends the selection,
  # repainting the header alone. Core's panel reader says each page drawn, as a new reading of the member, and browses
  # a selected member as the PC viewer does; the record's header is said once per record, and the page on show is kept
  # on the info key while the member is selected.
  module RejuvHallOfFame
    @starting = nil

    # One painted row: type icons worded, the bars between a page's figures as pauses, question marks as unknown.
    def self.worded(text)
      PokeAccess::DexEntry.unknown_marks(PokeAccess::RejuvInspect.worded(text.to_s.gsub(/\s*\|\s*/, ", ")))
    end

    # A page as one text, laid out as the eye reads it: a label row ("Moves:") leads the rows it labels, as a list;
    # otherwise line by line, top to bottom, each line's rows left to right.
    # param pairs the rows the page painted, as PaintCapture.sample gives them
    def self.page_text(pairs)
      rows = pairs.map { |r| [worded(r[0]), r[1], r[2], r[3]] }.reject { |r| r[0].empty? }
      label = rows.find { |r| r[0] =~ /:\z/ }
      return "#{label[0]} #{PokeAccess::PaintCapture.laid_out(rows - [label]).join(', ')}" if label
      PokeAccess.sentences(PokeAccess::PaintCapture.cells(rows).map { |c| c.join(", ") })
    end

    # Draws a page with its rows kept out of the panel's capture, then hands the panel the page as one row and keeps it
    # on the scene for the info key; the member's last reading is forgotten first, so a new page of the same member is
    # read too.
    def self.draw_page(scene)
      PokeAccess::Cursor.reset(scene, :hof_pk)
      r = nil
      pairs = PokeAccess::PaintCapture.sample { r = yield }
      page = page_text(pairs)
      scene.instance_variable_set(:@access_hof_page, page)
      PokeAccess::PaintCapture.note(page, :formatted)
      r
    end

    # A move's type icon, which the moves page draws as a picture left of the move's name, as the type's word laid out
    # just after the name, in the words the quick summary gives a move's type.
    # param x, y where the page paints the move's name
    def self.note_move_type(type, x, y)
      return unless type && x.is_a?(Numeric) && y.is_a?(Numeric)
      word = PokeAccess::DexEntry.unknown_marks(PokeAccess::RejuvInspect.type_word(type.to_s))
      PokeAccess::PaintCapture.note(PokeAccess::I18n.t(:mv_type, :t => word), :type_icon, x + 1, y)
    end

    # Runs core's reading of a repaint, noting where a selection starts and ends, each of which reads the member anew:
    # B ending one cuts what is being said, as the game's own reader does, and repaints the member under the record's
    # header alone, said as a browsed record is, and C starting one reads
    # it even where no page is drawn (an egg). While a member is selected the info key keeps the page on show (an egg
    # as an egg); the end of the selection takes it off.
    def self.say_panel(scene, pk)
      selected = PokeAccess.ivar(scene, :@selected) ? true : false
      was = PokeAccess.ivar(scene, :@access_hof_selected) ? true : false
      page = PokeAccess.ivar(scene, :@access_hof_page)
      scene.instance_variable_set(:@access_hof_selected, selected)
      scene.instance_variable_set(:@access_hof_page, nil)
      PokeAccess::Cursor.reset(scene, :hof_pk) if was != selected
      PokeAccess.stop_speech if was && !selected
      @starting = (selected && !was) ? scene : nil
      yield
      if selected
        PokeAccess::Info.set_info(:text, page.to_s.strip.empty? ? PokeAccess::HallOfFame.member_text(pk) : page)
      elsif was
        PokeAccess::Info.clear_text
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    ensure
      @starting = nil
    end

    # The record's header, painted first as one row, and the page under it. As a selection starts, the header the
    # browsed record said is kept as heard, so core does not say it again before the page.
    def self.split_header(rows)
      return [nil, rows] if rows.empty?
      head = PokeAccess.clean(rows[0].to_s)
      PokeAccess::Cursor.changed?(@starting, :hof_record, head) if @starting
      [head, rows[1..-1]]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  around("HallOfFameScene", :drawInfobox, :optional => true) do |scene, nxt, _a|
    PokeAccess::RejuvHallOfFame.draw_page(scene) { nxt.call }
  end

  # The moves page draws each move's type as a picture (pbDrawBitmap), which no capture sees.
  before("HallOfFameScene", :drawMoveTypeIcon, :optional => true) do |_scene, args|
    PokeAccess::RejuvHallOfFame.note_move_type(args[1], args[2], args[3])
  end

  # A selected member (only the PC selects one) is browsed member by member and page by page, as the PC viewer reads:
  # this PC calls writePokemonData without the record number core tells the viewer by.
  override("PokeAccess::HallOfFame", :viewer?) do |_mod, original, args|
    PokeAccess.ivar(args[0], :@selected) ? true : original.call
  end

  # This PC's selection, C to start it and B to end it, around core's reading of each repaint.
  override("PokeAccess::HallOfFame", :say_panel) do |_mod, original, args|
    PokeAccess::RejuvHallOfFame.say_panel(args[0], Array(args[1])[0]) { original.call }
  end

  # The record's header is painted as one row, label and number together, first, before the page under it; an egg's
  # panel paints nothing else, and is said as an egg.
  override("PokeAccess::HallOfFame", :split_header) do |_mod, _original, args|
    PokeAccess::RejuvHallOfFame.split_header(args[0])
  end
end
