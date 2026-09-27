module PokeAccess
  # The dispatcher every spoken line goes through: it makes the line a Message, hands it to the observers (the
  # history, the session recorder) and then to the screen reader.
  module Speech
    # One spoken line as the listeners see it: the text as the reader got it, its category (CATEGORIES, or REVIEW
    # for the history's own readouts), whether it interrupted, and its number in the session.
    Message = Struct.new(:text, :category, :interrupt, :seq)

    @observers = []

    # Registers a block that sees every line said, as a Message, under a key; registering the key again replaces it.
    def self.observe(key, &blk)
      unobserve(key)
      @observers.push([key, blk])
    end

    # Stops the observer registered under a key.
    def self.unobserve(key)
      @observers.reject! { |row| row[0] == key }
    end

    # Hands a message to every observer; one that raises is logged once and passed over.
    def self.notify(msg)
      @observers.each do |row|
        begin
          row[1].call(msg)
        rescue StandardError => e
          PokeAccess.log_once("observer_#{row[0]}", e)
        end
      end
    end
  end

  # Speaks a line through the screen reader, whitespace collapsed, and hands it to every observer; interrupt cuts
  # current speech, and a nil category takes the scope's or the moment's.
  def self.speak(text, interrupt = true, category = nil)
    text = text.to_s.gsub(/\s+/, " ").strip
    return if text.empty?
    @last_spoken = text
    note_spoken
    PokeAccess::Speech.notify(PokeAccess::Speech::Message.new(text, PokeAccess::Speech.category_of(category),
                                                              interrupt, spoken_seq))
    voice_out(text, interrupt)
  rescue StandardError => e
    write_marker("speak_error: #{format_error(e)}\n")
  end

  # Speaks a line of game text after clean strips its control codes (\PN, \V[n], \C[n]...).
  def self.speak_clean(text, interrupt = true, category = nil)
    speak(clean(text), interrupt, category)
  end

  # The last non-empty line spoken, for the spoken diagnostic ("last: ..."), or nil if nothing spoken yet.
  def self.last_spoken; @last_spoken; end

  # How many lines have been spoken this session (the silence watch's "did anything happen").
  def self.spoken_seq; @spoken_seq || 0; end

  # Bumps that counter.
  def self.note_spoken; @spoken_seq = (@spoken_seq || 0) + 1; end
end
