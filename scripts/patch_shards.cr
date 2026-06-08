PATCHES = {
  {
    shard:   "term-reader",
    path:    "lib/term-reader/src/reader/console.cr",
    search:  "      def get_char(raw : Bool, echo : Bool, nonblock : Bool) : Char?\n        char = nil\n        mode.cooked(!raw) do\n          mode.raw(raw) do\n            mode.echo(echo) do\n              @input.blocking = !nonblock\n              char = @input.read_char\n            end\n          end\n        end\n\n        char\n      rescue\n        nil\n      end",
    replace: "      def get_char(raw : Bool, echo : Bool, nonblock : Bool) : Char?\n        char = nil\n        mode.cooked(!raw) do\n          mode.raw(raw) do\n            mode.echo(echo) do\n              {% if flag?(:windows) %}\n                char = windows_read_char(nonblock)\n              {% else %}\n                char = posix_read_char(nonblock)\n              {% end %}\n            end\n          end\n        end\n\n        char\n      rescue\n        nil\n      end\n\n      {% if flag?(:windows) %}\n        private def windows_read_char(nonblock : Bool) : Char?\n          LibMSVCRT.kbhit == 0 ? nil : @input.read_char\n        rescue\n          nil\n        end\n      {% else %}\n        private def posix_read_char(nonblock : Bool) : Char?\n          return @input.read_char unless nonblock\n\n          chan = Channel(Char?).new\n          spawn { chan.send(@input.read_char) }\n          select\n          when c = chan.receive\n            c\n          when timeout 5.milliseconds\n            nil\n          end\n        rescue\n          nil\n        end\n      {% end %}",
  },
  {
    shard:   "term-prompt",
    path:    "lib/term-prompt/src/prompt/confirm_question.cr",
    search:  "Regex.escape(positive.to_s[0])",
    replace: "Regex.escape(positive.to_s[0].to_s)",
  },
  {
    shard:   "term-color",
    path:    "lib/term-color/src/color/color.cr",
    search:  "Cor.truecolor_string",
    replace: "Color.truecolor_string",
  },
}

applied = 0
skipped = 0

PATCHES.each do |patch|
  path = patch[:path]
  unless File.exists?(path)
    STDERR.puts "  SKIP #{patch[:shard]}: #{path} not found"
    skipped += 1
    next
  end

  content = File.read(path)

  if content.includes?(patch[:replace])
    puts "  OK   #{patch[:shard]}: already patched"
    skipped += 1
    next
  end

  unless content.includes?(patch[:search])
    STDERR.puts "  WARN #{patch[:shard]}: search string not found (upstream may have fixed this)"
    skipped += 1
    next
  end

  content = content.gsub(patch[:search], patch[:replace])
  File.write(path, content)
  puts "  FIX  #{patch[:shard]}: patched successfully"
  applied += 1
end

puts "\n  #{applied} patched, #{skipped} skipped"
exit(applied > 0 || skipped == PATCHES.size ? 0 : 1)
