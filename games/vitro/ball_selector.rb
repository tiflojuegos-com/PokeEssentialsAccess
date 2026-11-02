# Vitro's list of Balls (0246_Ball Selector, BallSelectorInterface): W over the command menu, and the throw that ends a raid
# (0306_NewBattle_CaptureAfterBattle). A row of icons turning around the one in the centre, whose name, count and description it
# paints; the left and right arrows go round.
module PokeAccess
  module VitroBallSelector
    SLOT = :vitro_ball

    # Says the Ball in the centre as the list repaints, the first read queued; also the info key's item.
    def self.update(list)
      balls = PokeAccess.ivar(list, :@ball_list)
      index = PokeAccess.ivar(list, :@index)
      ball = balls[index]
      PokeAccess::Cursor.announce(list, SLOT, index, true, false) do
        PokeAccess::Info.set_info(:item, ball)
        line(ball, PokeAccess.ivar(list, :@ball_counts)[index], index + 1, balls.length)
      end
    end

    # A Ball's row: its name and count with its place, and its description while descriptions are said.
    def self.line(ball, count, place, total)
      row = PokeAccess::Verbosity.list_entry("#{PokeAccess::Data.item_name(ball)}, #{count}", place, total)
      return row unless PokeAccess::Verbosity.descriptions?
      PokeAccess.sentences([row, PokeAccess::Data.item_description(ball)])
    end
  end
end

PokeAccess::Game.define("vitro") do
  after("BallSelectorInterface", :update_display) { |list, _r, _a| PokeAccess::VitroBallSelector.update(list) }
end
