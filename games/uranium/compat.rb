# Pokemon Uranium on mkxp-z. mkxp.json's preloadScript runs this file before the game's scripts (and before the mod's
# loader), to neutralize what the game loaded through its RPG Maker XP player and mkxp-z cannot run:
# - RGSS Linker (script 248) raises LoadError: its guard, Kernel's @RGSS_Linker, is set first.
# - FmodEx (script 249) needs RGSS Linker: its guard, Audio's @bgm_play, is set with the other saved natives, @library
#   and the volumes, as the game would; that guard also skips the game's volume wrappers, so they are put back here.
# - KleinBitmap.dll walks RGSS1 bitmap internals and rubyscreen.dll captures the RGSS player's window: every call into
#   them answers 0, so klein_bitmap_version is 0 and the stat animation never installs.
# - A script section Ruby 1.8.7 cannot compile (the developer tools, e.g. 253 GENERATE WIKI PAGES with a lookbehind
#   regex) would end the boot: mkxp-z evaluates each section through eval called on nil, so that call evaluates it at
#   top level and skips, noting it in accessibility/compat_skipped.txt, a section that does not compile.
# - The first-boot language picker (script 168, run by pbSetUpSystem while the scripts still load) comes before the
#   mod can speak: it takes the game language matching Windows' display language, English when none does. The game's
#   Options menu still opens the picker later.
# - FontInstaller.install (script 169, also before the mod) copies the game's fonts into Windows' and asks to restart:
#   mkxp-z draws only with its own fonts and the game's Fonts folder, so the game's install becomes a no-op.
module UraniumCompat
  # The DLLs whose calls answer 0 instead of running, by lowercase base name.
  NULL_DLLS = %w[kleinbitmap rubyscreen]

  # The Audio functions the game's FmodEx wrapper replaced, each with the volume it scaled by and the option read.
  PLAYS = [
    [:bgm_play, :@master_volume, :bgmvolume],
    [:bgs_play, :@sfx_volume, :sevolume],
    [:me_play, :@master_volume, :bgmvolume],
    [:se_play, :@sfx_volume, :sevolume]
  ]

  # Every Audio function the game's FmodEx block saves before replacing it.
  SAVED = [:bgm_play, :bgm_fade, :bgm_stop, :bgs_play, :bgs_fade, :bgs_stop, :me_play, :me_fade, :me_stop,
           :se_play, :se_stop]

  # A Win32API stand-in whose calls answer 0.
  class NullCall
    # Answers 0, whatever the arguments.
    def call(*args)
      0
    end

    alias_method :Call, :call
  end

  # True when the library named is one of NULL_DLLS, whatever its folder, case or extension.
  def self.null_dll?(name)
    NULL_DLLS.include?(File.basename(name.to_s).downcase.sub(/\.dll\z/, ""))
  end

  # The volume the game's FmodEx wrapper played at: the call's own, scaled by the global volume and by the option.
  def self.scaled(volume, global, option)
    v = volume * global / 100
    v *= ($PokemonSystem.send(option) / 100.0) if $PokemonSystem
    v.to_i
  end

  # Sets RGSS Linker's guard, so script 248 never loads the DLL.
  def self.skip_linker
    Kernel.instance_variable_set(:@RGSS_Linker, {}) unless Kernel.instance_variable_get(:@RGSS_Linker)
  end

  # Sets FmodEx's guard and state (the saved natives, a library other than FmodEx, both volumes at 100) and wraps the
  # play functions at the game's option volumes; once only, since an F12 reset runs this file again.
  def self.skip_fmodex
    Object.const_set(:FmodEx, Module.new) unless Object.const_defined?(:FmodEx)
    return if Audio.instance_variable_get(:@bgm_play)
    SAVED.each { |m| Audio.instance_variable_set("@#{m}", Audio.method(m)) }
    Audio.instance_variable_set(:@library, :mkxp)
    Audio.instance_variable_set(:@master_volume, 100)
    Audio.instance_variable_set(:@sfx_volume, 100)
    PLAYS.each { |meth, global, option| wrap_play(meth, global, option) }
  end

  # Replaces Audio.<meth> by its saved native at the volume scaled() gives.
  def self.wrap_play(meth, global, option)
    native = Audio.instance_variable_get("@#{meth}")
    (class << Audio; self; end).send(:define_method, meth) do |*args|
      args[1] = UraniumCompat.scaled(args.length > 1 ? args[1] : 100, Audio.instance_variable_get(global), option)
      native.call(*args)
    end
  end

  # Makes Win32API.new hand a NullCall for the NULL_DLLS; once only.
  def self.null_dlls
    return unless defined?(Win32API)
    meta = (class << Win32API; self; end)
    return if meta.method_defined?(:new__uranium_compat)
    meta.send(:alias_method, :new__uranium_compat, :new)
    meta.send(:define_method, :new) do |*args|
      UraniumCompat.null_dll?(args[0]) ? UraniumCompat::NullCall.new : new__uranium_compat(*args)
    end
  end

  # The game's message files by language code; any other language gets English (messages.dat).
  LANGUAGE_FILES = { "es" => "intl_spanish.dat", "pt" => "intl_portuguese.dat", "zh" => "intl_chinese.dat",
                     "fr" => "intl_french.dat", "de" => "intl_german.dat", "ko" => "intl_korean.dat",
                     "nl" => "intl_dutch.dat" }

  # Those codes by Windows primary language id (the low ten bits of a LANGID).
  LANGIDS = { 0x0a => "es", 0x16 => "pt", 0x04 => "zh", 0x0c => "fr", 0x07 => "de", 0x12 => "ko", 0x13 => "nl" }

  # What runs right after the script section of that name has been evaluated.
  AFTER_SECTION = { "Language Selection" => :auto_first_language }

  # The script sections skipped for not compiling, by the name mkxp-z gave them.
  def self.skipped
    @skipped ||= []
  end

  # Evaluates a script section at top level with its methods public, as mkxp-z's own call does (the game calls them
  # as Kernel.pbRgssOpen and the like), then its AFTER_SECTION step; one that does not compile is skipped and noted
  # instead of ending the boot. The public line goes as line 0, so the section keeps its own line numbers.
  def self.eval_section(src, scope, file)
    r = Kernel.eval("public\n" + src.to_s, scope || TOPLEVEL_BINDING, file || "(eval)", 0)
    after_section(file)
    r
  rescue SyntaxError => e
    skipped.push(file.to_s)
    note("accessibility/compat_skipped.txt", ["#{file}: #{e.message.to_s.split("\n").first}"], "a")
    nil
  end

  # Runs the AFTER_SECTION step of the section mkxp-z named file ("168:Language Selection"), if it has one; a failing
  # step is noted in accessibility/compat_error.txt and the boot goes on.
  def self.after_section(file)
    step = AFTER_SECTION[file.to_s.sub(/\A\d+:/, "").strip]
    send(step) if step
  rescue StandardError => e
    note("accessibility/compat_error.txt", ["#{file}: #{e.class}: #{e.message}"] + (e.backtrace || []).first(5), "a")
  end

  # Makes LanguageSelection#main answer the first-boot call with first_language instead of the picker; every other
  # call opens it as before. Rewrapped each time the section is evaluated, since that redefines main.
  def self.auto_first_language
    return unless defined?(::LanguageSelection)
    ::LanguageSelection.send(:alias_method, :main__uranium_compat, :main)
    ::LanguageSelection.send(:define_method, :main) do |*args|
      args[0] ? UraniumCompat.first_language : main__uranium_compat(*args)
    end
  end

  # Sets and loads the game language matching the player's, as the picker would, and answers its index.
  def self.first_language
    file = LANGUAGE_FILES[system_language.to_s] || "messages.dat"
    idx = LANGUAGES.index { |l| l[1] == file } || 0
    $PokemonSystem.language = idx
    pbLoadMessages("Data/" + LANGUAGES[idx][1])
    idx
  end

  # The player's two-letter language code in the order the mod asks (core/foundation/system_lang.rb): mkxp-z's
  # System.user_language, then Windows' display language; nil when neither is known.
  def self.system_language
    if defined?(::System) && ::System.respond_to?(:user_language)
      code = ::System.user_language.to_s[/\A[a-zA-Z]{2}/]
      return code.downcase if code
    end
    LANGIDS[system_langid & 0x3ff]
  rescue StandardError
    LANGIDS[system_langid & 0x3ff]
  end

  # Windows' display language id (a LANGID), or 0 when it cannot be read.
  def self.system_langid
    Win32API.new("kernel32", "GetUserDefaultUILanguage", "", "i").call.to_i
  rescue StandardError
    0
  end

  # Creates FontInstaller ahead of the game, so the install it defines later is replaced by a no-op at once.
  def self.skip_font_installer
    mod = Object.const_defined?(:FontInstaller) ? ::FontInstaller : Object.const_set(:FontInstaller, Module.new)
    meta = (class << mod; self; end)
    meta.send(:define_method, :singleton_method_added) do |name|
      if name == :install && !@uranium_compat_busy
        @uranium_compat_busy = true
        meta.send(:define_method, :install) { |*args| nil }
        @uranium_compat_busy = false
      end
    end
  end

  # Runs every neutralization; a failure is written to accessibility/compat_error.txt.
  def self.apply
    skip_linker
    skip_fmodex
    null_dlls
    skip_font_installer
  rescue StandardError => e
    note("accessibility/compat_error.txt", ["#{e.class}: #{e.message}"] + (e.backtrace || []).first(5), "w")
  end

  # Writes the lines to the file (mode "w" or "a"), silently when it cannot: nothing else is loaded yet to log it.
  def self.note(path, lines, mode)
    File.open(path, mode) { |f| f.write(lines.join("\n") + "\n") }
  rescue StandardError
    nil
  end
end

# mkxp-z calls eval on nil for each script section: only those calls land here, never an eval of the game's own.
class NilClass
  # Evaluates a script section through UraniumCompat.eval_section.
  def eval(*args)
    UraniumCompat.eval_section(args[0], args[1], args[2])
  end
end

UraniumCompat.apply
