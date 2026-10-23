# Mutation testing for one file of the mod: each mutant changes one operator, literal, condition or statement, and
# the chosen tests run with it loaded in place of the file. A mutant the tests still pass on survived: behavior no
# test pins down. The file on disk is never touched (the harness applies the mutant as it loads, PA_MUTANT).
#   ruby tools/mutate.rb core/routes/planner.rb unit/routes        # the tests whose path contains unit/routes
#   ruby tools/mutate.rb core/routes/planner.rb unit/routes --max 80 --seed 3 --lines 40-120 --timeout 180
require "prism"
require "json"
require "tmpdir"

ROOT = File.expand_path("..", File.dirname(__FILE__))
SWAPS = { "==" => "!=", "!=" => "==", "<" => "<=", "<=" => "<", ">" => ">=", ">=" => ">", "+" => "-", "-" => "+",
          "*" => "/", "/" => "*", "&&" => "||", "||" => "&&", "and" => "or", "or" => "and" }.freeze

def take(args, flag, default = nil)
  i = args.index(flag)
  return default unless i
  args.delete_at(i)
  args.delete_at(i)
end

def walk(node, &blk)
  yield node
  node.compact_child_nodes.each { |c| walk(c, &blk) }
end

# Every mutant of src as [start, end, replacement, what, line]: byte offsets into src.
def mutants_of(src)
  out = []
  walk(Prism.parse(src).value) do |n|
    case n
    when Prism::CallNode
      op = n.message_loc && n.message_loc.slice
      if n.receiver && SWAPS.key?(op) && n.arguments && n.arguments.arguments.length == 1
        out << [n.message_loc.start_offset, n.message_loc.end_offset, SWAPS[op], "#{op} -> #{SWAPS[op]}", n.location.start_line]
      end
    when Prism::AndNode, Prism::OrNode
      op = n.operator_loc.slice
      out << [n.operator_loc.start_offset, n.operator_loc.end_offset, SWAPS[op], "#{op} -> #{SWAPS[op]}", n.location.start_line] if SWAPS.key?(op)
    when Prism::IntegerNode
      v = n.value
      out << [n.location.start_offset, n.location.end_offset, (v == 1 ? 0 : v + 1).to_s, "#{v} -> #{v == 1 ? 0 : v + 1}", n.location.start_line]
    when Prism::TrueNode, Prism::FalseNode
      rep = n.is_a?(Prism::TrueNode) ? "false" : "true"
      out << [n.location.start_offset, n.location.end_offset, rep, "#{n.slice} -> #{rep}", n.location.start_line]
    when Prism::IfNode, Prism::UnlessNode
      pr = n.predicate
      out << [pr.location.start_offset, pr.location.end_offset, "!(#{pr.slice})", "condition negated", n.location.start_line]
    when Prism::ReturnNode
      if n.arguments
        out << [n.location.start_offset, n.location.end_offset, "return nil", "returns nil", n.location.start_line]
      end
    when Prism::DefNode
      body = n.body
      if body.is_a?(Prism::StatementsNode)
        body.body.each do |st|
          next if st.is_a?(Prism::NilNode)
          out << [st.location.start_offset, st.location.end_offset, "nil", "statement removed", st.location.start_line]
        end
      end
    end
  end
  out
end

# True when the chosen tests pass in both engines with mutant (nil: the file as it is) loaded, each engine's process
# within limit seconds (a mutant that hangs is killed, and counts as caught).
def passes?(filter, mutant, dir, limit)
  env = {}
  if mutant
    path = File.join(dir, "mutant.json")
    File.write(path, JSON.generate(mutant))
    env["PA_MUTANT"] = path
  end
  %w[gen6 gamedata].all? do |engine|
    pid = Process.spawn(env.merge("PA_ENGINE" => engine), "ruby", File.join(ROOT, "test", "run.rb"), filter,
                        "--seed", "1", [:out, :err] => File::NULL)
    deadline = Time.now + limit
    ok = nil
    while ok.nil?
      if Process.wait(pid, Process::WNOHANG)
        ok = $?.success?
      elsif Time.now > deadline
        Process.kill("KILL", pid) rescue nil
        Process.wait(pid) rescue nil
        ok = false
      else
        sleep 0.1
      end
    end
    ok
  end
end

args = ARGV.dup
max = take(args, "--max", "60").to_i
seed = take(args, "--seed", "1").to_i
limit = take(args, "--timeout", "120").to_i
range = take(args, "--lines")
target, filter = args
abort "usage: ruby tools/mutate.rb <file of the mod> <test path fragment> [--max N] [--seed N] [--lines A-B]" unless target && filter
full = File.join(ROOT, target)
src = File.read(full)
all = mutants_of(src)
if range
  lo, hi = range.split("-").map { |x| x.to_i }
  all = all.select { |m| m[4] >= lo && m[4] <= hi }
end
picked = all.shuffle(random: Random.new(seed)).first(max).sort_by { |m| [m[4], m[0]] }

Dir.mktmpdir("pa-mutate") do |dir|
  abort "the tests fail without any mutant: fix them first" unless passes?(filter, nil, dir, limit)
  survived = []
  picked.each_with_index do |(from, to, text, what, line), i|
    killed = !passes?(filter, { "path" => full, "start" => from, "end" => to, "text" => text }, dir, limit)
    survived << [line, what, src.byteslice(from, to - from).lines.first.to_s.strip[0, 70]] unless killed
    print(killed ? "." : "S")
    $stdout.flush
  end
  puts "\n#{target}: #{picked.length - survived.length} of #{picked.length} mutants killed (#{all.length} possible)"
  survived.each { |line, what, orig| puts format("  survived %5d  %-20s %s", line, what, orig) }
end
