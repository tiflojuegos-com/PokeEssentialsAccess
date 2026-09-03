module PokeAccess
  # Online play setup (Cable Club plugin). CableClub_Scene writes every line of the flow straight onto a
  # message-box sprite -- never through pbMessage -- so nothing the dialogue reader knows about is involved:
  # the question before a list, the status lines, and all the errors (invalid team, opponent disconnected,
  # outdated version, group full) were mute. The option lists themselves are Window_CommandPokemon and the
  # core menu hook already reads them, and the online battle runs on Battle::Scene, which the combat reader
  # covers.
  module AnilCableClub
    # A line the scene is about to put in the box. Read before it, because both writers then block or repaint
    # in a loop of their own.
    def self.say(text)
      PokeAccess.speak_clean(text, false)
    rescue StandardError
      nil
    end

    # The waiting line, which the frame update rewrites with one, two and three dots forever. Deduped on the
    # text without them, so the wait is announced once instead of three times a second.
    def self.waiting(scene, text)
      PokeAccess::Cursor.announce(scene, :cc_dots, text.to_s, false) { text.to_s }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("anil") do
  before("CableClub_Scene", :pbShowCommands) { |_s, args| PokeAccess::AnilCableClub.say(args[0]) }
  before("CableClub_Scene", :pbDisplay) do |s, args|
    PokeAccess::Cursor.reset(s, :cc_dots)
    PokeAccess::AnilCableClub.say(args[0])
  end
  before("CableClub_Scene", :pbDisplayDots) { |s, args| PokeAccess::AnilCableClub.waiting(s, args[0]) }
end
