# Records what the mod would speak, instead of driving the screen-reader DLL. It redefines PokeAccess.speak
# to run the REAL PokeAccess.clean (where control-code and double-speak bugs live) and append the cleaned
# line plus its interrupt flag to a log, so behaviour specs can assert on the spoken text.
#
# The REAL speak does NOT clean (cleaning lives in speak_clean), so a reader that feeds speak a text with
# raw control codes looks impeccable in the captured log yet would utter "\c[3]" through the synthesizer.
# The capture therefore also records every RAW text containing an escape-shaped code (\x[ , \PN, ...) in
# raw_offenders BEFORE cleaning; the runner fails the suite when any surfaced, which is the net that
# catches a reader that should have called speak_clean.
module SpeakCapture
  @log = []
  @raw_offenders = []

  # Replaces PokeAccess.speak with the recording version. Call once after the toolkit is loaded.
  def self.install
    log = @log
    raw = @raw_offenders
    PokeAccess.define_singleton_method(:speak) do |text, interrupt = true|
      raw.push(text.to_s) if text.to_s =~ /\\[A-Za-z]/
      t = PokeAccess.clean(text)
      next if t.to_s.empty?
      @last_spoken = t
      # The observer and the counter are part of speak's contract -- the session recorder rides on the
      # first, the silence watch on the second -- so the stand-in honours both. Anything built on an effect
      # the capture drops is untestable here, and worse, looks tested.
      (@on_speak.call(t, interrupt) rescue nil) if @on_speak
      PokeAccess.note_spoken
      log.push([t, interrupt])
      nil
    end
  end

  # Empties the log and the raw-offender list (the runner calls this before each suite).
  def self.clear
    @log.clear
    @raw_offenders.clear
  end

  # The raw texts (pre-clean) that contained an escape-shaped control code, since the last clear.
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
