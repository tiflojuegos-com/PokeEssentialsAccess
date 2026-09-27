module PokeAccess
  # The randomizer setup of the engine Reborn and Desolation share (RandomizerScene, opened by the "randomizer"
  # password): pages of the animation editor's controls (ControlWindow) that answer the mouse alone, and cancel, the
  # one key the screen takes. J/K/L/I move a focus between them as on the fly map, confirm works a button or a
  # checkbox, the left and right arrows step a slider; each change is written into the control itself, right after
  # its window's update, so the scene's own changed? check reads it as a click.
  module RandomizerRV
    # Control kinds by the game's class name; a subclass (OptionalSlider) is found through its ancestors.
    KINDS = { "TextBox" => :text, "Checkbox" => :checkbox, "TextSlider" => :slider, "Slider" => :slider,
              "Button" => :button, "Label" => :label }

    # A slider's step with shift held.
    BIG_STEP = 10

    # Enter, which ends typing in a text field (the confirm button would fire on typed letters).
    VK_RETURN = 0x0D

    # Says how the screen is worked, as it opens.
    def self.announce
      PokeAccess.speak(PokeAccess::I18n.t(:rv_randomizer_keys), true)
    end

    # The scene is starting: no focus yet.
    def self.opened(scene)
      reset
      @scene = scene
      announce
    end

    # The scene's loop has returned; a field left typing gives the keyboard back.
    def self.closed
      stop_editing
      reset
    end

    def self.reset
      @scene = nil
      @side = nil
      @focus = nil
      @pending = nil
      @editing = nil
      @page_pressed = false
      @section = nil
    end

    # The control the keys act on, or nil.
    def self.focus; @focus; end

    # One frame of the scene, from the hook on its sidebar loop, before any window updates: the keys move the focus
    # or queue what that control's window applies. While a field is typing, only Enter is read.
    def self.frame(scene, side)
      return unless @scene && @scene.equal?(scene)
      @side = side
      @pending = nil
      return unless live?
      return typing_frame if @editing
      handle(read_keys)
    end

    # Whether the keys are the mod's this frame: the mod on, the game focused and its menu shut.
    def self.live?
      return false unless (PokeAccess::Keys.enabled rescue true)
      return false unless (PokeAccess::Keys.focused? rescue true)
      !(PokeAccess::ConfigMenu.active? rescue false)
    end

    # The frame's key as an action: a direction (J/K/L/I, as on the fly map), :confirm, or a signed slider step.
    def self.read_keys
      PokeAccess::TownMap::DIRS.each { |sym, dir| return dir if PokeAccess::Keys.key(sym) }
      return :confirm if Input.trigger?(Input::C)
      step = (PokeAccess::Keys.shift_down? rescue false) ? BIG_STEP : 1
      return -step if Input.repeat?(Input::LEFT)
      return step if Input.repeat?(Input::RIGHT)
      nil
    end

    def self.handle(action)
      case action
      when :left, :right, :up, :down then move(action)
      when :confirm then activate
      when Integer then step(action)
      end
    end

    # Moves the focus to the nearest control in a direction and says it; with none yet, to the sidebar's first.
    # Up and down keep to the focus's column, so a gap in the sidebar never lands on the page beside it; left and
    # right cross to the other column, at the nearest row. Returns whether it moved.
    def self.move(dir)
      spots = spots_now
      return false if spots.empty?
      here = @focus ? position(@focus) : nil
      if here.nil?
        @focus = spots[0][0]
        say_focus
        return true
      end
      others = spots.reject { |s| s[0].equal?(@focus) }
      others = others.select { |s| s[1][0] == here[0] } if dir == :up || dir == :down
      target = PokeAccess::TownMap.nearest(others.map { |s| s[1] }, here[0], here[1], dir)
      if target.nil?
        PokeAccess.speak(PokeAccess::I18n.t(:rv_randomizer_edge), true)
        return false
      end
      @focus = others.find { |s| s[1] == target }[0]
      say_focus
      true
    end

    # The controls on screen worth a stop, as [control, [x, y]]: the sidebar's, then the shown page's.
    def self.spots_now
      out = []
      [@side, main_window].compact.each do |win|
        (win.controls rescue []).each do |c|
          xy = position(c, win)
          out.push([c, xy]) if xy && focusable?(c)
        end
      end
      out
    end

    def self.main_window
      @scene ? (@scene.mainwin rescue nil) : nil
    end

    # A control's place on screen: its window's corner plus its own offset.
    def self.position(c, win = nil)
      win ||= c.parent
      return nil unless win
      [win.x.to_i + c.x.to_i, win.y.to_i + c.y.to_i]
    rescue StandardError
      nil
    end

    # Every known control but a blank label; the sidebar's spacers are bare UIControls, of no known kind.
    def self.focusable?(c)
      kind = kind_of(c)
      return false if kind.nil?
      kind != :label || !own_label(c).empty?
    end

    def self.kind_of(c)
      c.class.ancestors.each do |a|
        k = KINDS[a.name.to_s.split("::").last]
        return k if k
      end
      nil
    end

    def self.own_label(c)
      c ? (c.label rescue "").to_s.strip : ""
    end

    # The control's name: its own label or, for a slider painted without one, the heading above it.
    def self.label_of(c)
      own = own_label(c)
      own.empty? ? own_label(heading_above(c)) : own
    end

    # The nearest heading (a label with text) above a control in its window, or nil.
    def self.heading_above(c)
      list = (c.parent.controls rescue [])
      i = list.index(c)
      return nil unless i
      (i - 1).downto(0) { |j| return list[j] if kind_of(list[j]) == :label && !own_label(list[j]).empty? }
      nil
    end

    # The control said whole: name, kind, and its mark, value or text.
    def self.describe(c)
      parts = [label_of(c)]
      case kind_of(c)
      when :button then parts.push(PokeAccess::I18n.t(:rv_randomizer_button))
      when :checkbox then parts.push(PokeAccess::I18n.t(:rv_randomizer_checkbox), state_of(c))
      when :slider then parts.push(PokeAccess::I18n.t(:rv_randomizer_slider), value_of(c))
      when :text then parts.push(PokeAccess::I18n.t(:rv_randomizer_text), value_of(c))
      end
      parts.reject { |p| p.to_s.empty? }.join(", ")
    end

    def self.state_of(c)
      PokeAccess::I18n.t(c.checked ? :rv_randomizer_checked : :rv_randomizer_unchecked)
    end

    # A slider's value as painted (its option's text, or the number), or a field's text.
    def self.value_of(c)
      if kind_of(c) == :text
        t = c.text.to_s
        return t.empty? ? PokeAccess::I18n.t(:rv_randomizer_empty) : t
      end
      opts = c.respond_to?(:options) ? c.options : nil
      v = c.curvalue
      (opts.is_a?(Array) && opts[v]) ? opts[v].to_s.strip : v.to_s
    end

    # Says the focused control, with the heading above it first when the move has crossed into its section: a page
    # repeats names under different headings (Reborn's three "Follow Evolutions").
    def self.say_focus
      head = kind_of(@focus) == :label ? @focus : heading_above(@focus)
      text = describe(@focus)
      if head && !head.equal?(@section) && !head.equal?(@focus) && !own_label(@focus).empty?
        text = "#{own_label(head)}, #{text}"
      end
      @section = head
      PokeAccess.speak(text, true)
    end

    # Confirm: a button or a checkbox is queued for its window's update, a field starts typing, the rest is said
    # again.
    def self.activate
      return false unless @focus
      case kind_of(@focus)
      when :button, :checkbox then @pending = [@focus, :press]
      when :text then start_editing(@focus)
      else say_focus
      end
      true
    end

    # Queues a slider step for its window's update; nothing on any other control.
    def self.step(delta)
      return false unless @focus && kind_of(@focus) == :slider
      @pending = [@focus, delta]
      true
    end

    # After a ControlWindow's update, which clears every control's changed flag: the queued press or step lands on
    # its control there, so the changed? check the scene makes next sees it.
    def self.after_update(win)
      return unless @scene
      act = @pending
      if act && (win.controls.index(act[0]) rescue nil)
        @pending = nil
        apply(win, act[0], act[1])
      end
      type_fallback(win) if @editing
      announce_page(win) if @page_pressed && win.equal?(main_window)
    end

    # Leaves a control as a click would: a button changed, a checkbox flipped, a slider moved by the step (changed
    # only when the value did, as the arrows do); the new mark or value is said.
    def self.apply(win, c, act)
      case kind_of(c)
      when :button
        c.changed = true
        @page_pressed = page_button?(win, c)
      when :checkbox
        c.checked = !c.checked
        c.changed = true
        PokeAccess.speak(state_of(c), true)
      when :slider
        old = c.curvalue
        c.curvalue = old + act
        c.changed = (c.curvalue != old)
        PokeAccess.speak(value_of(c), true)
      end
      (win.repaint rescue nil)
    end

    # Whether a pressed button is one of the sidebar's page buttons, which come first, one per page.
    def self.page_button?(win, c)
      return false unless win.equal?(@side)
      i = win.controls.index(c)
      pages = (@scene.pages rescue nil)
      (i && pages.is_a?(Array) && i < pages.length) ? true : false
    end

    # Says the page a sidebar button put up, by its first heading, which then goes unrepeated on the way in.
    def self.announce_page(win)
      @page_pressed = false
      head = (win.controls rescue []).find { |c| kind_of(c) == :label && !own_label(c).empty? }
      @section = head
      PokeAccess.speak(own_label(head), true) if head
    end

    # Confirm on a field: it takes the keyboard as a click on it would (captured, text input on) until Enter.
    def self.start_editing(c)
      c.instance_variable_set(:@captured, true)
      Input.text_input = true if Input.respond_to?(:text_input=)
      (c.invalidate rescue nil)
      @editing = c
      PokeAccess::Keyboard.triggered?(:rv_randomizer_enter, VK_RETURN)
      PokeAccess.speak(PokeAccess::I18n.t(:rv_randomizer_typing), true)
    end

    def self.stop_editing
      c = @editing
      @editing = nil
      return unless c
      c.instance_variable_set(:@captured, false)
      Input.text_input = false if Input.respond_to?(:text_input=)
      (c.invalidate rescue nil)
    end

    # A frame while typing: the mod's keys stay quiet, and Enter ends it and says the text.
    def self.typing_frame
      PokeAccess::Keys.typing!
      return unless PokeAccess::Keyboard.triggered?(:rv_randomizer_enter, VK_RETURN)
      c = @editing
      stop_editing
      PokeAccess.speak(value_of(c), true)
    end

    # The field types only with the pointer over the window (Mouse.getMousePos is nil otherwise), so without it the
    # typed text and Backspace go in here, the way the field puts them.
    def self.type_fallback(win)
      c = @editing
      return unless (win.controls.index(c) rescue nil)
      return unless (Mouse.getMousePos rescue nil).nil?
      if (Input.triggerex?(:BACKSPACE) || Input.repeatex?(:BACKSPACE) rescue false)
        c.delete if PokeAccess.ivar(c, :@cursor).to_i > 0
      elsif Input.respond_to?(:gets)
        Input.gets.to_s.scan(/./m).each { |ch| c.insert(ch) }
      end
    end
  end
end

if PokeAccess::DataRV.engine? && PokeAccess.const_at("RandomizerScene")
  PokeAccess::Hooks.before_hook("RandomizerScene", :initialize, :optional => true) do |s, _a|
    PokeAccess::RandomizerRV.opened(s)
  end
  PokeAccess::Hooks.after_hook("RandomizerScene", :initialize, :optional => true, :hook_container => true) do |_s, _r, _a|
    PokeAccess::RandomizerRV.closed
  end
  PokeAccess::Hooks.before_hook("RandomizerScene", :sidewinLoop, :optional => true) do |s, a|
    PokeAccess::RandomizerRV.frame(s, a[0])
  end
  PokeAccess::Hooks.after_hook("ControlWindow", :update, :optional => true, :hook_container => true) do |w, _r, _a|
    PokeAccess::RandomizerRV.after_update(w)
  end
end
