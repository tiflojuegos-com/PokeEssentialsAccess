# Every rescue of the mod that catches StandardError or Exception reports what it caught (swallowed, log_once,
# write_marker, or the data layer's note_error, once per method and class) or raises it again, so no failure vanishes
# without a trace. One-line `x rescue y` probes are out, and so are failures.rb, diag.rb and selfcheck.rb, which report
# by other means, and Uranium's compat.rb, which runs before the mod is loaded and notes what it skips in files of its
# own.
require "prism"

class RescueReportsTest < PokeAccessTest
  EXEMPT = %w[core/foundation/failures.rb core/input/diag.rb core/util/selfcheck.rb games/uranium/compat.rb].freeze
  REPORTS = /\b(swallowed|log_once|write_marker|note_error|raise)\b/

  test "static: every broad rescue of the mod reports what it caught" do
    root = File.expand_path("../..", File.dirname(__FILE__))
    silent = []
    broad = 0
    Dir.glob(File.join(root, "{core,games,plugins}", "**", "*.rb")).sort.each do |f|
      rel = f.sub(root + "/", "")
      next if EXEMPT.include?(rel)
      nodes = [Prism.parse_file(f).value]
      until nodes.empty?
        n = nodes.pop
        nodes.concat(n.compact_child_nodes)
        next unless n.is_a?(Prism::RescueNode)
        kinds = n.exceptions.map { |k| k.slice }
        next unless kinds.empty? || kinds.include?("StandardError") || kinds.include?("Exception")
        broad += 1
        silent.push("#{rel}:#{n.location.start_line}") unless (n.statements ? n.statements.slice : "") =~ REPORTS
      end
    end

    assert_equal [], silent, "each broad rescue calls PokeAccess.swallowed(e), log_once or write_marker, or raises"
    assert broad > 800, "the sweep found the mod's broad rescues (#{broad})"
  end
end
