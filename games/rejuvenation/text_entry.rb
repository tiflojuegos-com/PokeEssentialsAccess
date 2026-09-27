module PokeAccess
  # Rejuvenation's two entry screens of the Pokedex and PC searches (TextEntry.rb): the type pick (pbEnterTypes), two
  # reels that paint only a type's icon, chosen with up and down and swapped with left and right; and the bounded
  # text entry (pbEnterBoundedText), typed on the keyboard with up to five matches listed under it and the one picked
  # with up and down painted blue. Its keyboard window never calls the core's update, so the mod's keys stay held here.
  module RejuvEntry
    # A reel's type as the icon shows it, or the word for none on the second reel's blank.
    def self.type_word(reel)
      t = reel.selected
      t.nil? ? PokeAccess::I18n.t(:sum_none) : (PokeAccess::DataRV.type_name(t) || t.to_s)
    end

    # A reel with its number, as it is said when the cursor moves onto it.
    def self.reel_text(reel)
      PokeAccess::I18n.t(:rj_type_slot, :n => PokeAccess.ivar(reel, :@index).to_i + 1, :t => type_word(reel))
    end

    # The type pick as it opens: the question over the reels, the first reel and, while key hints are said, the help.
    def self.types_opening(scene)
      question = PokeAccess.clean((PokeAccess.sprite(scene, "entry").text rescue "").to_s)
      reel = PokeAccess.sprite(scene, "type1")
      help = PokeAccess.clean((PokeAccess.sprite(scene, "helpwindow").text rescue "").to_s)
      PokeAccess.sentences([question, reel ? reel_text(reel) : nil, PokeAccess::KeyHints.gate_sentences(help)])
    end

    # The matches under the typed text: how many there are and the first one.
    def self.matches_text(names)
      return nil if names.nil? || names.empty?
      PokeAccess::I18n.t(:rj_matches, :n => names.length, :first => PokeAccess.clean(names[0].to_s))
    end

    # The text entry as it opens: the question, the matches and, while key hints are said, the help.
    def self.entry_opening(scene, question)
      win = PokeAccess.sprite(scene, "entry")
      help = PokeAccess.clean((PokeAccess.sprite(scene, "helpwindow").text rescue "").to_s)
      PokeAccess.sentences([PokeAccess.clean(question.to_s), matches_text(PokeAccess.ivar(win, :@matchingnames)),
                            PokeAccess::KeyHints.gate_sentences(help)])
    end

    # Each frame of the keyboard window: holds the mod's keys while it is active, then says the picked match when up
    # or down moves it, or the matches left when a key changed them (queued behind the letter's echo).
    def self.follow(win)
      return unless (win.active rescue true)
      PokeAccess::Keys.typing!
      names = PokeAccess.ivar(win, :@matchingnames)
      hl = PokeAccess.ivar(win, :@highlightindex).to_i
      last_names = PokeAccess.ivar(win, :@access_rj_names)
      last_hl = PokeAccess.ivar(win, :@access_rj_hl)
      win.instance_variable_set(:@access_rj_names, names ? names.dup : nil)
      win.instance_variable_set(:@access_rj_hl, hl)
      return if last_names.nil?
      if hl > 0 && hl != last_hl && names
        pos = PokeAccess::I18n.t(:list_pos, :i => hl, :n => names.length)
        PokeAccess.speak("#{PokeAccess.clean(names[hl - 1].to_s)}, #{pos}", true)
      elsif names != last_names
        PokeAccess.speak(matches_text(names), false)
      end
    rescue StandardError => e
      PokeAccess.log_once("rj_entry", e)
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  after("PokemonTypeSelectionScreen", :pbStartScene, :optional => true) do |scene, _r, _a|
    PokeAccess.speak(PokeAccess::RejuvEntry.types_opening(scene), false)
  end

  after("PokemonTypeReel", :up, :optional => true) do |reel, _r, _a|
    PokeAccess.speak(PokeAccess::RejuvEntry.type_word(reel), true) if PokeAccess.ivar(reel, :@selected)
  end

  after("PokemonTypeReel", :down, :optional => true) do |reel, _r, _a|
    PokeAccess.speak(PokeAccess::RejuvEntry.type_word(reel), true) if PokeAccess.ivar(reel, :@selected)
  end

  after("PokemonTypeReel", :toggleSelect, :optional => true) do |reel, _r, _a|
    PokeAccess.speak(PokeAccess::RejuvEntry.reel_text(reel), true) if PokeAccess.ivar(reel, :@selected)
  end

  after("BoundedPokemonEntryScene", :pbStartScene, :optional => true) do |scene, _r, args|
    PokeAccess.speak(PokeAccess::RejuvEntry.entry_opening(scene, args[0]), false)
  end

  after("Window_BoundedTextEntry_Keyboard", :update, :optional => true, :hook_container => true) do |win, _r, _a|
    PokeAccess::RejuvEntry.follow(win)
  end
end
