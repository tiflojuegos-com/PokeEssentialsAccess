# Records what the mod would speak, instead of driving the screen-reader DLL. The stand-in mirrors the
# REAL PokeAccess.speak exactly -- whitespace collapse and nothing else -- so every spec asserts on the
# byte-for-byte text the synthesizer would receive. Cleaning stays where production keeps it: speak_clean.
# A capture that cleans on its own asserts a text the player never hears.
#
# A reader that feeds speak an uncleaned text therefore shows those codes in the log AND lands in
# raw_offenders, tagged with the suite that produced it; run_all fails the run if any surfaced -- the net
# that catches a reader which should have called speak_clean.
#
# The list survives clear() on purpose. clear() resets the spoken log between assertions and some specs
# call it a dozen times, so wiping the offenders with it would leave the net holding only whatever the
# last few lines of each suite produced. It is emptied once per engine pass, by clear_all.
module SpeakCapture
  # Every family clean() removes (core/speech/text.rb): the backslash codes (\x[..], \PN, and the eight
  # punctuation waits), markup tags (<br>, <b>...), the bare pipe, and non-whitespace control bytes. The
  # real speak passes all of them straight to the synthesizer, so any of these reaching speak means a
  # reader skipped speak_clean. Whitespace controls are excluded: speak itself collapses \t \n \r.
  RAW_CODE = /\\[A-Za-z.!|^<>~\\]|<\/?[A-Za-z][^>]*>|\||[\x00-\x08\x0b\x0c\x0e-\x1f]/

  @log = []
  @raw_offenders = []

  # Replaces PokeAccess.speak with the recording version. Call once after the toolkit is loaded.
  def self.install
    log = @log
    raw = @raw_offenders
    PokeAccess.define_singleton_method(:speak) do |text, interrupt = true|
      raw.push([(Assert.suite rescue nil), text.to_s]) if text.to_s =~ RAW_CODE
      t = text.to_s.gsub(/\s+/, " ").strip
      next if t.empty?
      @last_spoken = t
      PokeAccess.note_spoken
      # The observer and the counter are part of speak's contract -- the session recorder rides on the
      # first, the silence watch on the second -- so the stand-in honours both. Anything built on an effect
      # the capture drops is untestable here, and worse, looks tested.
      (@on_speak.call(t, interrupt) rescue nil) if @on_speak
      log.push([t, interrupt])
      nil
    end
  end

  # Empties the spoken log. Specs call this between assertions; the offender list is deliberately untouched.
  def self.clear
    @log.clear
  end

  # Empties both, for the start of an engine pass.
  def self.clear_all
    @log.clear
    @raw_offenders.clear
  end

  # [suite, raw text] for every text that reached speak with an escape-shaped control code still in it.
  def self.raw_offenders
    @raw_offenders
  end

  # The raw log of [text, interrupt] pairs since the last clear.
  def self.log
    @log
  end

  # Just the spoken texts since the last clear.
  def self.lines
    @log.map { |t, _| t }
  end

  # The last spoken text, or nil.
  def self.last
    (@log.last || [])[0]
  end
end
