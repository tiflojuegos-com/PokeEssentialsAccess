module PokeAccess
  # Pathfinder, the spoken route: a list of step directions as the player hears it, in legs.
  module Pathfinder
    # What is said of a target with no route: that none was found, or, when a search stopped short, that it
    # could not be worked out from where the player stands.
    def self.no_route_text(cut)
      PokeAccess::I18n.t(cut ? :loc_route_gave_up : :loc_no_route)
    end

    # A route split into legs, runs of one direction merged into [direction, count] pairs; both route readers use it.
    def self.legs(path)
      return [] if path.nil? || path.empty?
      out = []; cur = path[0]; count = 0
      path.each do |d|
        if d == cur then count += 1
        else out.push([cur, count]); cur = d; count = 1 end
      end
      out.push([cur, count])
      out
    end

    # One leg as the player hears it, e.g. "3 up".
    def self.leg_text(leg)
      "#{leg[1]} #{PokeAccess::I18n.t(PokeAccess::Locator::DIR_NAMES[leg[0]])}"
    end

    # Turns a list of step directions into a spoken route (e.g. "3 up, 2 left").
    # param cut true when the search behind a nil route stopped short (see cuts)
    def self.path_to_text(path, cut = false)
      return no_route_text(cut) if path.nil?
      return PokeAccess::I18n.t(:loc_next_to) if path.empty?
      legs(path).map { |l| leg_text(l) }.join(", ")
    end
  end
end
