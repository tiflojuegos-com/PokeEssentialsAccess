# Infinite Fusion's move tutor board (pbShowRareTutorFullList): the relearner opened with no Pokemon, a list to browse
# under the title "Moves list"; each move reads its own data, and the title leads the first one.
module IFMovesListSpec
  # A relearner scene with its moves, its cursor on one of them, and the Pokemon it teaches (nil on the board).
  def self.scene(pokemon, moves, index = 0)
    win = Struct.new(:index).new(index)
    s = Object.new
    s.instance_variable_set(:@pokemon, pokemon)
    s.instance_variable_set(:@moves, moves)
    s.instance_variable_set(:@sprites, { "commands" => win })
    s
  end
end

Suite.define("infinite fusion: the moves board reads each move with no Pokemon, led once by its title") do
  ml = PokeAccess::MoveList
  board = IFMovesListSpec.scene(nil, [:TACKLE, :EMBER])
  SpeakCapture.clear
  ml.detail(board)
  spoke "a move on the board, with no Pokemon to teach, is read from its own data", /MoveTACKLE/
  spoke "with its type and description", /descTACKLE/

  meta = (class << ml; self; end)
  meta.send(:alias_method, :if_spec_title, :title)
  begin
    load File.expand_path("../../../games/infinitefusion_common/moves_list.rb", File.dirname(__FILE__))
    fresh = IFMovesListSpec.scene(nil, [:TACKLE, :EMBER])
    SpeakCapture.clear
    ml.detail(fresh)
    eq "opening the board says its title ahead of the first move", SpeakCapture.lines.length, 1
    truthy "the title first", SpeakCapture.lines[0].to_s.start_with?("Moves list. MoveTACKLE")
    fresh.instance_variable_get(:@sprites)["commands"].index = 1
    SpeakCapture.clear
    ml.detail(fresh)
    truthy "the next move alone", SpeakCapture.lines[0].to_s.start_with?("MoveEMBER")

    taught = IFMovesListSpec.scene(Poke.build(:name => "Chispa"), [:TACKLE])
    SpeakCapture.clear
    ml.detail(taught)
    not_spoke "a relearner teaching a Pokemon has no board title", /Moves list/
  ensure
    meta.send(:alias_method, :title, :if_spec_title)
    meta.send(:remove_method, :if_spec_title)
  end
end
