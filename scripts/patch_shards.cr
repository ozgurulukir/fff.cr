# Patches for known crystal-term shard bugs that remain unfixed upstream in v1.0.0.
#
# Bug 1 (term-reader sync= type mismatch) — fixed upstream in v1.0.0, patch removed.
# Bug 3 (term-prompt Regex.escape) — fixed upstream in v1.0.0, patch removed.
# Bug 6 (term-color Cor.truecolor_string) — fixed upstream in v1.0.0, patch removed.
#
# Remaining: Bug 2 (term-reader ESC loop hang) — still unfixed in v1.0.0.

PATCHES = {
  {
    shard:   "term-reader",
    path:    "lib/term-reader/src/reader/console.cr",
    search:  "require \"./keys\"\nrequire \"./mode\"\n\nmodule Term",
    replace: "require \"./keys\"\nrequire \"./mode\"\n\n{% if flag?(:windows) %}\n  lib LibMSVCRT\n    fun kbhit = \"_kbhit\" : Int32\n  end\n{% end %}\n\nmodule Term",
  },
  {
    shard:   "term-reader",
    path:    "lib/term-reader/src/reader/console.cr",
    search:  "      def get_char(raw : Bool, echo : Bool, nonblock : Bool) : Char?\n        char = nil\n        mode.cooked(!raw) do\n          mode.raw(raw) do\n            mode.echo(echo) do\n              @input.blocking = !nonblock\n              char = @input.read_char\n            end\n          end\n        end\n\n        char\n      rescue\n        nil\n      end",
    replace: "      def get_char(raw : Bool, echo : Bool, nonblock : Bool) : Char?\n        char = nil\n        mode.cooked(!raw) do\n          mode.raw(raw) do\n            mode.echo(echo) do\n              {% if flag?(:windows) %}\n                char = windows_read_char(nonblock)\n              {% else %}\n                char = posix_read_char(nonblock)\n              {% end %}\n            end\n          end\n        end\n\n        char\n      rescue\n        nil\n      end\n\n      {% if flag?(:windows) %}\n        private def windows_read_char(nonblock : Bool) : Char?\n          LibMSVCRT.kbhit == 0 ? nil : @input.read_char\n        rescue\n          nil\n        end\n      {% else %}\n        private def posix_read_char(nonblock : Bool) : Char?\n          return @input.read_char unless nonblock\n\n          chan = Channel(Char?).new\n          spawn { chan.send(@input.read_char) }\n          select\n          when c = chan.receive\n            c\n          when timeout 5.milliseconds\n            nil\n          end\n        rescue\n          nil\n        end\n      {% end %}",
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
  content = content.gsub("\r\n", "\n")

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
