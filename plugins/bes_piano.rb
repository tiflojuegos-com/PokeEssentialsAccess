# Yuko115's Functional Piano (BES, pbPiano, a top-level function with its own loop): it paints no text and its notes are
# sounds, so what is said is how the keys map to notes, once, and the mod's own keys are held back while it plays.
module PokeAccess
  module BesPiano
    NATURALS = [["Q", :piano_note_c, false], ["W", :piano_note_d, false], ["E", :piano_note_e, false],
                ["R", :piano_note_f, false], ["T", :piano_note_g, false], ["Y", :piano_note_a, false],
                ["U", :piano_note_b, false], ["I", :piano_note_c, true], ["O", :piano_note_d, true],
                ["P", :piano_note_e, true]]
    SHARPS = [["Q", :piano_note_c, false], ["W", :piano_note_d, false], ["E", :piano_note_f, false],
              ["R", :piano_note_g, false], ["T", :piano_note_a, false], ["Y", :piano_note_c, true],
              ["U", :piano_note_d, true]]
    FORMS = { [true, false] => :piano_sharp, [false, true] => :piano_high, [true, true] => :piano_high_sharp }
    @playing = false

    # A note's spoken name in the language, sharpened and taken an octave up as its key plays it.
    def self.note_name(note_key, sharp, high)
      note = PokeAccess::I18n.t(note_key)
      form = FORMS[[sharp, high]]
      form ? PokeAccess::I18n.t(form, :note => note) : note
    end

    # A table of keys as "Q Do, W Re, ..." in the language's note names.
    def self.key_list(table, sharp)
      table.map { |letter, note_key, high| "#{letter} #{note_name(note_key, sharp, high)}" }.join(", ")
    end

    # What the piano says as it opens: its name and, while key hints are said, the keys with their notes, those
    # sharpened under shift, and the key that leaves.
    def self.help
      parts = [PokeAccess::I18n.t(:piano_title)]
      if PokeAccess::Verbosity.hints?
        shift = PokeAccess::I18n.t(:key_shift)
        leave = PokeAccess::KeyHints.key(:b, PokeAccess::I18n.t(:key_escape))
        parts.push(PokeAccess::I18n.t(:piano_keys, :list => key_list(NATURALS, false)))
        parts.push(PokeAccess::I18n.t(:piano_sharps, :shift => shift, :list => key_list(SHARPS, true)))
        parts.push(PokeAccess::I18n.t(:piano_exit, :key => leave))
      end
      PokeAccess.sentences(parts)
    end

    # Says the help, queued; a help that cannot be composed leaves the piano as it was.
    def self.say_help
      PokeAccess.speak(help, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs the piano's loop: the help said, and the mod's keys held back from the first frame.
    def self.playing
      @playing = true
      PokeAccess::Keys.typing!
      say_help
      yield
    ensure
      @playing = false
    end

    # Each frame of the piano: its keys are letters the mod binds too, T the information key and O the configuration
    # one, so the mod's keys stay quiet as they do while a name is typed.
    def self.hold_keys
      PokeAccess::Keys.typing! if @playing
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbPiano", "plugin_bes_piano", :around) do |_args, call_next|
  PokeAccess::BesPiano.playing { call_next.call }
end
PokeAccess::Frame.each_pulse { PokeAccess::BesPiano.hold_keys }
