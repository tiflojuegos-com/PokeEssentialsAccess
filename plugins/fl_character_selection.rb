# FL's Character Selection (CharacterSelection::Scene): sprites with no text but a title window; the title is said as it
# opens, and each cursor move says the character's name from its graphic file and its place in the list.
module PokeAccess
  module FLCharacterSelection
    # A character's name from a graphic file name: no folder or extension, no leading trainer-style stem, underscores as
    # spaces; nil when under two letters are left (a bare number or initial).
    def self.file_name(file)
      base = file.to_s.split(/[\\\/]/).last.to_s.sub(/\.[A-Za-z0-9]+\z/, "")
      base = base.sub(/\A(?:trainer|trchar|trback|char|character|player|npc)(?:[_\-]+|(?=\d))/i, "")
      text = base.gsub(/[_\-]+/, " ").strip
      text.gsub(/[\d\s.]/, "").length >= 2 ? text : nil
    end

    # The name of the character at index: its battle graphic's, else its overworld one's; nil when neither says one.
    def self.character_name(scene, index)
      [PokeAccess.ivar(scene, :@battle), PokeAccess.ivar(scene, :@overworld)].each do |files|
        name = files.is_a?(Array) ? file_name(files[index]) : nil
        return name if name
      end
      nil
    end

    # The focused character: its name and place in the list, or its place alone when no file names one readably.
    def self.entry(scene)
      index = PokeAccess.ivar(scene, :@index)
      files = PokeAccess.ivar(scene, :@overworld)
      return nil unless index.is_a?(Integer) && files.is_a?(Array) && !files.empty?
      name = character_name(scene, index)
      return PokeAccess::I18n.t(:charsel_slot, :n => index + 1, :tot => files.length) unless name
      PokeAccess::I18n.t(:list_entry, :name => name, :n => index + 1, :tot => files.length)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the title window's text as the scene opened, queued behind whatever brought it up.
    def self.opened(scene)
      box = PokeAccess.sprite(scene, "messagebox")
      t = box ? PokeAccess.clean((box.text rescue "").to_s) : ""
      PokeAccess.speak(t, false) unless t.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("CharacterSelection::Scene", :start, :optional => true) do |scene, nxt, _a|
  r = nxt.call
  PokeAccess::FLCharacterSelection.opened(scene)
  r
end

# The cursor is polled in the loop that waits for the keys; the first character is queued behind the title.
PokeAccess::SceneWatcher.reader("CharacterSelection::Scene", :main_loop, :charsel_cursor, :optional => true) do |scene|
  [PokeAccess.ivar(scene, :@index), lambda { PokeAccess::FLCharacterSelection.entry(scene) }]
end

# The confirmation's question is written on the title window; its Yes and No window is the one the mod already reads.
PokeAccess::Hooks.before_hook("CharacterSelection::Scene", :display_confirm, :optional => true) do |_scene, args|
  PokeAccess.say_screen_message(args)
end
