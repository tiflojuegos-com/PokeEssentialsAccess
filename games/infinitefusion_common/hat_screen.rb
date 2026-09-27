module PokeAccess
  # A Pokemon's hat screen (PokemonHatPresenter, from the party and the summary), which writes nothing: the hat is
  # picked with left and right, then placed with the arrows, one step of 4 pixels a press. Polled on the view's
  # update, which both loops run every frame: the hat's name as it changes, then where it sits.
  module IFHatScreen
    # One step of the placement, in pixels (PIXELS_PER_MOVEMENT in both games).
    STEP = 4

    # The step the presenter is running: :pick, :place or nil.
    def self.mode(pres)
      PokeAccess.ivar(pres, :@access_hat_mode)
    end

    # Starts a step, read afresh from its first frame.
    def self.enter(pres, step)
      PokeAccess::Cursor.reset(pres, step == :pick ? :if_hat : :if_hat_pos)
      pres.instance_variable_set(:@access_hat_mode, step)
    end

    def self.leave(pres)
      pres.instance_variable_set(:@access_hat_mode, nil)
    end

    # The hat's name from the outfit data, or its id.
    def self.hat_name(id)
      name = ((get_hat_by_id(id).name) rescue nil)
      PokeAccess.clean((name.nil? || name.to_s.empty?) ? id.to_s : name.to_s)
    end

    # Where the hat sits, in steps from the top-left corner of the Pokemon's picture, where its offsets start.
    def self.where(pres)
      x = PokeAccess.ivar(pres, :@x_pos).to_i / STEP
      y = PokeAccess.ivar(pres, :@y_pos).to_i / STEP
      return PokeAccess::I18n.t(:if_hat_corner) if x == 0 && y == 0
      PokeAccess::I18n.t(:if_hat_from_corner, :where => PokeAccess::Locator.dir_phrase(x, y))
    end

    # Whether an arrow was pressed this frame, which at an edge moves nothing.
    def self.arrow_pressed?
      [:LEFT, :RIGHT, :UP, :DOWN].any? { |k| Input.trigger?(Input.const_get(k)) }
    rescue StandardError
      false
    end

    # One frame: the hat picked when it changes; while placing, the place when it changes, or the edge when an arrow
    # moved nothing. The first frame of each step says it whole.
    def self.poll(pres)
      case mode(pres)
      when :pick
        first = PokeAccess::Cursor.pending?(pres, :if_hat)
        id = PokeAccess.ivar(pres, :@hat_id)
        return unless PokeAccess::Cursor.changed?(pres, :if_hat, id)
        PokeAccess.speak(first ? PokeAccess::I18n.t(:if_hat_pick, :name => hat_name(id)) : hat_name(id), true)
      when :place
        first = PokeAccess::Cursor.pending?(pres, :if_hat_pos)
        pos = [PokeAccess.ivar(pres, :@x_pos), PokeAccess.ivar(pres, :@y_pos)]
        if PokeAccess::Cursor.changed?(pres, :if_hat_pos, pos)
          t = where(pres)
          PokeAccess.speak(first ? PokeAccess::I18n.t(:if_hat_place, :where => t) : t, true)
        elsif arrow_pressed?
          PokeAccess.speak(PokeAccess::I18n.t(:if_hat_edge), true)
        end
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  [[:select_hat, :pick], [:position_hat, :place]].each do |meth, step|
    around("PokemonHatPresenter", meth, :optional => true) do |pres, nxt, _a|
      PokeAccess::IFHatScreen.enter(pres, step)
      begin
        nxt.call
      ensure
        PokeAccess::IFHatScreen.leave(pres)
      end
    end
  end
  after("PokemonHatView", :update, :optional => true) do |view, _r, _a|
    PokeAccess::IFHatScreen.poll(PokeAccess.ivar(view, :@presenter))
  end
end
