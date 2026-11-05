# Ashen Frost's pictures, shown by its events: each case's title, typed letter by letter over dozens of pictures; the court's
# lives; the flying game's health and its start and end; the crossword; the letters and papers its cutscenes show; and a short
# description of the pictures with no words. Said as they come into sight, which many events leave for messages after they load
# one with opacity 0, and none through picture_texts: a picture left up as the flying game's Flying_Start is would hold the
# locator and the sounds as a menu of pictures (PictureCues.menu_showing?).
module PokeAccess
  module AshenPictures
    # The number of each title's picture, by the word in its file name, as the Case File names that case.
    CASE_WORDS = {
      "One" => 1, "Two" => 2, "Three" => 3, "Four" => 4, "Five" => 5, "Six" => 6, "Seven" => 7, "Eight" => 8, "Nine" => 9,
      "Ten" => 10, "Eleven" => 11, "Twelve" => 12, "Thirteen" => 13, "Fourteen" => 14, "Fifteen" => 15, "Sixteen" => 16,
      "Seventeen" => 17, "Eighteen" => 18, "Nineteen" => 19, "Twenty" => 20
    }
    # The titles whose last frame paints other words than the Case File's row, and the one it has no row for.
    PAINTED_TITLES = {
      "Case 3.5 (1)" => "Case Three-and-a-Half: Mordecai's Marvelous Misadventure",
      "Case Five (1)" => "Case Five: Lu³",
      "Case Six (1)" => "Case Six: Lafayettes, Lonardos, Palermos"
    }

    # The title as it is painted, or nil for a picture that is not a title's first letter.
    def self.case_title(name)
      return PAINTED_TITLES[name] if PAINTED_TITLES[name]
      word = name[/\ACase (\w+) \(1\)\z/, 1]
      number = word ? CASE_WORDS[word] : nil
      return nil unless number
      raw = (CaseUI_Menu_Scene.allocate.get_case_names(number) rescue nil)
      raw ? _INTL(raw) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A picture that shows a count: what it counts, by the file's name, or nil.
    def self.counter(name)
      case name
      when /\AFlying_Health(?:_\w+)?_(\d+)\z/ then PokeAccess::I18n.t(:ashen_fly_health, :n => $1.to_i)
      when /\AArturo's_Lives_(\d+)\z/ then PokeAccess::I18n.t(:ashen_court_lives, :n => $1.to_i)
      when /\AHP_Player_(\d+)\z/ then PokeAccess::I18n.t(:ashen_hp_player, :n => $1.to_i)
      when /\AHP_Girl_(\d+)\z/ then PokeAccess::I18n.t(:ashen_hp_girl, :n => $1.to_i)
      end
    end

    # Hart's picture of a choice his cutscenes play out on their own: its words, once, as its cursor moves over them.
    HART_CHOICES = {
      "Hart_1" => "Hart: Hm, what should I ask this surly guy? Want my autograph? I'll buy your office! Why is your face " \
                  "bandaged? Nothing!",
      "Hart_5" => "Hart: Lucile told me to keep my eyes peeled, after all. You seen a Lafayette? You look weary.",
      "Hart_A" => "Hart: What should I ask her? You're the culprit! Faked being a ghost, lately? You look suspicious!"
    }

    # What a picture paints or tells, whatever the verbosity: its words in the game's language, as a String; a key of lang/, or
    # [key, words] for one whose words are painted inside it. Frames of a series name the same entry, and only the one that
    # paints the whole of it is listed.
    SHOWN = {
      "Flying_Border" => "Mordecai + Fearow. Level: 1.",
      "Flying_Border_Rotom" => "Mordecai + Rotom. Level: 2.",
      "Flying_Border_Tropius" => "Help me. Level: Aaaaaaaah.",
      "Flying_Start" => "Start!",
      "Flying_Cleared" => "Cleared!",
      "Flying_Failed" => "Failed!",
      "Fin (3)" => "Fin",
      "End Demo (8)" => "End of demo",
      "End Demo (Bloody) (8)" => "End of demo",
      "Transition_Copper_Text" => "The Copper Ball",
      "First Job" => "First Job: Safety First",
      "Letter_1" => "Pascal,",
      "Letter_2" => "I am afraid.",
      "Letter_4" => "Your bro,",
      "Letter_5" => "Monty",
      "Kalvin's Letter" => PokeAccess::AshenDocuments::KALVIN_LETTER,
      "Serenity Letter" => PokeAccess::AshenDocuments::CLUE_TEXTS["serenityletter"],
      "clueagenda" => PokeAccess::AshenDocuments::CLUE_TEXTS["clueagenda"],
      "Crossword_0" => "Riverview Crossword",
      "Crossword_1" => "Riverview Crossword: Priya.",
      "Crossword_2" => "Riverview Crossword: Priya, Silva.",
      "Crossword_3" => "Riverview Crossword: Priya, Silva, Trebel.",
      "Crossword_4" => "Riverview Crossword: Priya, Silva, Trebel, Serenity.",
      "Crossword_5" => "Riverview Crossword: Priya, Silva, Trebel, Serenity, Lugia.",
      "Crossword_6" => "Riverview Crossword: Priya, Silva, Trebel, Serenity, Lugia, Skating.",
      "Analysis_8" => "Name: Guillermo del Tora, Mordecai. Sex: M. Age: 19. Occupation: Reoccurring Annoyance. Printsonfile?: True. " \
                      "Iscriminal?: True. Haswarrant?: False.",
      "Analysis_Alternate_8" => "Name: Mardoquedo \"Mordecai\" Flores Cabello. Sex: M. Age: 19. Occupation: ERROR. BILLIONARE IS NOT " \
                                "AN OCCUPATION. Printsonfile?: True. Iscriminal?: True.",
      "Analysis_Eyes_10" => "Subject ID: 03284. Sex: M. Age: 19. Regional Ethnicity: Hoenn. Eye Colour: Magenta. Eye Acuity: 20/20. " \
                            "Macula: Normal. Refraction: Above Average. Vitreous humor: Normal. Ispotentialdonor?: true.",
      "Analysis_Garbage (11)" => "Name: Mardoquedo \"Mordecai\" Flores Cabello. Sex: M. Age: 19. Occupation: ERROR. BILLIONARE IS NOT " \
                                 "AN OCCUPATION. Calculating Garbage Level... WARNING! WARNING! WARNING!",
      "Technology_1" => "Technology is incredible!",
      "Technology_2" => "Technology is incredible!",
      "Technology_3" => "The power of science is staggering!",
      "Technology_4" => "Technology is incredible!",
      "Arceus" => "'Arse'us. Hello cool.",
      "Cake" => "Rich Girl: Hey, you got the last slice of coffee cake.",
      "interview_text (5)" => "Serenity Inc",
      "Serenitymap_1" => [:ashen_pic_map_lab, "Serenity Inc."],
      "Serenitymap_2" => :ashen_pic_map_marks,
      "Escape_0" => :ashen_pic_inv_empty,
      "Escape_1" => :ashen_pic_inv_rolls,
      "Escape_2" => :ashen_pic_inv_pliers,
      "Escape_3" => :ashen_pic_inv_board,
      "Escape_Priya_0" => :ashen_pic_inv_empty,
      "Escape_Priya_1" => :ashen_pic_inv_hanger,
      "Escape_Priya_2" => :ashen_pic_inv_pick,
      "Escape_Priya_3" => :ashen_pic_inv_clothes,
      "Battle_1" => :ashen_pic_bars_full,
      "Battle_2" => :ashen_pic_bars_half,
      "Battle_3" => :ashen_pic_bars_low,
      "Battle_4" => :ashen_pic_bars_empty,
      "Culprit_0" => :ashen_pic_culprit_all,
      "Culprit_1" => [:ashen_pic_culprit_n, 1],
      "Culprit_2" => [:ashen_pic_culprit_n, 2],
      "Culprit_3" => [:ashen_pic_culprit_n, 3],
      "Culprit_4" => [:ashen_pic_culprit_n, 4]
    }

    # What the pictures with no words show, in a sentence, said with the verbosity's descriptions: a fade of one drawing names one
    # entry, so it is not said again as the frames change.
    DESCRIBED = {
      "Finding Body" => :ashen_pic_body,
      "Finding Body_2" => :ashen_pic_body_2,
      "Finding Body_3" => :ashen_pic_body_3,
      "Finding_Body_4" => :ashen_pic_body_4,
      "Falling" => :ashen_pic_falling,
      "Noose" => :ashen_pic_noose,
      "Picture_Research" => :ashen_picture_research,
      "Memory_Ambush" => :ashen_pic_memory_ambush,
      "Memory_Dark_Places" => :ashen_pic_memory_dark,
      "Memory_Fogdale_Winter" => :ashen_pic_lake_winter,
      "Memory__Fogdale_Spring" => :ashen_pic_lake_spring,
      "Memory_Luciano" => :ashen_pic_memory_luciano,
      "Memory_Penthouse" => :ashen_pic_memory_penthouse,
      "Memory_Smokey" => :ashen_pic_memory_smokey,
      "Memory_Spa" => :ashen_pic_memory_spa,
      "L_Memory_Mother" => :ashen_pic_memory_mother,
      "M_Memory_1" => :ashen_pic_m_memory_1,
      "M_Memory_2" => :ashen_pic_m_memory_2,
      "Mordecai_Recall_1" => :ashen_pic_recall_1,
      "Mordecai_Recall_2" => :ashen_pic_recall_2,
      "Mordecai_Recall_3" => :ashen_pic_recall_3,
      "Severn_1" => :ashen_pic_severn_1,
      "Severn_2" => :ashen_pic_severn_2,
      "Severn_Aerodactyl_1" => :ashen_pic_severn_aero_1,
      "Severn_Aerodactyl_2" => :ashen_pic_severn_aero_2,
      "Severn_Finneon" => :ashen_pic_severn_finneon,
      "Severn_Froslass" => :ashen_pic_severn_froslass,
      "Severn_Magcargo" => :ashen_pic_severn_magcargo,
      "Severn_Maractus_1" => :ashen_pic_severn_maractus_1,
      "Severn_Maractus_2" => :ashen_pic_severn_maractus_2,
      "Severn_Mothim" => :ashen_pic_severn_mothim,
      "Severn_Noctowl" => :ashen_pic_severn_noctowl,
      "Severn_Trubbish" => :ashen_pic_severn_trubbish,
      "Photo_Baby" => :ashen_pic_photo_baby,
      "Photo_Louis" => :ashen_pic_photo_louis,
      "Photo_Mafia" => :ashen_pic_board,
      "Photo_Southern" => :ashen_pic_photo_southern,
      "Photo_Sylvester" => :ashen_pic_photo_sylvester,
      "Photo_Violet_Combined" => :ashen_pic_photo_violet,
      "Evidence_Exes" => :ashen_pic_couple,
      "Trash PNG" => :ashen_pic_trash,
      "Portrait_Dipplin" => :ashen_pic_dipplin,
      "Quagsire" => :ashen_pic_quagsire,
      "Stakataka" => :ashen_pic_stakataka,
      "TV_Sparky" => [:ashen_pic_tv_sparky, "OP QR ST, U"],
      "Sylvesters Crazy Relative" => :ashen_pic_relative,
      "Young Mordecai_Blurry" => [:ashen_pic_young, "Lose it all!"],
      "Blur_Concussion" => :ashen_pic_blur_concussion,
      "Blur_Hospital" => :ashen_pic_blur_hospital,
      "Blur_Ice_Shard" => :ashen_pic_blur_ice,
      "Blur_Maze_House" => :ashen_pic_blur_maze,
      "Blade_Story_1" => :ashen_pic_blade_1,
      "Blade_Story_2" => :ashen_pic_blade_2,
      "Blade_Story_3" => :ashen_pic_blade_3,
      "Blade_Story_4" => :ashen_pic_blade_4,
      "Blade_Story_5" => :ashen_pic_blade_5,
      "Blade_Story_6" => :ashen_pic_blade_6,
      "Blade_Story_7" => [:ashen_pic_blade_7, "Lacey and Whiskers! Congratulations!"],
      "Blade_Story_8" => :ashen_pic_blade_8,
      "Call_Arturo" => :ashen_pic_call_arturo,
      "Call_Arturo_Office" => :ashen_pic_call_arturo_office,
      "Call_Bruce_Office_1" => :ashen_pic_call_bruce,
      "Call_Bruce_Office_2" => :ashen_pic_call_bruce,
      "Call_Bruce_Office_3" => :ashen_pic_call_bruce,
      "Call_Bruce_Office_4" => :ashen_pic_call_bruce_4,
      "Cleaner_1" => :ashen_pic_cleaner_1,
      "Cleaner_2" => :ashen_pic_cleaner_2,
      "Cleaner_3" => :ashen_pic_cleaner_3,
      "Cleaner_4" => :ashen_pic_cleaner_4,
      "Connection_1" => :ashen_pic_connection,
      "Dinner_1" => :ashen_pic_dinner_1,
      "Dinner_2" => :ashen_pic_dinner_2,
      "Dinner_3" => :ashen_pic_dinner_3,
      "Distrust" => :ashen_pic_distrust,
      "Donations_Mordecai" => :ashen_pic_donations_m,
      "Donations_Sylvester" => :ashen_pic_donations_s,
      "Eloise's Matchmaking" => :ashen_pic_eloise,
      "Friendship_Square_1" => :ashen_pic_square_1,
      "Friendship_Square_2" => :ashen_pic_square_2,
      "Friendship_Square_3" => :ashen_pic_square_3,
      "Friendships_1" => :ashen_pic_friendships,
      "Hide-n-Seek" => :ashen_pic_hide,
      "Hypothesis_1" => :ashen_pic_hypothesis_1,
      "Hypothesis_2" => :ashen_pic_hypothesis_2,
      "Hypothesis_3" => :ashen_pic_mural_grey,
      "Hypothesis_4" => :ashen_pic_hypothesis_4,
      "LafayetteInterview_1" => :ashen_pic_lafayette,
      "LafayetteInterview_2" => :ashen_pic_lafayette,
      "Listing_1" => :ashen_pic_listing_1,
      "Listing_2" => :ashen_pic_listing_2,
      "Listing_3" => :ashen_pic_listing_3,
      "Listing_4" => :ashen_pic_listing_4,
      "Listing_5" => :ashen_pic_listing_5,
      "Listing_6" => :ashen_pic_listing_6,
      "Listing_7" => :ashen_pic_listing_7,
      "Listing_8" => :ashen_pic_listing_8,
      "Listing_9" => :ashen_pic_listing_9,
      "Listing_10" => :ashen_pic_listing_10,
      "Lon_Interview_1" => :ashen_pic_lon,
      "Lon_Interview_2" => :ashen_pic_lon,
      "Rockruff_1" => :ashen_pic_rockruff_1,
      "Rockruff_2" => :ashen_pic_rockruff_2,
      "Rockruff_3" => :ashen_pic_rockruff_3,
      "Thinking_1" => :ashen_pic_thinking_1,
      "Thinking_2" => :ashen_pic_thinking_2,
      "Zapdos_Discussion_1" => :ashen_pic_zapdos_1,
      "Zapdos_Discussion_2" => :ashen_pic_zapdos_2,
      "Zapdos_Discussion_3" => :ashen_pic_zapdos_3,
      "Zapdos_Discussion_4" => :ashen_pic_zapdos_4,
      "AU_Mordecai" => :ashen_pic_au_mordecai,
      "AU_Fearow" => :ashen_pic_au_fearow,
      "AU_Introkids_3" => :ashen_pic_au_kids,
      "AU_Starter" => :ashen_pic_au_starter,
      "AU_Court_A" => :ashen_pic_au_court_a,
      "AU_Court_B" => :ashen_pic_au_court_b,
      "AU_Court_C" => :ashen_pic_au_court_c,
      "AU_Court_D" => :ashen_pic_au_court_d,
      "interview_1_m (1)" => :ashen_pic_interview_m,
      "interview_2_m (1)" => :ashen_pic_interview_m,
      "interview_1_f (2)" => :ashen_pic_interview_f,
      "interview_2_f (1)" => :ashen_pic_interview_f,
      "Static_A" => :ashen_pic_static,
      "Static_B" => :ashen_pic_static,
      "Cracks" => :ashen_pic_cracks,
      "Cut (1)" => :ashen_pic_cut,
      "Lightning (1)" => :ashen_pic_lightning,
      "Rings (1)" => :ashen_clue_rings
    }

    # The crossword of Ano's quiz (map 638), in the order Crossword_0 to Crossword_5 ask it (M638/E27/p3), with the help its entry
    # screen opens with: the word's number, the way it runs and its length, the letters the words already written give it, painted
    # in its cells, and the words it crosses still to be written.
    CROSSWORD = [
      { :help => "Actress", :word => 1, :way => :ashen_xw_down, :len => 5, :known => [], :shared => [[5, 2, :ashen_xw_across]] },
      { :help => "City Supervillain", :word => 2, :way => :ashen_xw_across, :len => 5, :known => [[5, "A"]], :shared => [[1, 2, :ashen_xw_down]] },
      { :help => "Mountain", :word => 3, :way => :ashen_xw_down, :len => 6, :known => [], :shared => [[3, 4, :ashen_xw_across]] },
      { :help => "Tech Company", :word => 4, :way => :ashen_xw_across, :len => 8, :known => [[2, "E"]], :shared => [[7, 2, :ashen_xw_down]] },
      { :help => "City Guardian", :word => 5, :way => :ashen_xw_across, :len => 5, :known => [], :shared => [[3, 2, :ashen_xw_down]] },
      { :help => "Winter Sport", :word => 2, :way => :ashen_xw_down, :len => 7, :known => [[1, "S"], [4, "T"], [7, "G"]], :shared => [] }
    ]

    # Whether this map has not shown this picture yet, the mark kept on the map.
    def self.first_on_map?(name)
      seen = $game_map.instance_variable_get(:@access_ashen_seen) || []
      return false if seen.include?(name)
      $game_map.instance_variable_set(:@access_ashen_seen, seen.dup.push(name))
      true
    end

    # An entry's words: a key with the words painted inside it, a key, or the painted words themselves.
    def self.words(entry)
      entry.is_a?(Array) ? PokeAccess::I18n.t(entry[0], :text => entry[1]) : PokeAccess::I18n.t(entry)
    end

    # A picture shown: said now if it can be seen, else kept on it for the move that brings it into sight.
    def self.showing(picture, args)
      name = args[0].to_s
      visible = visible?(args[6])
      picture.instance_variable_set(:@access_ashen_unseen, visible ? nil : name)
      shown(name) if visible
    end

    # A picture moved: one kept unseen is said as it starts to fade in, and a fade out ends what was said of it, as an erase does, for
    # the events that leave it faded and show it again (M756/E54 and E55).
    def self.moving(picture, args)
      unless visible?(args[6])
        @last_entry = nil
        return
      end
      name = picture.instance_variable_get(:@access_ashen_unseen)
      return unless name
      picture.instance_variable_set(:@access_ashen_unseen, nil)
      shown(name)
    end

    # Whether an opacity lets a picture be seen; a script that gives none leaves it whole.
    def self.visible?(opacity)
      opacity.nil? || opacity.to_f > 0
    end

    # Says the title, count or choices a picture shows, or what it paints and shows, once until a picture goes; all queued but
    # the title, which stands alone, so a line in the same frame is not cut.
    def self.shown(name)
      word_asked(name)
      title = case_title(name)
      return PokeAccess.speak(title, true) if title
      choice = HART_CHOICES[name]
      return PokeAccess.speak(choice, false) if choice && first_on_map?(name)
      line = counter(name)
      return PokeAccess.speak(line, false) if line
      entry = SHOWN[name] || (PokeAccess::Verbosity.descriptions? ? DESCRIBED[name] : nil)
      return if entry.nil? || entry == @last_entry
      @last_entry = entry
      PokeAccess.speak(words(entry), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A picture erased ends what was said of it, and what it would have said unseen: the same one shown again is said again.
    def self.erased(picture)
      picture.instance_variable_set(:@access_ashen_unseen, nil)
      @last_entry = nil
    end

    # The word a Crossword_N picture brings up, which its hint then describes, for the info key.
    def self.word_asked(name)
      n = name[/\ACrossword_(\d)\z/, 1]
      @word = CROSSWORD[n.to_i] if n
    end

    # The info key's line for the word being asked, from its picture to the end of its entry screen: on that screen the key types
    # its letter, as every mod key gives way to a text field (Keys.typing!), so this is before it, over the hint.
    def self.word_info
      @word ? crossword_line(@word) : nil
    end

    # The word's line off the info key: its screen has closed, or the game has reset.
    def self.word_closed; @word = nil; end

    # The entry screen of a code, around its opener; it gives the word up as it closes.
    def self.entry(args)
      entry_opened(args)
      yield
    ensure
      word_closed
    end

    # A word of the crossword as the entry screen opens, where the picture has faded: its place, length and letters, none of
    # them the answer. Any other code asked for this way paints as many blanks as it has letters.
    def self.entry_opened(args)
      word = CROSSWORD.find { |w| w[:help] == args[1] }
      PokeAccess.speak(word ? crossword_line(word) : PokeAccess::I18n.t(:ashen_letters, :n => args[3]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What the grid shows of a word: where it runs and how long it is, its letters already written and the crossings to come.
    def self.crossword_line(word)
      t = PokeAccess::I18n
      parts = [t.t(:ashen_xw_word, :n => word[:word], :way => t.t(word[:way]), :len => word[:len])]
      word[:known].each { |known| parts.push(t.t(:ashen_xw_known, :n => known[0], :c => known[1])) }
      word[:shared].each { |shared| parts.push(t.t(:ashen_xw_shared, :n => shared[0], :w => shared[1], :way => t.t(shared[2]))) }
      parts.join(" ")
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  after("Game_Picture", :show) { |picture, _ret, args| PokeAccess::AshenPictures.showing(picture, args) }
  after("Game_Picture", :move) { |picture, _ret, args| PokeAccess::AshenPictures.moving(picture, args) }
  after("Game_Picture", :erase) { |picture, _ret, _args| PokeAccess::AshenPictures.erased(picture) }
  kernel("passCheck", :around) { |args, nxt| PokeAccess::AshenPictures.entry(args) { nxt.call } }
  PokeAccess::Info.map_owner(:ashen_crossword) { PokeAccess::AshenPictures.word_info }
  PokeAccess::Caches.register(:ashen_crossword) { PokeAccess::AshenPictures.word_closed }
end
