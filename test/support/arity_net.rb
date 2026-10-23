# Ruby 1.8.7, the games' Ruby, hands a block with one parameter all the values it is called with, as one array; the
# tests' Ruby hands it the first. The net logs every block or proc of the mod (core/, games/, plugins/) with one
# parameter that is called with two or more values, for the run to fail on (an Events.on_change listener taking
# |tiles| got [tiles, record, how] in Pokemon Z and broke the probe's memo).
module ArityNet
  MOD = %r{[/\\](core|games|plugins)[/\\]}
  ROOT = File.expand_path("../..", File.dirname(__FILE__)).tr("\\", "/")
  @offenders = {}

  # The offenders seen, as "defined at -> called from" strings.
  def self.offenders; @offenders.keys.sort; end

  # Logs prc when it takes one parameter and was handed n values from the mod.
  def self.note(prc, n)
    return unless n > 1 && prc.arity == 1
    loc = prc.source_location
    return unless loc
    path = loc[0].tr("\\", "/")
    return unless path.start_with?(ROOT) && path[ROOT.length..-1] =~ MOD
    from = caller_locations(3, 1)[0]
    @offenders["#{path[(ROOT.length + 1)..-1]}:#{loc[1]} <- #{from ? "#{File.basename(from.path)}:#{from.lineno}" : '?'}"] = true
  end

  # Proc#call, #[] and #yield, logged before they run.
  module Calls
    def call(*args, &b); ArityNet.note(self, args.length); super; end
    def [](*args, &b); ArityNet.note(self, args.length); super; end
    def yield(*args, &b); ArityNet.note(self, args.length); super; end
  end
end

Proc.prepend(ArityNet::Calls)
