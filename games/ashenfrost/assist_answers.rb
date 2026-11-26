# What the puzzle assist says at two entry screens of Ashen Frost's own: the word passCheck waits for (its first
# argument) and the melody pbCallFlute waits for (a song of the table kept in Ocarina.rb).
module PokeAccess
  module AshenAssistAnswers
    # The sheet each song of Ocarina.rb's table is painted on, by its place in the table; AshenDocuments::SHEETS has the
    # notes.
    SONGS = %w[Pianoconfig_A Pianoconfig_B Pianoconfig_C SongRed SongOrange SongYellow SongGreen SongBlue Pianoconfig_D
               Pianoconfig_8]

    # Says the word a passCheck call takes, queued before its entry screen's own line; assist only.
    def self.word(args)
      return unless PokeAccess::Puzzles.assist?
      PokeAccess.speak(PokeAccess::I18n.t(:puzzle_answer, :a => args[0].to_s), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The notes of a song of the table in words, or nil for one it does not hold.
    def self.melody(n)
      notes = PokeAccess::AshenDocuments::SHEETS[SONGS[n.to_i]]
      notes ? notes.map { |note| PokeAccess::I18n.t("dir_#{note}".to_sym) }.join(", ") : nil
    end

    # Says the melody pbCallFlute opens the ocarina for, queued before the screen's own line; assist only.
    def self.song(args)
      return unless PokeAccess::Puzzles.assist?
      notes = melody(args[0])
      PokeAccess.speak(PokeAccess::I18n.t(:puzzle_answer, :a => notes), false) if notes
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  kernel("passCheck", :before) { |args, _r| PokeAccess::AshenAssistAnswers.word(args) }
  kernel("pbCallFlute", :before) { |args, _r| PokeAccess::AshenAssistAnswers.song(args) }
end
