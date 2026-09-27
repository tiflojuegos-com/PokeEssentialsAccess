module PokeAccess
  # The player's system language as a mod code, for the automatic language choice: mkxp-z's System.user_language,
  # else the Windows UI language (kernel32), else the POSIX locale variables. Asked once.
  module SystemLang
    # Windows primary language ids (the low ten bits of a LANGID, shared by every regional variant) to codes.
    LANGIDS = { 0x09 => :en, 0x0a => :es, 0x0c => :fr, 0x07 => :de, 0x16 => :pt, 0x15 => :pl,
                0x10 => :it, 0x11 => :ja, 0x12 => :ko, 0x04 => :zh, 0x19 => :ru, 0x13 => :nl,
                0x03 => :ca, 0x2d => :eu, 0x56 => :gl }

    # A system language the mod does not ship => the shipped one its speakers also read (Catalan => Spanish).
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
