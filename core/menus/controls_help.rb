# The opening's controls help (ButtonEventScene): paragraphs are collected per screen as the scene registers them
# (addLabelForScreen, or addLabel from the gen-6 constructor) and read when that screen is put up. Key pictures
# from the same screen lead the paragraphs drawn beside them.
module PokeAccess
  module ControlsHelp
    # Stores one paragraph on the scene, under the screen it belongs to, with the height it is drawn at.
    def self.note(scene, number, text, y = nil)
      labels = (PokeAccess.ivar(scene, :@access_labels) || {})
      (labels[number] ||= []).push([text.to_s, y])
      scene.instance_variable_set(:@access_labels, labels)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Stores the name and height of a recognized key picture for its screen.
    def self.note_key(scene, number, y, file)
      key = picture_key(file)
      return if key.nil?
      keys = (PokeAccess.ivar(scene, :@access_keys) || {})
      (keys[number] ||= []).push([y.to_i, key])
      scene.instance_variable_set(:@access_keys, keys)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The key a help picture shows, as the player has it now: the arrows, or the letter its file is named after, through
    # KeyHints for a standard button the player may have moved; nil for any other picture.
    def self.picture_key(file)
      base = File.basename(file.to_s)
      return PokeAccess::I18n.t(:ctl_arrows) if base =~ /\AhelpArrowKeys\z/i
      return $1.upcase if base =~ /\Ahelp_(f(?:[1-9]|1[0-2]))\z/i
      return nil unless base =~ /\Ahelp([A-Z]\d*)key\z/i
      letter = $1.upcase
      PokeAccess::KeyHints.key(PokeAccess::KeyHints::RGSS_LETTERS[letter], letter)
    end

    # The screen's paragraphs, each led by the key whose picture is drawn nearest its height.
    # param rows the stored [text, height] paragraphs
    # param keys the stored [height, key] pictures, or nil
    def self.keyed(rows, keys)
      placed = (0...rows.length).select { |i| rows[i][1] }
      lead = {}
      (keys || []).each do |y, name|
        i = placed.min_by { |j| (rows[j][1].to_i - y).abs }
        lead[i] ||= name unless i.nil?
      end
      out = []
      rows.each_with_index { |r, i| out.push(lead[i] ? "#{lead[i]}: #{r[0]}" : r[0]) }
      out
    end

    # Speaks the paragraphs of the screen being put up, interrupting; a full stop joins two only where the first
    # lacks end punctuation.
    def self.say(scene, number)
      labels = PokeAccess.ivar(scene, :@access_labels)
      rows = labels ? labels[number] : nil
      return if rows.nil? || rows.empty?
      out = ""
      keys = PokeAccess.ivar(scene, :@access_keys)
      keyed(rows, keys && keys[number]).each do |r|
        t = r.to_s.strip
        next if t.empty?
        out += (out.empty? ? "" : (out =~ /[.!?:;]\z/ ? " " : ". ")) + t
      end
      PokeAccess.speak_clean(out, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("ButtonEventScene", :addLabelForScreen, :optional => true) do |scene, _r, args|
  PokeAccess::ControlsHelp.note(scene, args[0], args[4], args[2])
end

PokeAccess::Hooks.after_hook("ButtonEventScene", :set_up_screen, :optional => true) do |scene, _r, args|
  PokeAccess::ControlsHelp.say(scene, args[0])
end

# The gen-6 copy: addLabel(x, y, width, text) from the constructor, one screen; skipped where addLabelForScreen
# exists, since the modern copy's addLabelForScreen calls addLabel.
PokeAccess::Hooks.after_hook("ButtonEventScene", :addLabel, :optional => true) do |scene, _r, args|
  PokeAccess::ControlsHelp.note(scene, 1, args[3], args[1]) unless scene.respond_to?(:addLabelForScreen)
end

# A paged screen registers its pictures with the page number and their painted height.
PokeAccess::Hooks.after_hook("ButtonEventScene", :addImageForScreen, :optional => true) do |scene, _r, args|
  PokeAccess::ControlsHelp.note_key(scene, args[0], args[2], args[3])
end

# A legacy screen registers its pictures directly in the constructor.
PokeAccess::Hooks.after_hook("ButtonEventScene", :addImage, :optional => true) do |scene, _r, args|
  PokeAccess::ControlsHelp.note_key(scene, 1, args[1], args[2]) unless scene.respond_to?(:addImageForScreen)
end

# Speaks the gen-6 copy's screen once built. Around, not after: an after-hook would run the constructor under the
# reentrancy guard and drop the addLabel hooks as nested.
PokeAccess::Hooks.around_hook("ButtonEventScene", :initialize, :optional => true) do |scene, nxt, _a|
  nxt.call
  PokeAccess::ControlsHelp.say(scene, 1) unless scene.respond_to?(:set_up_screen)
end
