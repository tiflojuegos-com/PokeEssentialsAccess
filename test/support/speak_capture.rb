# Records what the mod would speak at voice_out, so every line still goes through the real speak (category,
# history, recorder) and specs assert the exact text the synthesizer would get. An uncleaned text also lands in
# raw_offenders, which fail the run; clear() keeps them, clear_all empties them once per engine pass.
module SpeakCapture
  # Every family clean() removes (core/speech/text.rb): backslash codes, markup tags, the bare pipe and control
  # bytes other than \t \n \r, which speak itself collapses.
  RAW_CODE = /\\[A-Za-z.!|^<>~\\]|<\/?[A-Za-z][^>]*>|\||[\x00-\x08\x0b\x0c\x0e-\x1f]/

  @log = []
  @raw_offenders = []

  # Records every line at voice_out instead of the reader, and checks the raw text speak receives (before its
  # whitespace collapse) for control codes. Call once after the toolkit is loaded.
  def self.install
    log = @log
    raw = @raw_offenders
    real_speak = PokeAccess.method(:speak)
    PokeAccess.define_singleton_method(:speak) do |text, interrupt = true, category = nil|
      raw.push([(Assert.suite rescue nil), text.to_s]) if text.to_s =~ RAW_CODE
      real_speak.call(text, interrupt, category)
    end
    PokeAccess.define_singleton_method(:voice_out) do |text, interrupt|
      log.push([text, interrupt])
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

# Runs the block with the game's _INTL answering the given translations, as a build in another language does (Royal's
# English one, through its translator), the stub's own _INTL put back afterwards.
def with_intl(map)
  Object.send(:alias_method, :pa_spec_intl, :_INTL)
  Object.send(:define_method, :_INTL) { |text, *args| pa_spec_intl(map[text] || text, *args) }
  Object.send(:private, :_INTL)
  yield
ensure
  Object.send(:alias_method, :_INTL, :pa_spec_intl)
  Object.send(:remove_method, :pa_spec_intl)
end

# The block's result at the three verbosity levels, [brief, medium, full], the scheme put back to full afterwards.
def vb_levels
  [:brief, :medium, :full].map do |level|
    PokeAccess::Config.verbosity = level
    yield
  end
ensure
  PokeAccess::Config.verbosity = :full
end
