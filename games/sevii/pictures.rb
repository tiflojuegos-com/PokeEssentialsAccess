module PokeAccess
  # Text Sevii paints only in pictures, said from transcriptions of them: the load screen's background (loadbg_*) and
  # the credits roll (HGSS_CreditsScene, credits.png), a section at a time as it rises into view, then THE END.
  module SeviiPictures
    # What every loadbg_* paints: the title on its top band, the version on its bottom one.
    LOAD_BACKGROUND = "Pokémon HGSS: Sevii Islands. Version: Final 1.2.0"
    # The height of the roll's viewport: a line is in view once the roll's y plus its offset is under it.
    VIEW_HEIGHT = 384
    # credits.png's sections, top to bottom, as [the y of its first line in the picture, its lines as painted]: a
    # two-column row is two names, a heading ends in a colon; the dashed rules and the heading bullets are left out.
    ROLL = [
      [70, ["Pokémon HGSS: Sevii Islands"]],
      [198, ["CREDITS"]],
      [326, ["PurpleZaffre - Creator (FaperJr on PokéCommunity)"]],
      [486, ["Beta Testers:", "TechSkylander1518", "Fst", "AlolanIvysaur", "Foxowl", "NocTurn", "Brysoon", "madmanjr",
             "Trillzys", "ADP9295"]],
      [774, ["Mega Johto Starters", "Sprites and Concept:", "KajiAtsui", "Sprite Animations:", "Antiant"]],
      [1094, ["Music & Sounds:", "PurpleZaffre", "BlueJackG", "DJ_Reshiram", "Lohweo", "StevenMix", "Pokestir",
              "FalKKonE", "PokéMixr92", "Saxmast3r", "Brojito", "LukeeGD", "GRonnoc", "Smouv", "Zame", "pokemonags",
              "NintenSheet", "Nanashima", "BadSamaritan", "NightDefined", "KunningFox", "DKen2021", "Fakemon123", "Deo",
              "iteachvader", "Derek", "Eclairattack", "TGH", "Bliitzit", "LD3005", "Media Factory", "Overlap",
              "hnturs12", "Red6095", "Lumify", "Gil", "PokemonRater", "VGMusicMaker", "MC Bomber", "Dialga22239",
              "GaragebandPoke", "Qwert2", "DerxwnaKapsyla", "Jag 00", "Pokeli", "Mixeli", "Jobless Music",
              "Seiiccubus", "Trum Pit", "TeruTeruSky", "dialga328", "TurboShell", "Alpha Remaster", "Nullfuchs",
              "HappyDragonite", "niconico", "Eternal Sushi", "Morningdew", "Meeow's Music", "A.G. Zhark",
              "SoundsAreUs", "YoshiDude12", "Video Game Music Resources", "Shelmet - Olive Expert",
              "Lego Battles: Ninjago", "Jonas B. Ingebretsen", "Pokémon Remastered", "Pika! Productions",
              "KaiserLeospike", "Lightblade Absol", "HoopsandHipHop", "Altering Cave", "Pikachu Records",
              "Atlantic Records", "Cameron Cadima", "DrakeSycamore", "chrodlessmelody", "Kousei Uemura",
              "We are Magikarp!", "Shinji Miyazaki"]],
      [2822, ["Scripts:", "PurpleZaffre", "WolfPP", "Marin", "Mr. Gela", "KleinStudios", "Umbreon", "Zeus81", "Boonzeet",
              "Crystal Noel", "raZ", "NuriYuri", "Savordez", "Kyu", "avery", "Sichlor", "bo4p56787", "Pistis", "Michael",
              "Marcello", "Obito", "~JV~", "Clara", "Vendily", "Tustin2121", "cilerba", "-FL-", "BlackOutG5",
              "DekuSamurai", "Hansiec", "DL Kurosh", "SunakazeKun", "Lucidious89", "LostSoulsDev", "Deouen", "mej71",
              "Luka S.J.", "Mario Gamer", "YoshiCLONE", "Shiney570", "TheTrain2000", "dragonnite", "Zeak6464",
              "help-14", "Zingzags", "Venom12", "rayd12smitty", "Saving Raven", "thesuzerain", "BlackEternity",
              "Marty152", "Alaguesia", "Drimer", "Wichu", "Rot8er_ConeX", "NocTurn", "flylib.com", "Jaiden", "KK20",
              "Krom Stern", "ForeverZer0", "AiurJordan", "TiagoArraes", "Ganz/Webkinz", "Golisopod User",
              "TastyRedTomato", "DerxwnaKapsyla", "AtomicReactor", "TechSkylander1518"]],
      [4166, ["Tiles:", "PurpleZaffre", "Voltseon", "ENLS", "AnonAlpaca", "LuxDiablo", "KennyCatches", "Pira",
              "KingTapir", "xDinky", "Gaia Project", "Diegotoon20", "Keh-Ven", "Phyromatical", "Cilerba", "Akizakura16",
              "the red ex", "19dante19", "zlolxd", "Lemon", "gigatom", "Calis", "Alistair", "flurmimon", "crocovyle",
              "thegreatblaid", "princessmagic", "rayd12smitty", "leilou", "Crazyninjaguy", "Gallanty", "Zeak6464",
              "yourii54", "DonLawride", "Mr. Gela", "Thunderdove", "EternalTakai", "SpartaLazor", "Tsuka", "Iametrine",
              "Gamershow", "Kimotonian", "Godofthesky", "Light-PA", "LilaTraube", "Zeo", "RedKnightX", "WilliamGJ",
              "EVoLiNa", "NSora-96", "BoOmxBiG", "ThatsSoWitty", "sagaxxy", "EpicDay", "warox1994", "zerudez",
              "Zeo254", "help-14", "thurpok", "Advance Tileset", "Warpras", "Professorverno", "MoonTIK",
              "spaceemotion", "Naokohiro", "Kaliser", "Rayquaza-dot", "Manuxd789", "Rossay", "WesleyFG", "xAlien95",
              "LotusKing", "DarkDragoon", "UltimoSpriter", "Speedialga", "CrimsonTakai", "Aigue--Marine", "EpicDay",
              "kaitoooo", "Magiscarf", "peekychew", "CNickC", "Alucus", "Kyledove", "Dewitty", "CNC", "zetavares852",
              "Lightbulb15", "JayLuxray", "Droid779", "princess-phoenix", "TyranitarDark", "UltimateTraveler",
              "Hek-el-grande", "MrBlueOctober", "MinorThreat0987", "Ulithium_Dragon", "WilsonScarloxy",
              "Kizemaru-Kurunosuke", "Heartlessdragoon", "FloofyPanthar", "Neo-Spriteman", "princelegendario",
              "chimcharsfireworkd", "ChaoticCherryCake", "Heavy-Metal-Lover"]],
      [6278, ["Overworlds Characters:", "PurpleZaffre", "chasemortier", "Dewitty", "Kimotonian", "Chocosrawloid",
              "milomilotic11", "Brawlzilla", "Neo-Spriteman"]],
      [6694, ["Overworld Pokémon", "PurpleZaffre", "SageDeoxys", "Wolfang62", "DarkusShadow", "tammyclaydon",
              "Larryturbo", "Kidkatt", "help-14", "csandoval", "2and2makes5", "MissingLukey", "Zyon17", "Kimotonian",
              "cSc-A7X", "LunarDusk", "Fernandojl", "Silver-Skies", "TyranitarDark", "Getsuei-H", "Kid1513",
              "Gallanty", "Kyt666", "kdiamo11", "Pokegirl4ever", "Syledude", "Gizamimi-Pichu", "milomilotic11",
              "princessphoenix", "Ezerart", "Chocosrawlooid", "Azria"]],
      [7366, ["Alolan, Galarian, Hisuian, Paldean, Paradox, Mega & Gigantamax Pokémon Sprites:", "PurpleZaffre",
              "www.smogon.com", "Arkeis", "Farriella", "TrainerSplash", "Layell", "Noscium", "Glustora", "doomchaos",
              "Luigi Player", "Dleep", "Siiilver", "Snivy101", "Speed-X", "Sleet", "RedRooster", "Quanyails", "aXl",
              "Turtleye", "Wobblebuns", "Bynine", "TeraVolt", "Wyverii", "Mos_Quitoxe", "viperdk1", "Kalalokki",
              "Kyuzeth", "Arhops", "WPS", "Brylark", "leparagon", "ThatChar", "Branflakes325", "Mak", "goldenbanana",
              "Azria", "ezerart", "OldSoulja", "Caruban", "Katten", "jinxed", "MallowOut", "NoelleMBrooks", "Spinda94",
              "MCH4R1Z4RD", "Tpick2211", "PomPomKing", "Diegotoon20", "Typhlito", "Iametrine", "elcheeso",
              "paintseagull", "Blaquaza", "lennybitao", "kiriaura", "Tinkatooni", "Galifia", "Harrie", "Seiku",
              "GeoisEvil", "FlorianDX", "DanEX", "SelenaFF", "arinoelle", "Ice-cold Claws", "G.E.Z.", "TheCynicalPoet",
              "HM100", "N-Kin", "fishbowlsoul90", "SelenaArmorclaw", "SpheX", "Zermonious", "hexagonereal", "Elena",
              "princessofmusic", "Gnowmowlady", "cyrecyri", "Gardow", "PixelLlamaArt", "Antiant", "Corson", "Turtleye",
              "AMVictory", "TheAetherPlayer", "uppa", "mangalos180", "RetroNC", "HyperactiveFlummi",
              "KingOfThe-X-Roads", "Mashirosakura", "Trainer Guigo", "hellfire0raptor", "CoolStoryBoat",
              "ThatGuyYouKnow", "Tyrell D. Barnes", "princess-phoenix", "RadicalCharizard", "Legitimate Username"]],
      [9382, ["Other Graphics:", "PurpleZaffre", "Voltseon", "ENLS", "Akizakura16", "Deo", "Akuma Tsubasa",
              "Mario Gamer", "Rune", "YoshiCLONE", "Erassus", "Eli", "Brom", "Overwordly", "ArtpopTrainer", "Zenionith",
              "Richard PT", "RBRNNova", "Glench", "ARandomRiver", "NX-Kun", "Lemon", "SpartaLazor", "Tricko1",
              "shivanking", "Mucrush", "virizion66", "Nephae", "TiniVi", "HyperTurtle32", "xMachaku", "Ploaj",
              "Valtoma", "PoLlOrOn", "Chidoridude55", "Raven", "Beliot419", "Phoenix-849", "Alaguesia", "Marin",
              "MapleBranchWing", "spaceemotion", "LarryTurbo", "DMN666", "Sylv", "leparagon", "MasterVictini",
              "IceJKai", "Drawn to Life", "char1cific", "AnonAlpaca", "hyo-oppa", "Pokecrator", "LuigiTKO",
              "vg-resource.com", "Mykala Tchaeschke", "PhoenixOfLight92"]],
      [10502, ["Cable Club (Online Connectivity):", "Vendily, mGriffin & Khaikaa"]],
      [10724, ["EBS (Elite Battle System):", "Sprites:", "GameFreak", "Pokecheck.org", "Luka S.J.", "PinkCatDragon",
               "redblueyellow", "Battle Backgrounds:", "lilatraube", "Eli", "Custom UI:", "Luka S.J.",
               "Sound Effects:", "GameFreak", "BadSamaritan"]],
      [11206, ["Pokémon Essentials was created by:", "Flameguru", "Poccil (Peter O.)", "Maruno",
               "With contributions from:", "Venom12", "Luka S.J.", "Boushy", "MiDas Mike", "Brother1440", "Popper",
               "FL.", "PinkMan", "Harshboy", "Rataime", "help-14", "SoundSpawn", "IceGod64", "the__end",
               "KitsuneKouta", "Wachunga", "Lisa Anthony", "xLeD", "Genzai Kawakami", "Near Fantastica",
               "AvatarMonkeyKirby", "Jacob O. Wobbrock", "and everyone else who helped out!"]],
      [12006, ["RPG Maker XP by:", "Enterbrain"]],
      [12166, ["Pokémon is owned by:", "The Pokémon Company", "Nintendo", "Affiliated with Game Freak"]],
      [12390, ["This is a non-profit fan-made game. No copyright infringements intended. Please support the official " \
               "games!"]],
      [12646, ["A special thank you to everyone from the Relic Castle/Eevee Expo community!"]],
      [12868, ["And thank YOU for playing!"]]
    ]
    # What the_end3 and the_end4 paint between them once the roll is over.
    THE_END = "THE END"

    # A section's lines as one reading: its title, then each heading running into the names under it, listed.
    def self.reading(lines)
      out = ""
      lines.each_with_index do |l, i|
        out << (lines[i - 1] =~ /:\z/ ? " " : ((i == 1 || l =~ /:\z/) ? ". " : ", ")) if i > 0
        out << l
      end
      out
    end

    # Says, queued, each section of the roll whose first line has come into view since the last frame, then THE END
    # once it shows; a roll that is gone says nothing more.
    def self.tick(scene)
      roll = PokeAccess.sprite(scene, "credits")
      if roll && !roll.disposed?
        seen = ROLL.count { |top, _lines| roll.y + top < VIEW_HEIGHT }
        said = PokeAccess::Cursor.current(scene, :sv_credits).to_i
        ROLL[said...seen].each { |_top, lines| PokeAccess.speak(reading(lines), false) } if seen > said
        PokeAccess::Cursor.changed?(scene, :sv_credits, seen)
      end
      return unless PokeAccess.sprite(scene, "End")
      PokeAccess.speak(THE_END, false) if PokeAccess::Cursor.changed?(scene, :sv_credits_end, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("sevii") do
  # The background is the first thing pbStartScene draws, before the panels the core reads after it.
  before("PokemonLoadScene", :pbStartScene) do |_s, _a|
    PokeAccess.speak(PokeAccess::SeviiPictures::LOAD_BACKGROUND, false)
  end

  # The credits are a user sprite of the map, updated every frame; the roll rises a little on each one.
  before("HGSS_CreditsScene", :update) { |scene, _a| PokeAccess::SeviiPictures.tick(scene) }
end
