# Ashen Frost's glasses in Fogdale's inn (map 661, Case Sixteen): at variable 240 = 1 the door at 37,4 (entered facing
# left) leads to the bedroom, where Truffles (switch 71) smells six sprites by colour; only the red one (EV136) finds
# the glasses (240 at 3). Alice (EV43) then asks for three pieces of evidence, which the assist names.
module PokeAccess
  module AshenInnGlasses
    MAP = 661
    STEP = 240
    TRUFFLES = 71
    CLUE = 136
    ALICE = 43
    SMELLS = [46, 47, 50, 136, 137, 138]
    COLOURS = { "Red" => :afe_smell_red, "Yellow" => :afe_smell_yellow, "Green" => :afe_smell_green,
                "Black" => :afe_smell_black }
    ROUNDS = [:CLUEGLASSES, :TESTLUCY, :TESTANO]

    # The case's step with the glasses.
    def self.step
      $game_variables[STEP].to_i
    end

    # Whether the player is Truffles, sniffing.
    def self.sniffing?
      $game_switches[TRUFFLES] ? true : false
    end

    # A smell's name, by its sprite's colour; with the assist, the one with the glasses says so. Nil unless Truffles.
    def self.smell_label(ev)
      return nil unless sniffing?
      return :afe_smell_clue if ev.id == CLUE && PokeAccess::Puzzles.assist?
      colour = ev.character_name.to_s =~ /_([A-Za-z]+)\z/ ? COLOURS[$1] : nil
      colour || :afe_smell
    end

    # Whether Alice waits for the evidence: her third page has run and the scene it leads to has not.
    def self.alice_waits?
      $game_self_switches[[MAP, ALICE, "B"]] && !$game_self_switches[[MAP, ALICE, "C"]] ? true : false
    end

    # What the assist says as Alice is spoken to on her fourth page.
    def self.alice_answer
      alice_waits? ? [:afe_alice_evidence, { :list => AshenEvidence.names(ROUNDS) }] : nil
    end

    # The assist's hint for the step: the door, the smell, then Alice.
    def self.hint
      return :afe_glasses_hint_door if step == 1
      return :afe_glasses_hint_smell if step == 2
      :afe_glasses_hint_alice
    end

    # Whether the glasses are still to be found or shown.
    def self.open?
      step.between?(1, 2) || (step >= 3 && !$game_self_switches[[MAP, ALICE, "C"]])
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  inn = PokeAccess::AshenInnGlasses
  mechanic(:state, inn::MAP, :part => :afe_glasses) do
    auto
    active { PokeAccess::Puzzles.assist? && inn.open? }
    name inn::SMELLS, lambda { |ev| inn.smell_label(ev) }, :when => lambda { |_ev| inn.sniffing? }
    on_use inn::ALICE, lambda { |_ev| inn.alice_answer }, :assist => true
    phase lambda { inn.open? }, :hint => lambda { inn.hint }
  end
end
