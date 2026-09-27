module PokeAccess
  # The Inspect report of the engine Reborn and Rejuvenation share (pbShowBattleStats, on the L and R buttons in
  # battle): a list under an "Inspecting X:" message, which the generic reader says a line at a time as the cursor
  # moves. While it is up the info key says it whole, the message first; the command menu takes the key back when
  # it reopens. Beside the list it paints a button for the field notes and, in Reborn, one for the PULSE Dex, each
  # only when the game's predicate lets it open them; their hints are said once as the report opens.
  module InspectRV
    # The buttons in the order they sit: the predicate the game paints each by, the hint's key, and the button and
    # its keyboard letter (the field notes on S, the PULSE Dex on D).
    BUTTONS = [["canCheckFieldApp?", :rv_inspect_field_notes, :y, "S"],
               ["canCheckPulseDex?", :rv_inspect_pulse_dex, :z, "D"]]

    # The report as one text: the message above the list, then each line as painted, cleaned of its padding.
    def self.report_text(msgwindow, rows)
      head = (msgwindow.text rescue nil)
      PokeAccess.sentences([head].concat(Array(rows)).map { |r| PokeAccess.clean(r.to_s) })
    end

    # Notes what a button's predicate answered, which decides whether the report paints the button.
    def self.note_button(fname, shown)
      (@shown ||= {})[fname] = shown ? true : false
    end

    # Forgets the answers noted before a report starts: only those given while it runs decide its buttons
    # (Rejuvenation asks after its report or from the battle menus, and paints none).
    def self.forget
      @shown = {}
    end

    # The key hints of the buttons painted beside this report; forgets them for the next one.
    def self.button_hints
      shown = @shown || {}
      @shown = {}
      painted = BUTTONS.select { |b| shown[b[0]] }
      painted.map { |b| PokeAccess::I18n.t(b[1], :key => PokeAccess::KeyHints.key(b[2], b[3])) }
    end

    # Offers the report on the info key with the painted buttons' hints after it, and says those hints once while key
    # hints are said.
    def self.offer(msgwindow, rows)
      hints = button_hints
      text = PokeAccess.sentences([report_text(msgwindow, rows)].concat(hints))
      PokeAccess::Info.set_info(:text, text) unless text.empty?
      PokeAccess.speak(PokeAccess.sentences(hints), false) if !hints.empty? && PokeAccess::Verbosity.hints?
    rescue StandardError
      nil
    end

    # Whether the game defines a top-level function.
    def self.fn?(name)
      Object.private_method_defined?(name.to_sym) || Object.method_defined?(name.to_sym)
    end

    # Hooks the report, its start (pbShowBattleStats, the one way in both games take) and the predicates of its
    # buttons.
    def self.bind
      return unless fn?("pbShowInspect")
      if fn?("pbShowBattleStats")
        PokeAccess::Hooks.wrap_global("pbShowBattleStats", "rv_inspect_start", :before) do |_args, _r|
          PokeAccess::InspectRV.forget
        end
      end
      PokeAccess::Hooks.wrap_global("pbShowInspect", "rv_inspect_report", :before) do |args, _r|
        PokeAccess::InspectRV.offer(args[0], args[1])
      end
      BUTTONS.each do |b|
        next unless fn?(b[0])
        PokeAccess::Hooks.wrap_global(b[0], "rv_inspect_buttons", :after) do |_args, shown|
          PokeAccess::InspectRV.note_button(b[0], shown)
        end
      end
    end
  end
end

PokeAccess::InspectRV.bind if PokeAccess::DataRV.engine?
