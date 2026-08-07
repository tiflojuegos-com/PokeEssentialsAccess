# Records what the mod would speak, instead of driving the screen-reader DLL. It redefines PokeAccess.speak
# to run the REAL PokeAccess.clean (where control-code and double-speak bugs live) and append the cleaned
# line plus its interrupt flag to a log, so behaviour specs can assert on the spoken text.
#
# The REAL speak does NOT clean (cleaning lives in speak_clean), so a reader that feeds speak a text with
# raw control codes looks impeccable in the captured log yet would utter "\c[3]" through the synthesizer.
# The capture therefore also records every RAW text containing an escape-shaped code (\x[ , \PN, ...) in
# raw_offenders BEFORE cleaning, tagged with the suite that produced it, and run_all fails the run if any
# surfaced -- the net that catches a reader which should have called speak_clean.
#
# The list survives clear() on purpose. clear() resets the spoken log between assertions and some specs
# call it a dozen times, so wiping the offenders with it would leave the net holding only whatever the
# last few lines of each suite produced. It is emptied once per engine pass, by clear_all.
module SpeakCapture
  # Exactly the escapes clean() removes (core/speech/text.rb): the \x[..] and \PN family, and the eight
  # punctuation ones -- \. \! \| \^ \< \> \~ \\ -- which are RPG Maker's wait/instant codes and turn up in
  # fangame dialogue constantly. Watching only \<letter> meant a reader could hand speak a line full of
  # "\." and the net stayed quiet while the synthesizer read the backslashes out loud.
  RAW_CODE = /\\[A-Za-z.!|^<>~\\]/

  @log = []
  @raw_offenders = []

  # Replaces PokeAccess.speak with the recording version. Call once after the toolkit is loaded.
  def self.install
    log = @log
    raw = @raw_offenders
    PokeAccess.define_singleton_method(:speak) do |text, interrupt = true|
      raw.push([(Assert.suite rescue nil), text.to_s]) if text.to_s =~ RAW_CODE
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
