# Sevii's party panel and PC where they part from the stock ones: the panel shows the HP bar without its figures and
# the ball each member was caught in, and the PC's party and return buttons are drawn into its picture.
PokeAccess::Game.define("sevii") do
  # The panel writes its HP figures at x 1000, off its bitmap (@hpX, @hpY): only the bar shows.
  override("PokeAccess::Party", :panel_hp_figures?) { |_mod, _original, _args| false }

  # One ball picture per ballused, as $BallTypes names them, where the stock panel draws a single one.
  override("PokeAccess::Party", :panel_marks) do |_mod, original, args|
    ball = PokeAccess::Summary.ball_name(args[0])
    ball ? original.call + [ball] : original.call
  end

  # boxsides.png draws "PARTY PKMN" and "RETURN" with no text to capture.
  override("PokeAccess::Party", :pc_buttons) do |_mod, original, _args|
    painted = original.call
    painted.empty? ? [PokeAccess::I18n.t(:pc_team), PokeAccess::I18n.t(:back)] : painted
  end
end
