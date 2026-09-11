module PokeAccess
  # The language the player's system runs in, as one of the mod's codes, for the automatic language choice
  # when the game declares none of its own. Three sources in order, each optional: mkxp-z's own
  # System.user_language ("en_US") on the modern builds; the Windows user-interface language through
  # kernel32 on the 1.8.7 builds, which have no System module but load native functions the way audio3d
  # does; and the POSIX locale variables last. Asked once: it cannot change under a running game.
  module SystemLang
    # Windows primary language ids (the low ten bits of a LANGID) for the languages the mod ships or may.
    # The primary id is shared by every regional variant -- en-US, en-GB and en-AU are all 0x09, es-ES and
    # es-MX both 0x0a -- which is exactly the granularity the mod's files have.
    LANGIDS = { 0x09 => :en, 0x0a => :es, 0x0c => :fr, 0x07 => :de, 0x16 => :pt, 0x15 => :pl,
                0x10 => :it, 0x11 => :ja, 0x12 => :ko, 0x04 => :zh, 0x19 => :ru, 0x13 => :nl,
                0x03 => :ca, 0x2d => :eu, 0x56 => :gl }

    # A system language the mod does not ship, mapped to the shipped one its speakers live beside: a
    # Catalan, Basque or Galician Windows belongs to a player who reads Spanish, and Spanish is a better
    # guess for the mod's voice than whatever the game declares.
    NEIGHBOURS = { :ca => :es, :eu => :es, :gl => :es, :ast => :es }

    # The shipped neighbour of a system language code, or nil.
    def self.neighbour(code)
      code ? NEIGHBOURS[code] : nil
    end

    # The system's language code (:en, :es, ...), or nil when no source answers.
    def self.code
      return @code if @asked
      @asked = true
      @code = from_runtime || from_windows || from_env
    end

    # Forgets the answer, so the next call asks again (tests).
    def self.forget
      @asked = false
      @code = nil
    end

    def self.from_runtime
      return nil unless defined?(::System) && ::System.respond_to?(:user_language)
      parse(::System.user_language)
    rescue StandardError
      nil
    end

    def self.from_windows
      fn = (Win32API.new("kernel32", "GetUserDefaultUILanguage", [], "i") rescue nil)
      return nil unless fn
      id = fn.call.to_i
      id > 0 ? LANGIDS[id & 0x3ff] : nil
    rescue StandardError
      nil
    end

    def self.from_env
      v = ENV["LC_ALL"] || ENV["LC_MESSAGES"] || ENV["LANG"] || ENV["LANGUAGE"]
      v ? parse(v) : nil
    rescue StandardError
      nil
    end

    # "en_US.UTF-8", "es-ES" or "pt" to :en, :es, :pt; the "C" locale and blanks to nil.
    def self.parse(s)
      m = s.to_s.match(/\A([A-Za-z]{2,3})(?:[_\-.]|\z)/)
      return nil unless m
      c = m[1].downcase
      c == "c" ? nil : c.to_sym
    end
  end
end
