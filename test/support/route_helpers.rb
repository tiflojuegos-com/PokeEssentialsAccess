# Shared route spec helpers, loaded by the runner with the other support files.

# A replayed route (Pathfinder.trace) as one [x, y, level] per Step, the shape the route specs pin.
def spots(steps)
  steps.map { |s| [s.x, s.y, s.level] }
end
