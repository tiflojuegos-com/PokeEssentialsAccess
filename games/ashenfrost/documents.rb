# Ashen Frost's documents, all pictures: the clues the evidence screen examines (Graphics/Evidence/Clues), the newspapers and
# letters (005_Case13Images.rb, 006_Case14Images.rb, 008_Case16Images.rb), the sheet music (012_SheetMusicImages.rb) and the
# plates (016_PlateImages.rb, whose text a message says). The words are the pictures', transcribed in the game's language;
# a picture with none has a short description.
module PokeAccess
  module AshenDocuments
    # What each clue's picture says, by the file's name.
    CLUE_TEXTS = {
      "autopsyreport" => "Species: Rockruff. Cause of Death: Drowning. ETD: Evening.",
      "clueagenda" => "Sammy and Jade's Schedule. 09:00-10:00: Get costumes, meet caterer. 10:00-10:30: Go to Priya's Condo. " \
                      "10:30-11:30: Give actresses costumes. 11:30: Tea and social.",
      "cluebook" => "Chapter 5: Pokémon and Alzheimer's. People who have Alzheimer's may own Pokémon, and care responsibilities " \
                    "towards them. It can be difficult to explain to them what is happening to their trainer. Sometimes to " \
                    "the extent that they no longer remember their Pokémon.",
      "cluecard" => "To: Beatrice. Happy 8.5th Birthday! Love: Grandpa.",
      "cluecourier" => "Louis Rosewell: P&W's. Madeline Archer: Courthouse. Benjamin Wexter: Docks. Elmer Patterson: Factory.",
      "cluejournal" => "March 17th. It started out as a perfectly normal day; I handled the usual snot-nosed brats coming in to " \
                       "check up on their worthless, near-untrainable Pokémon, and the weirdos obsessed with breeding. No " \
                       "matter how many additional shifts I pick up at work, I still wind up stuck volunteering here, at the " \
                       "Daycare. I was just checking on the eggs when he showed up. Another one of those moronic Lonardo " \
                       "gangsters. I'd already dealt with three in the past: two men, one woman. I pepper sprayed the first " \
                       "lout they sent and tazed the second. The woman was clearly the smartest of the bunch, which is why I " \
                       "dug a pit above the door mat for her to fall into. Anyway, the latest gangster went into the usual " \
                       "spiel about the Daycare. I had Mightyena sic him, and we battled. In our ensuing battle, we wound up " \
                       "destroying a good portion of the Daycare. It was a draw. I lost my bow at some point, and the gangster " \
                       "picked it up. He tried to use it as leverage to learn my name. But the idiot didn't know how fast my " \
                       "reflexes were, and I took it back. He was brutish, and a terrible, awful flirt. But amidst all the " \
                       "wreckage, something changed. I realized we both had our ambitions, and the ruthless drive to reach " \
                       "them. Then the fluttery feelings I did have went away when I realized I would have to clean up the " \
                       "Daycare again.",
      "cluelafayette" => "Olde Riverviewe Archives File - 3467. The Lafayettes were once the ruling crime family of Riverview " \
                         "City. They started out with small operations, mostly centered around bootlegging. Their sarsparilla " \
                         "drink production made it easy to disguise then illegal beverages as legitimate. The Lafayettes then " \
                         "dug a network of tunnels and hideaways on and around their property to transport illicit goods. Some " \
                         "historians believe that the Lafayettes gave up on crime because Prohibition ended and their drinks " \
                         "were therefore not as profitable. Economic data does not support this argument, as alcohol " \
                         "consumption remained high post-prohibition. The historically-accepted reason is that the Lafayettes " \
                         "renounced their empire after they witnessed the destruction and corruption Silva Lafayette caused. " \
                         "Economics aside, some historians assert the latter interpretation is propaganda the family put out " \
                         "to erase their old image in the collective conscience of Riverviewites.",
      "clueletter" => "Pascal, I am afraid. I am afraid that after learning what I have, something might happen to me. I've never " \
                      "approved of your involvement with the Lonardos, and you've never liked my distrust of them. Then I went " \
                      "and joined up with them anyway, and we fought. I know I seemed like a hypocrite, but I did it for a " \
                      "reason. Lucile doesn't care about anyone but herself, and I can prove it. Your charge isn't the " \
                      "Lonardo's daughter. She's the Rosewell's. I ran a DNA test, and the test results came back negative. " \
                      "I've given you a copy for proof. I didn't know who would've bothered with saving her from the fire, let " \
                      "alone take her in under a different name, at first. And so I had to investigate further. I think I'm " \
                      "approaching the reason, but I can't be certain. They didn't hire a bodyguard because they're worried " \
                      "about her safety. The Lonardos are afraid of losing their hostage. I don't think my inquiries have gone " \
                      "unnoticed. The Lonardos have eyes everywhere in Riverview, and they'll realize what I am. Do what you " \
                      "will with this information, because something tells me I won't get the chance. We might never talk " \
                      "again, either because I'll move from Riverview, or Lucile will find me. So I want to give you these " \
                      "rings the Don gave to me. Propose to your girlfriend already, you hear? Your bro, Monty.",
      "cluelist" => "1. PEW's? 2. Lawyer's? 3. Lulu's? 4. Bolt.",
      "cluepatent" => "RE: Patent 251730. Felicia, I've forwarded you the paperwork to get the patent request started up. I've " \
                      "included the verification data from the outside testers like you asked me to. Let me know if there's " \
                      "anything else I can my provide. Bruce mentioned to me that the legal team will be in contact with you " \
                      "once they're back from their conference. Things should run a little more smoothly once they've " \
                      "returned. Thank-you, Neon. Serenity Marine Facility Branch Manager, Duchampe Gardens.",
      "cluepost" => "Lucy, Here we are in Johto! We locked Nie in a well full of Slowpoke. It was funny. Keep it real, Lus. " \
                    "Luciano Meri, 84 Aurora Street, Riverview City, RV5 289.",
      "cluereceipt" => "Save at Safe Safe's Safes! Shopping District, Riverview City. Your Purchases Today: LRG IND SFE, 9,967.32. " \
                       "Tax Rate, Tax Amount. Tax 1, 7%, 1423.90.",
      "cluesilva" => "Olde Riverviewe Archives File - 6970. Silva Lafayette is arguably one of the most notorious members of the " \
                     "family. He was Riverview's third Chief of Police, and chosen by Moltres to become the new head of the " \
                     "Lafayette family. Silva is best known for attempting to bring eternal summer to Riverview City. The " \
                     "Lafayettes, being sarsaparilla farmers and loggers, would benefit greatly from this climate change. As " \
                     "the Lafayettes immigrated to Riverview, then known as [REDACTED], from Sinnoh, it made sense that Silva " \
                     "would look towards Arceus for assistance. While Silva did succeed in calling upon the Alpha Pokémon, his " \
                     "mission went horribly awry from there. Silva was burned to death by the Alpha Pokémon. Information on " \
                     "Silva Lafayette was once limited to a handful of facts: he was married to Katerina Flores, a member to " \
                     "a minor cadet branch of the Flores. Together they had three children. Maisey, the eldest, is the current " \
                     "matriarch of the family. Silva was also known for being a fan of lawn bowling. Although contemporary " \
                     "Lafayettes still fiercely work to prevent anyone from viewing Silva Lafayette in a heroic light, they " \
                     "have been more willing to share information about him. They have even sponsored a documentary about " \
                     "his life.",
      "serenityletter" => "Iodine, This is your final warning. Keep your head down and stay out of trouble. We cannot afford " \
                          "another scandal surrounding our latest breakthrough. Bruce Serenity."
    }

    # What a clue's picture shows but does not write, added to its words.
    CLUE_NOTES = { "cluelist" => :ashen_clue_crossed }

    # What the clues with no words show, by the file's name.
    CLUE_VIEWS = {
      "clueapron" => :ashen_clue_apron, "cluebox" => :ashen_clue_box, "cluedoor" => :ashen_clue_door,
      "clueemblem" => :ashen_clue_emblem, "cluefight" => :ashen_clue_fight, "clueloui" => :ashen_pic_photo_louis,
      "cluesafe" => :ashen_clue_safe, "cluesalt" => :ashen_clue_salt, "cluesandbag" => :ashen_clue_sandbag,
      "cluescissors" => :ashen_clue_scissors, "cluetable" => :ashen_clue_table, "cluetorch" => :ashen_clue_torch,
      "gradphoto" => :ashen_clue_grad, "cluephoto" => :ashen_pic_couple, "clueboard" => :ashen_pic_board,
      "cluefloor" => :ashen_clue_floor, "cluerings2" => :ashen_clue_rings, "cluetile" => :ashen_clue_mural
    }

    # The newspaper pages Case 13 turns through and those the later cases hand over.
    NEWSPAPER_1 = "Riverview This Week. FLORES TRIAL SHAM. Lonardos set up false charges. Infamous Lawyer Defends Flores. Arturo " \
                  "Sullivan, one of Riverview City's most notorious attorneys, returned from his self-imposed exile in the Hoenn " \
                  "Region. Sullivan fled the city nearly two decades ago, fearing retaliation"
    NEWSPAPER_2 = "The Severn Comet. POLICE CHIEF MOB DON! City Council to vote on firing him! Long-time Chief of Police Leonardo " \
                  "Valconi (né Lonardo) was revealed in court to be the current head of the Lonardo family. Valconi (as we shall " \
                  "continue to refer to him) is the younger brother of the late Raphael Lonardo. Raphael himself died a year ago " \
                  "under mysterious"
    NEWSPAPER_3 = "The Daily Pelipper. VOTE TO FIRE VALCONI FAILS. City Council decision close at 7 to 6. After a series of " \
                  "meetings, City Council elected not to fire Chief Valconi. The spokeperson for the pro-Valconi side, Mlle. Amélie " \
                  "Duchampe, argued that, \"Riverview operates under the principle of reasonable doubt. There is no conclusive " \
                  "evidence to suggest that Leonardo has participated in"
    NEWSPAPER_4 = "The Sunday Scolipede. FIGHT ON THE ROOFTOP. Flores and Lonardo duke it out in Beacon Plaza. Sudden changes in " \
                  "the weather were noted in Beacon Plaza. There were on and off thunderstorms"
    KALVIN_LETTER = "I can't do it anymore, I can't keep juggling these responsibilities. I never wanted this. I never wanted you."

    CASE13_PAGES = { 1 => NEWSPAPER_1, 2 => NEWSPAPER_2, 3 => NEWSPAPER_3 }

    # The screens with one picture: their words and the button that closes them, as each scene sets its trigger.
    SINGLE = { "Case14Images" => NEWSPAPER_4, "Case16Images" => KALVIN_LETTER }

    # The notes each sheet paints, as the arrows of the songs table in Ocarina.rb, which its colours follow.
    SHEETS = {
      "SongRed" => [:up, :right, :right, :down],
      "SongOrange" => [:up, :left, :right, :left],
      "SongYellow" => [:up, :up, :right, :left],
      "SongGreen" => [:left, :down, :right, :down],
      "SongBlue" => [:left, :down, :right, :left],
      "Pianoconfig_A" => [:up, :right, :right, :down, :left, :left],
      "Pianoconfig_B" => [:left, :left, :down, :right, :right, :down],
      "Pianoconfig_C" => [:down, :down, :right, :right, :up, :right],
      "Pianoconfig_D" => [:up, :right, :right, :down, :left, :down, :down, :right, :right, :up, :right],
      "Pianoconfig_8" => [:left, :down, :down, :down, :left, :right, :down, :right, :up, :right]
    }

    # The picture of a clue, said as it is examined: its words, or what it shows; nil for one the tables do not know.
    def self.clue(name)
      file = name.to_s.downcase
      note = CLUE_NOTES[file]
      return "#{CLUE_TEXTS[file]} #{PokeAccess::I18n.t(note)}" if note
      return CLUE_TEXTS[file] if CLUE_TEXTS[file]
      key = CLUE_VIEWS[file]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # A sheet's notes in words, under the title it paints.
    def self.sheet(notes)
      "Play Along! #{notes.map { |n| PokeAccess::I18n.t("dir_#{n}".to_sym) }.join(', ')}"
    end

    # Says a document with its key, on the info key too until the next line.
    def self.say(text, hint)
      PokeAccess::Info.set_info(:text, text, text)
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(text, hint), true)
    end

    # The hint of the button that closes a document.
    def self.close_hint(sym, painted)
      PokeAccess::I18n.t(:ashen_doc_close, :key => PokeAccess::KeyHints.key(sym, painted))
    end

    # What pbEventScreen opens: a newspaper or letter closes with USE; a sheet of music or a plate, with BACK.
    def self.opened(cls)
      name = cls.to_s
      return say(SINGLE[name], close_hint(:c, "C")) if SINGLE[name]
      return say(sheet(SHEETS[name]), close_hint(:b, "X")) if SHEETS[name]
      plate(name)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A plate says its words as a message of its own; only the button that closes it is added, queued behind it.
    def self.plate(name)
      return unless name =~ /\APlate/ && PokeAccess::Verbosity.hints?
      PokeAccess.after_next_line(close_hint(:b, "X"))
    end

    # Case 13's newspaper, one page per USE, which turns it until the last closes it (pbOnScreenEnd).
    def self.page(number)
      text = CASE13_PAGES[number]
      return unless text
      turns = number < CASE13_PAGES.length
      say(text, turns ? PokeAccess::I18n.t(:ashen_doc_next, :key => PokeAccess::KeyHints.key(:c, "C")) : close_hint(:c, "C"))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  kernel("pbEventScreen", :before) { |args, _r| PokeAccess::AshenDocuments.opened(args[0]) }
  before("Case13Images", :set_up_screen) { |_scene, args| PokeAccess::AshenDocuments.page(args[0]) }
  %w[Case13Images Case14Images Case16Images SongRed SongOrange SongYellow SongGreen SongBlue Pianoconfig_A Pianoconfig_B
     Pianoconfig_C Pianoconfig_D Pianoconfig_8].each { |cname| clear_info_on(cname, :pbOnScreenEnd) }
end
