module PokeAccess
  # The screen that marks a Pokemon, in its three shapes:
  #   - the summary's (modern era and Awakening): six mark pictures, three by two, then OK and Cancel, cursor sprite;
  #   - the PC's in those games: the same grid, pointed at by the box arrow;
  #   - the gen-6 PC's: a command list, a row per mark, set or not told only by its sign's colour tag.
  # The grids keep cursor and marks in the game loop's locals: the slot is read off the cursor sprite or the arrow
  # call, each mark tracked by the loop's rule for the button (v17 and v19 flip a bit; v20 on cycle a value).
  module Marking
    NAMES = [:mk_circle, :mk_triangle, :mk_square, :mk_heart, :mk_star, :mk_diamond]

    # The summary cursor's column and row step in pixels; OK sits two rows under the first mark, Cancel three.
    STEP_X = 58
    STEP_Y = 50

    # The colour tags the gen-6 list paints a mark's sign with, set and not set (getMarkingCommands).
    MARKED = /\A<c=505050>/i
    UNMARKED = /\A<c=D0C8B8>/i

    # Starts watching a marking screen on this Pokemon.
    # param cursor :sprite (summary, read off its sprite), :arrow (PC grid, via pbMarkingSetArrow) or :list (gen-6)
    def self.open(scene, pk, cursor)
      @scene = scene
      @cursor = cursor
      m = (pk.markings rescue 0)
      @bits = !m.is_a?(Array)
      @marks = (0...6).map { |i| @bits ? (m.to_i >> i) & 1 : m[i].to_i }
      @variants = @bits ? 2 : variants(scene)
      @clears = !@bits && cursor == :sprite
      @index = nil
      @origin = nil
      @buttons = nil
      PokeAccess::PaintCapture.arm(:marking)
    end

    def self.close
      PokeAccess::PaintCapture.take(:marking)
      @scene = nil
    end

    # How this game's PC shows the screen: :arrow where the scene has pbMarkingSetArrow, else :list.
    def self.pc_cursor(scene)
      scene.respond_to?(:pbMarkingSetArrow) ? :arrow : :list
    end

    # The Pokemon the PC is marking: the one held, else the one in the party or box slot the selection names.
    def self.stored(scene, selected, held)
      return held if held
      storage = PokeAccess.ivar(scene, :@storage)
      selected[0] == -1 ? storage.party[selected[1]] : storage[selected[0], selected[1]]
    rescue StandardError
      nil
    end

    # The marks a Pokemon carries, as its panels show them: the gen-6 signs as painted (PokemonStorage::MARKINGCHARS),
    # or the pictures by name, with the colour when marks have more than two states; [] for none.
    # param variants the rows of the marks picture, or nil without a scene: then a mark above one means colours
    def self.shown(pk, variants = nil)
      m = (pk.markings rescue nil)
      return [] if m.nil?
      if m.is_a?(Array)
        colours = variants ? variants > 2 : m.any? { |v| v.to_i > 1 }
        out = []
        m.each_with_index do |v, i|
          next unless v.to_i > 0 && NAMES[i]
          n = PokeAccess::I18n.t(NAMES[i])
          out.push(colours ? "#{n} #{PokeAccess::I18n.t(:mk_color, :n => v.to_i)}" : n)
        end
        return out
      end
      signs = (PokemonStorage::MARKINGCHARS rescue nil)
      labels = signs.is_a?(Array) ? signs.map { |c| c.to_s } : NAMES.map { |k| PokeAccess::I18n.t(k) }
      (0...labels.length).select { |i| (m.to_i >> i) & 1 == 1 }.map { |i| labels[i] }
    rescue StandardError
      []
    end

    # How many states a mark has in this copy: the rows of its marks picture, two at the least.
    def self.variants(scene)
      h = (PokeAccess.ivar(scene, :@markingbitmap).bitmap.height rescue nil)
      mh = (scene.class::MARK_HEIGHT rescue nil)
      (h.is_a?(Integer) && mh.is_a?(Integer) && mh > 0 && h / mh > 2) ? h / mh : 2
    end

    # The slot under the summary's cursor sprite (0-5 a mark, 6 OK, 7 Cancel), measured from where it stood on the
    # first frame (the first mark); nil elsewhere.
    def self.slot_at(sel)
      x = (sel.x rescue nil)
      y = (sel.y rescue nil)
      return nil unless x.is_a?(Numeric) && y.is_a?(Numeric)
      @origin ||= [x, y]
      dx = x - @origin[0]
      dy = y - @origin[1]
      return 6 if dx == 0 && dy == 2 * STEP_Y
      return 7 if dx == 0 && dy == 3 * STEP_Y
      return nil unless dx % STEP_X == 0 && dy % STEP_Y == 0
      col = dx / STEP_X
      row = dy / STEP_Y
      (col >= 0 && col < 3 && row >= 0 && row < 2) ? row * 3 + col : nil
    end

    # Once the grid is painted: speaks the screen's title (its first painted row) and keeps the two buttons' labels.
    def self.introduce
      return if @buttons
      pairs = PokeAccess::PaintCapture.take_pairs(:marking)
      labels = pairs.select { |r| r[1] == :positions }.map { |r| PokeAccess.clean(r[0]) }
      @buttons = labels.length >= 2 ? labels[-2, 2] : []
      title = pairs.empty? ? "" : PokeAccess.clean(pairs.first[0])
      PokeAccess.speak(title, false) unless title.empty?
    end

    # A mark's state as a word: not set, set, or which colour of several when the picture has more rows.
    def self.state_word(v)
      return PokeAccess::I18n.t(:mk_off) if v.to_i <= 0
      return PokeAccess::I18n.t(:mk_on) if @variants <= 2
      PokeAccess::I18n.t(:mk_color, :n => v)
    end

    # A slot as it is read: a mark with its state, or a button as the screen paints it.
    def self.slot_text(i)
      return "#{PokeAccess::I18n.t(NAMES[i])}, #{state_word(@marks[i])}" if i < 6
      @buttons[i - 6] || PokeAccess::I18n.t(i == 6 ? :kb_ok : :pc_cancel)
    end

    # The cursor on slot i: the title first, then the slot, queued on arrival and interrupting after.
    def self.focus(i)
      return if @scene.nil? || i.nil? || i == @index
      introduce
      first = @index.nil?
      @index = i
      PokeAccess.speak(slot_text(i), !first)
    end

    # Speaks the cursor mark's new state in the frame its button is pressed, by the rule the loop applies.
    def self.press
      i = @index
      return unless i.is_a?(Integer) && i < 6
      if (Input.trigger?(Input::C) rescue false)
        @marks[i] = @bits ? 1 - @marks[i] : (@marks[i] + 1) % @variants
      elsif @clears && @marks[i] > 0 && (Input.trigger?(Input::A) rescue false)
        @marks[i] = 0
      else
        return
      end
      PokeAccess.speak(state_word(@marks[i]), true)
    end

    # One frame of a picture grid, polled inside the loop's Input.update: after the cursor is placed, before the loop
    # reads the button.
    def self.poll
      return if @scene.nil? || @cursor == :list
      focus(slot_at(PokeAccess.sprite(@scene, "markingsel"))) if @cursor == :sprite
      press
    end

    # A gen-6 list row while the screen is up: the sign as painted and, by its colour, set or not; the title first.
    def self.list_row(win, i)
      base = PokeAccess::Menus.generic_focus(win, i)
      return base unless @scene && @cursor == :list && base
      introduce
      return "#{base}, #{PokeAccess::I18n.t(:mk_on)}" if base =~ MARKED
      return "#{base}, #{PokeAccess::I18n.t(:mk_off)}" if base =~ UNMARKED
      base
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonSummary_Scene", :pbMarking, :optional => true) do |scene, nxt, args|
  PokeAccess::Marking.open(scene, args[0], :sprite)
  begin
    nxt.call
  ensure
    PokeAccess::Marking.close
  end
end

PokeAccess::Hooks.around_hook("PokemonStorageScene", :pbMark, :optional => true) do |scene, nxt, args|
  pk = PokeAccess::Marking.stored(scene, args[0], args[1])
  PokeAccess::Marking.open(scene, pk, PokeAccess::Marking.pc_cursor(scene))
  begin
    nxt.call
  ensure
    PokeAccess::Marking.close
  end
end

PokeAccess::Hooks.after_hook("PokemonStorageScene", :pbMarkingSetArrow, :optional => true) do |_s, _r, args|
  PokeAccess::Marking.focus(args[1])
end

PokeAccess::Menus.def_extractor("Window_AdvancedCommandPokemon") { |win, i| PokeAccess::Marking.list_row(win, i) }
PokeAccess::Keys.on_frame { PokeAccess::Marking.poll }
