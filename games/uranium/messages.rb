module PokeAccess
  # Uranium's system messages (Kernel.pbMessageDisplaySystem, behind Kernel.pbMessageSystem: trades, evolutions and
  # map events), read the way core reads pbMessageDisplay: paged or whole, one message level deeper while shown.
  module UraniumMessages
    # Shows one system message through the game's own display; args as pbMessageDisplaySystem takes them
    # (pos, msgwindow, message, letterbyletter, commandProc).
    def self.display(args, nxt)
      win = args[1]
      message = args[2]
      return nxt.call unless win && message.is_a?(String)
      paged = PokeAccess::DialoguePages.open(win, message, PokeAccess.letter_by_letter(args[3..-1] || []))
      PokeAccess.say_dialogue(message) unless paged
      PokeAccess.message_enter
      begin
        nxt.call
      ensure
        PokeAccess.message_leave
        PokeAccess::DialoguePages.close(win) if paged
      end
    end
  end
end

PokeAccess::Game.define("uranium") do
  kernel("pbMessageDisplaySystem", :around) { |args, nxt| PokeAccess::UraniumMessages.display(args, nxt) }
end
