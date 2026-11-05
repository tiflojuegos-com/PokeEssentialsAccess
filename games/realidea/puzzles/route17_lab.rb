# The laboratory of Route 17. On the ground floor (map 309) the data sheet of the Decoy (event 1) asks, after the battle
# (switch 422), which defence is higher, its HP and its type, which the game changes (variable 148) whenever it is missed.
# On the first floor (map 311) five figures stand in the dark and a terminal (event 14) asks for the figure at four places
# in turn (variable 179); Owen notes each figure examined (switches 436 to 441). The sheet done (its self switch C) and the
# terminal solved (switch 428) each end their floor's rule and count on the info key.
module PokeAccess
  module RealideaLab
    SHEET = 1
    SHEET_MAP = 309
    FOUGHT = 422
    FIGURES_MAP = 311
    TERMINAL = 14
    FIGURES = { 15 => :rea_shape_circle, 18 => :rea_shape_diamond, 16 => :rea_shape_triangle, 17 => :rea_shape_square,
                13 => :rea_shape_rectangle }
    EXAMINED = [436, 438, 439, 440, 441]
    # What the terminal asks for at each stage, as the game compares it.
    NAMES = ["Circulo", "Cuadrado", "Triangulo", "Rombo"]
    STAGE = 179
    SOLVED = 428

    # The type of the Decoy as the game spells it now, or "" when it cannot be read.
    def self.decoy_type
      PBTypes.getName(getConst(PBTypes, $game_variables[148])).to_s
    rescue StandardError => e
      PokeAccess.swallowed(e)
      ""
    end

    # True once the data sheet has been answered whole.
    def self.sheet_done?
      $game_self_switches[[SHEET_MAP, SHEET, "C"]] ? true : false
    end

    # What the puzzle assist says as the sheet is used, once the Decoy has been fought: the answers still to give, in the
    # order the page asks them, or nothing once the sheet is done or while the type cannot be read.
    def self.sheet_answer
      return "" if !$game_switches[FOUGHT] || sheet_done?
      type = decoy_type
      return "" if type.empty?
      key = $game_self_switches[[SHEET_MAP, SHEET, "B"]] ? :rea_decoy_type : :rea_decoy_answer
      [:puzzle_answer, { :a => PokeAccess::I18n.t(key, :type => type) }]
    end

    # What the puzzle assist says as the terminal is used: the figures it asks for from the stage it is at, in order, since
    # one page asks them all while they are right; nothing once it is done.
    def self.terminal_answer
      return "" if $game_switches[SOLVED]
      left = NAMES[$game_variables[STAGE].to_i..-1]
      left.nil? || left.empty? ? "" : [:puzzle_answer, { :a => left.join(", ") }]
    end
  end
end

PokeAccess::Game.define("realidea") do
  lab = PokeAccess::RealideaLab
  mechanic(:state, lab::SHEET_MAP) do
    auto
    name lab::SHEET, :rea_decoy_sheet
    count :rea_decoy_data, :flags => [{ :self => [lab::SHEET, "A"] }, { :self => [lab::SHEET, "B"] }, { :self => [lab::SHEET, "C"] }]
    on_use lab::SHEET, lambda { lab.sheet_answer }, :assist => true
    right_choice lab::SHEET, :takes => { :self => "A" }
    arrival_hint :rea_decoy_rule
    solved { lab.sheet_done? }
  end
  mechanic(:state, lab::FIGURES_MAP) do
    auto
    lab::FIGURES.each { |id, key| name id, key }
    name lab::TERMINAL, :rea_shapes_terminal
    count :rea_shapes_count, :switches => lab::EXAMINED
    on_use lab::TERMINAL, lambda { lab.terminal_answer }, :assist => true
    arrival_hint :rea_shapes_rule
    solved { $game_switches[lab::SOLVED] }
  end
end
