require "term-color"
require "term-screen"
require "term-cursor"
require "term-reader"
require "term-prompt"
require "file"
require "file_utils"
require "process"
require "signal"

# Fucking Fast File Manager - Crystal Port
# Using crystal-term shards: term-color, term-screen, term-cursor, term-reader, term-prompt

module FFF
  VERSION = "0.1.0"

  # Terminal wrapper using crystal-term shards
  class Terminal
    getter width : Int32
    getter height : Int32
    getter reader : Term::Reader
    getter prompt : Term::Prompt

    def initialize
      @width = Term::Screen.width
      @height = Term::Screen.height
      @reader = Term::Reader.new(interrupt: :no_exit)
      @prompt = Term::Prompt.new(interrupt: :no_exit)
    end

    def max_items
      @height - 3
    end

    def refresh_size
      @width = Term::Screen.width
      @height = Term::Screen.height
    end

    def enter_tui
      refresh_size
      print Term::Cursor.hide
      print "\e[?1049h"   # alternate screen buffer
      print "\e[2J"       # clear
      print "\e[1;1H"     # home
      STDOUT.flush
    end

    def leave_tui
      print "\e[2J"
      print "\e[1;1H"
      print Term::Cursor.show
      print "\e[?1049l"   # restore main screen
      STDOUT.flush
      # Restore STDIN to normal (cooked + echo) for shell/prompt use.
      if STDIN.tty?
        STDIN.cooked!
      end
    end

    def move_to(row : Int32, col : Int32)
      print "\e[#{row + 1};#{col + 1}H"
    end

    # Read a single keypress via term-reader
    def read_keypress : String?
      @reader.read_keypress(echo: false, raw: false, nonblock: false)
    end

    # Ask for text input (leaves TUI temporarily)
    def ask(message : String) : String
      @prompt.ask(message, default: "").to_s
    end

    # Yes/no confirmation (leaves TUI temporarily)
    def confirm?(message : String) : Bool
      @prompt.yes?(message) || false
    end

    # Keypress prompt (leaves TUI temporarily)
    def keypress(message : String)
      @prompt.keypress(message)
    end
  end

  # Configuration from environment
  class Config
    getter editor : String
    getter opener : String
    getter trash_dir : String
    getter cd_on_exit : Bool
    getter cd_file : String
    getter key_up : String
    getter key_down : String
    getter key_enter : String
    getter key_quit : String
    getter key_search : String
    getter key_parent : String
    getter key_mark : String
    getter key_mark_all : String
    getter key_copy : String
    getter key_move : String
    getter key_delete : String
    getter key_new_dir : String
    getter key_paste : String
    getter key_preview : String
    getter key_page_up : String
    getter key_page_down : String
    getter key_top : String
    getter key_bottom : String
    getter key_rename : String
    getter key_shell : String
    getter key_hidden : String
    getter key_home : String
    getter key_prev : String
    getter key_refresh : String
    getter key_mkfile : String
    getter key_attributes : String
    getter key_executable : String
    getter key_go_dir : String
    getter key_go_trash : String

    def initialize
      @editor = ENV["EDITOR"]? || "vi"
      @opener = ENV["FFF_OPENER"]? || "xdg-open"
      @trash_dir = ENV["FFF_TRASH"]? || File.join(ENV["HOME"], ".local", "share", "fff", "trash")
      @cd_on_exit = (ENV["FFF_CD_ON_EXIT"]? == "1")
      @cd_file = ENV["FFF_CD_FILE"]? || File.join(ENV["HOME"], ".cache", "fff", ".fff_d")
      @key_up = ENV["FFF_KEY_UP"]? || "k"
      @key_down = ENV["FFF_KEY_DOWN"]? || "j"
      @key_enter = ENV["FFF_KEY_ENTER"]? || "l"
      @key_quit = ENV["FFF_KEY_QUIT"]? || "q"
      @key_search = ENV["FFF_KEY_SEARCH"]? || "/"
      @key_parent = ENV["FFF_KEY_PARENT"]? || "h"
      @key_mark = ENV["FFF_KEY_MARK"]? || " "
      @key_mark_all = ENV["FFF_KEY_MARK_ALL"]? || "m"
      @key_copy = ENV["FFF_KEY_COPY"]? || "y"
      @key_move = ENV["FFF_KEY_MOVE"]? || "v"
      @key_delete = ENV["FFF_KEY_DELETE"]? || "d"
      @key_new_dir = ENV["FFF_KEY_NEW_DIR"]? || "n"
      @key_paste = ENV["FFF_KEY_PASTE"]? || "p"
      @key_preview = ENV["FFF_KEY_PREVIEW"]? || "i"
      @key_page_up = ENV["FFF_KEY_PAGE_UP"]? || "\e[A"
      @key_page_down = ENV["FFF_KEY_PAGE_DOWN"]? || "\e[B"
      @key_top = ENV["FFF_KEY_TOP"]? || "g"
      @key_bottom = ENV["FFF_KEY_BOTTOM"]? || "G"
      @key_rename = ENV["FFF_KEY_RENAME"]? || "r"
      @key_shell = ENV["FFF_KEY_SHELL"]? || "s"
      @key_hidden = ENV["FFF_KEY_HIDDEN"]? || "."
      @key_home = ENV["FFF_KEY_HOME"]? || "~"
      @key_prev = ENV["FFF_KEY_PREVIOUS"]? || "-"
      @key_refresh = ENV["FFF_KEY_REFRESH"]? || "e"
      @key_mkfile = ENV["FFF_KEY_MKFILE"]? || "f"
      @key_attributes = ENV["FFF_KEY_ATTRIBUTES"]? || "x"
      @key_executable = ENV["FFF_KEY_EXECUTABLE"]? || "X"
      @key_go_dir = ENV["FFF_KEY_GO_DIR"]? || ":"
      @key_go_trash = ENV["FFF_KEY_GO_TRASH"]? || "t"
    end
  end

  # Main application
  class Application
    def initialize(@args : Array(String))
    end

    def run
      if @args.includes?("--version")
        puts "fff #{VERSION}"
        return
      end

      if @args.includes?("--help") || @args.includes?("-h")
        print_help
        return
      end

      start_dir = @args.find { |a| !a.starts_with?('-') } || "."
      config = Config.new

      fm = FileManager.new(config, start_dir)
      fm.run
    end

    private def print_help
      puts "fff - Fucking Fast File Manager (Crystal)"
      puts ""
      puts "Usage: fff [options] [directory]"
      puts ""
      puts "Options:"
      puts "  -h, --help     Show this help"
      puts "  --version      Show version"
      puts ""
      puts "Keys:"
      puts "  j/k       Down/Up        l/h    Enter/Parent"
      puts "  q         Quit           /      Search"
      puts "  space     Mark           m      Mark all"
      puts "  y         Yank (copy)    v      Move (cut)"
      puts "  p         Paste          d      Delete"
      puts "  n         New dir        r      Rename"
      puts "  i         Preview        s      Shell"
      puts "  g/G       Top/Bottom     arrows Page up/down"
      puts "  .         Toggle hidden  ~      Home dir"
      puts "  -         Prev dir       e      Refresh"
      puts "  f         New file       x      Attributes"
      puts "  X         Toggle exec    :      Go to dir"
      puts "  t         Go to trash"
      puts ""
      puts "All keys configurable via FFF_KEY_* env vars."
    end
  end

  # The file manager
  class FileManager
    @term : Terminal
    @config : Config
    @list : Array(String)
    @scroll : Int32
    @page_offset : Int32
    @marked : Set(String)
    @clipboard : Array(String)
    @clipboard_mode : Symbol
    @running : Bool
    @show_hidden : Bool
    @prev_dir : String?
    @prev_child : String?
    @error_msg : String?
    @error_expires : Time?
    @prev_scroll : Int32
    @prev_page_offset : Int32
    def initialize(@config : Config, start_dir : String)
      @term = Terminal.new
      Dir.cd(start_dir)
      @list = [] of String
      @scroll = 0
      @page_offset = 0
      @marked = Set(String).new
      @clipboard = [] of String
      @clipboard_mode = :none
      @running = true
      @show_hidden = (ENV["FFF_HIDDEN"]? == "1")
      @prev_dir = nil
      @prev_child = nil
      @error_msg = nil
      @error_expires = nil
      @prev_scroll = -1
      @prev_page_offset = -1
    end

    def run
      # Signal handling: clean up terminal on exit
      Signal::INT.trap { quit }
      Signal::TERM.trap { quit }
      Signal::QUIT.trap { quit }
      Signal::WINCH.trap { handle_resize }

      # Ensure terminal is restored even on abnormal exit
      at_exit { @term.leave_tui if @running }

      ensure_dirs
      @term.enter_tui
      read_directory
      event_loop
    rescue e : Exception
      @term.leave_tui
      STDERR.puts "fff error: #{e.message}"
      if ENV["FFF_DEBUG"]? == "1"
        STDERR.puts e.backtrace.join('\n')
      end
    end

    private def ensure_dirs
      FileUtils.mkdir_p(File.join(ENV["HOME"], ".cache", "fff")) if @config.cd_on_exit
      FileUtils.mkdir_p(@config.trash_dir)
    end

    # ── Signal / resize ────────────────────────────────────────

    private def handle_resize
      @term.refresh_size
      # Clamp scroll to new visible area
      max = @term.max_items
      @scroll = {@scroll, @list.size - 1}.min if @list.size > 0
      @page_offset = {@page_offset, {@scroll - max + 1, 0}.max}.min if @scroll >= @page_offset + max
      redraw(true)
    end

    # ── Directory reading ──────────────────────────────────────

    private def read_directory
      cwd = Dir.current
      dirs = [] of String
      files = [] of String

      Dir.each_child(cwd) do |name|
        # Skip hidden files unless show_hidden is enabled
        next if name.starts_with?('.') && !@show_hidden

        path = File.join(cwd, name)
        if File.directory?(path)
          dirs << path
        else
          files << path
        end
      rescue File::NotFoundError
        next
      end

      @list = dirs.sort + files.sort

      # Restore scroll position for parent navigation
      if @prev_dir && cwd == File.dirname(@prev_dir.not_nil!) && @prev_child
        idx = @list.index(@prev_child.not_nil!)
        @scroll = idx || 0
      else
        @scroll = 0
      end
      @page_offset = 0
    end

    # ── Drawing ────────────────────────────────────────────────

    private def redraw(full = false)
      @term.refresh_size

      # Decide what to redraw
      list_changed = @list.object_id != @prev_list_id rescue false
      scroll_delta = (@scroll - @prev_scroll).abs
      page_changed = @page_offset != @prev_page_offset

      if full || list_changed || page_changed
        # Full list redraw: clear visible area and redraw all
        max = @term.max_items
        max.times do |i|
          idx = @page_offset + i
          break if idx >= @list.size
          @term.move_to(i, 0)
          print "\e[2K"  # clear line
        end
        draw_all_lines
      elsif scroll_delta == 1
        # Single cursor move: redraw old and new lines only
        old_scroll = @prev_scroll
        if old_scroll >= @page_offset && old_scroll < @page_offset + @term.max_items
          old_row = old_scroll - @page_offset
          @term.move_to(old_row, 0)
          print "\e[2K"
          draw_line(old_row, old_scroll) if old_scroll < @list.size
        end
        new_row = @scroll - @page_offset
        if new_row >= 0 && new_row < @term.max_items && @scroll < @list.size
          draw_line(new_row, @scroll)
        end
      end

      draw_status
      draw_error
      STDOUT.flush

      # Remember current state for next redraw
      @prev_scroll = @scroll
      @prev_page_offset = @page_offset
      @prev_list_id = @list.object_id
    end

    # Format a single list item into (label, color) — no terminal I/O
    private def format_line(idx : Int32) : {String, Symbol}
      path = @list[idx]
      name = File.basename(path)
      selected = (idx == @scroll)
      is_marked = @marked.includes?(path)
      in_clip = @clipboard.includes?(path)

      color = if selected
                :red
              elsif is_marked
                :yellow
              elsif in_clip
                :magenta
              elsif File.directory?(path)
                :blue
              elsif File.info?(path).try(&.permissions.includes?(::File::Permissions::OtherExecute))
                :green
              else
                :white
              end

      prefix = is_marked ? "*" : " "
      suffix = File.directory?(path) ? "/" : ""
      label = "#{prefix} #{name}#{suffix}"

      # Truncate to terminal width
      label = label[0...(@term.width - 1)] if label.size > @term.width
      {label, color}
    end

    # Draw a single line at screen row (0-indexed)
    private def draw_line(row : Int32, idx : Int32)
      label, color = format_line(idx)
      @term.move_to(row, 0)
      print Term::Color.truecolor_string(label, fore: Term::Color.color(color))
    end

    # Draw all visible lines
    private def draw_all_lines
      max = @term.max_items
      offset = @page_offset
      max.times do |i|
        idx = offset + i
        break if idx >= @list.size
        draw_line(i, idx)
      end
    end

    private def draw_list
      draw_all_lines
    end

    private def draw_status
      row = @term.max_items
      cwd = Dir.current
      total = @list.size
      cur = total > 0 ? @scroll + 1 : 0
      marked_n = @marked.size
      clip_str = case @clipboard_mode
                 when :copy then " [yank:#{@clipboard.size}]"
                 when :move then " [cut:#{@clipboard.size}]"
                 else ""
                 end

      status = " #{cur}/#{total} #{cwd} [#{marked_n} marked]#{clip_str}"

      @term.move_to(row, 0)
      print Term::Color.truecolor_string(status,
        fore: Term::Color.color(:black),
        back: Term::Color.color(:white))
    end

    private def draw_error
      return unless msg = @error_msg
      if exp = @error_expires
        return if Time.utc > exp
      end
      row = @term.max_items + 1
      @term.move_to(row, 0)
      print Term::Color.truecolor_string(" ERROR: #{msg} ",
        fore: Term::Color.color(:white),
        back: Term::Color.color(:red))
    end

    # ── Event loop ─────────────────────────────────────────────

    private def event_loop
      redraw

      while @running
        key = @term.read_keypress

        unless key
          sleep 10.milliseconds
          next
        end

        handle_key(key)
        redraw if @running
      end

      @term.leave_tui
      save_cd_on_exit
    end

    private def handle_key(key : String)
      case key
      when @config.key_quit      then quit
      when @config.key_up        then cursor_up
      when @config.key_down      then cursor_down
      when @config.key_enter     then enter_item
      when @config.key_parent    then go_parent
      when @config.key_search    then search
      when @config.key_mark      then toggle_mark
      when @config.key_mark_all  then toggle_mark_all
      when @config.key_copy      then yank_files
      when @config.key_move      then cut_files
      when @config.key_paste     then paste_files
      when @config.key_delete    then delete_files
      when @config.key_new_dir   then new_directory
      when @config.key_preview   then preview_file
      when @config.key_page_up   then page_up
      when @config.key_page_down then page_down
      when @config.key_top       then go_top
      when @config.key_bottom    then go_bottom
      when @config.key_rename    then rename_item
      when @config.key_shell     then spawn_shell
      when @config.key_hidden    then toggle_hidden
      when @config.key_home      then go_home
      when @config.key_prev      then go_prev
      when @config.key_refresh   then refresh_dir
      when @config.key_mkfile    then new_file
      when @config.key_attributes then show_attributes
      when @config.key_executable then toggle_executable
      when @config.key_go_dir    then go_to_dir
      when @config.key_go_trash  then go_to_trash
      end
    end

    # ── Navigation ─────────────────────────────────────────────

    private def cursor_up
      return if @scroll <= 0
      @scroll -= 1
      adjust_page_offset
    end

    private def cursor_down
      return if @scroll >= @list.size - 1
      @scroll += 1
      adjust_page_offset
    end

    private def page_up
      max = @term.max_items
      @scroll = {@scroll - max, 0}.max
      adjust_page_offset
    end

    private def page_down
      max = @term.max_items
      @scroll = {@scroll + max, @list.size - 1}.min
      adjust_page_offset
    end

    private def go_top
      @scroll = 0
      @page_offset = 0
    end

    private def go_bottom
      @scroll = {@list.size - 1, 0}.max
      adjust_page_offset
    end

    private def adjust_page_offset
      max = @term.max_items
      if @scroll < @page_offset
        @page_offset = @scroll
      elsif @scroll >= @page_offset + max
        @page_offset = @scroll - max + 1
      end
      @page_offset = {@page_offset, 0}.max
    end

    # Check if a file is a text file (open in EDITOR vs OPENER)
    private def text_file?(path : String) : Bool
      return false unless File.file?(path)

      # Check by extension first (fast path)
      ext = File.extname(path).downcase
      text_exts = {".txt", ".md", ".cr", ".rb", ".py", ".js", ".ts", ".json",
                   ".yaml", ".yml", ".toml", ".xml", ".html", ".css", ".sh",
                   ".bash", ".zsh", ".fish", ".vim", ".conf", ".cfg", ".ini",
                   ".c", ".h", ".cpp", ".hpp", ".java", ".go", ".rs", ".php"}
      return true if text_exts.includes?(ext)

      # Check MIME type via file command
      output = IO::Memory.new
      Process.run("file", ["-I", path], output: output, error: Process::Redirect::Close)
      mime = output.to_s.downcase

      mime.includes?("text/") || mime.includes?("x-empty") || mime.includes?("json")
    rescue
      false
    end

    private def enter_item
      path = @list[@scroll]?
      return unless path

      if File.directory?(path)
        @prev_dir = Dir.current
        @prev_child = File.basename(path)
        Dir.cd(path)
        read_directory
      else
        @term.leave_tui

        # Open text files in EDITOR, everything else with OPENER
        opener = @config.opener
        if text_file?(path)
          opener = @config.editor
        end

        Process.run(opener, [path],
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit)
        @term.enter_tui
      end
    end

    private def go_parent
      cwd = Dir.current
      return if cwd == "/"
      @prev_dir = cwd
      @prev_child = nil
      Dir.cd(File.dirname(cwd))
      read_directory
    end

    # ── New: hidden files toggle ───────────────────────────────

    private def toggle_hidden
      @show_hidden = !@show_hidden
      read_directory
    end

    # ── New: quick navigation ──────────────────────────────────

    private def go_home
      Dir.cd(ENV["HOME"])
      @prev_dir = nil
      @prev_child = nil
      read_directory
    end

    private def go_prev
      return unless @prev_dir
      Dir.cd(@prev_dir.not_nil!)
      @prev_child = nil
      read_directory
    end

    private def refresh_dir
      read_directory
    end

    private def go_to_dir
      @term.leave_tui
      path = @term.ask("go to dir:")
      @term.enter_tui

      return if path.empty?
      expanded = path.gsub("~", ENV["HOME"])
      if Dir.exists?(expanded)
        Dir.cd(expanded)
        @prev_dir = nil
        @prev_child = nil
        read_directory
      else
        show_error("dir not found: #{path}")
      end
    end

    private def go_to_trash
      Dir.cd(@config.trash_dir)
      @prev_dir = nil
      @prev_child = nil
      read_directory
    end

    # ── New: file creation ─────────────────────────────────────

    private def new_file
      @term.leave_tui
      name = @term.ask("New file name:")
      @term.enter_tui

      return if name.empty?
      begin
        File.touch(File.join(Dir.current, name))
        read_directory
      rescue e
        show_error("touch: #{e.message}")
      end
    end

    # ── New: file attributes ───────────────────────────────────

    private def show_attributes
      path = @list[@scroll]?
      return unless path

      @term.leave_tui
      puts `stat --format="%A %h %U %G %s %y %n" #{path}`
      @term.keypress("\nPress any key to return...")
      @term.enter_tui
    end

    # ── New: executable toggle ─────────────────────────────────

    private def toggle_executable
      path = @list[@scroll]?
      return unless path
      return unless File.file?(path)

      perms = File.info(path).permissions
      if perms.includes?(::File::Permissions::OtherExecute)
        new_perms = perms & ~::File::Permissions::OtherExecute
      else
        new_perms = perms | ::File::Permissions::OtherExecute
      end
      # Use Process.run for chmod due to Crystal 1.20 union type bug
      Process.run("chmod", [new_perms.value.to_s(8), path.to_s],
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit)
      read_directory
    end

    # ── Marking ────────────────────────────────────────────────

    private def toggle_mark
      path = @list[@scroll]?
      return unless path
      @marked.includes?(path) ? @marked.delete(path) : @marked.add(path)
    end

    private def toggle_mark_all
      if @marked.size == @list.size
        @marked.clear
      else
        @list.each { |p| @marked.add(p) }
      end
    end

    # ── Clipboard ──────────────────────────────────────────────

    private def yank_files
      paths = marked_or_current
      return if paths.empty?
      @clipboard = paths
      @clipboard_mode = :copy
      @marked.clear
    end

    private def cut_files
      paths = marked_or_current
      return if paths.empty?
      @clipboard = paths
      @clipboard_mode = :move
      @marked.clear
    end

    private def paste_files
      return if @clipboard.empty?
      dest_dir = Dir.current


      @clipboard.each do |src|
        name = File.basename(src)
        dest = File.join(dest_dir, name)

        # Duplicate name check
        if File.exists?(dest)
          show_error("already exists: #{name}")
          next
        end

        begin
          case @clipboard_mode
          when :copy
            File.directory?(src) ? FileUtils.cp_r(src, dest) : FileUtils.cp(src, dest)
          when :move
            FileUtils.mv(src, dest)
          end
        rescue e
          show_error("paste: #{e.message}")
        end
      end

      @clipboard.clear
      @clipboard_mode = :none
      read_directory
    end

    # ── Delete ─────────────────────────────────────────────────

    private def delete_files
      paths = marked_or_current
      return if paths.empty?

      @term.leave_tui
      confirmed = @term.confirm?("Trash #{paths.size} item(s)?")
      @term.enter_tui

      return unless confirmed

      # Use custom trash command if set
      if trash_cmd = ENV["FFF_TRASH_CMD"]?
        Process.run(trash_cmd, paths,
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit)
        @marked.clear
        read_directory
        return
      end

      # Default trash: move to trash directory
      trash_dir = @config.trash_dir
      FileUtils.mkdir_p(trash_dir)

      paths.each do |path|
        name = File.basename(path)
        dest = File.join(trash_dir, name)
        begin
          # If destination exists, add timestamp suffix
          if File.exists?(dest)
            timestamp = Time.utc.to_unix
            dest = File.join(trash_dir, "#{name}.#{timestamp}")
          end
          FileUtils.mv(path, dest)
        rescue e
          show_error("trash: #{e.message}")
        end
      end

      @marked.clear
      read_directory
    end

    # ── New directory ──────────────────────────────────────────

    private def new_directory
      @term.leave_tui
      name = @term.ask("New directory name:")
      @term.enter_tui

      return if name.empty?

      # Duplicate name check
      if File.exists?(File.join(Dir.current, name))
        show_error("already exists: #{name}")
        return
      end


      begin
        Dir.mkdir(File.join(Dir.current, name))
        read_directory
      rescue e
        show_error("mkdir: #{e.message}")
      end
    end

    # ── Rename ─────────────────────────────────────────────────

    private def rename_item
      old_path = @list[@scroll]?
      return unless old_path

      old_name = File.basename(old_path)

      @term.leave_tui
      new_name = @term.ask("Rename #{old_name} ->")
      @term.enter_tui

      return if new_name.empty? || new_name == old_name

      new_path = File.join(Dir.current, new_name)

      # Duplicate name check
      if File.exists?(new_path)
        show_error("already exists: #{new_name}")
        return
      end


      begin
        File.rename(old_path, new_path)
        read_directory
      rescue e
        show_error("rename: #{e.message}")
      end
    end

    # ── Search ─────────────────────────────────────────────────

    private def search
      @term.leave_tui
      term = @term.ask("/")
      @term.enter_tui

      if term.empty?
        read_directory
      else
        results = @list.select { |p| File.basename(p).downcase.includes?(term.downcase) }
        if results.empty?
          show_error("No matches for '#{term}'")
        else
          @list = results
          @scroll = 0
          @page_offset = 0
        end
      end
    end

    # ── Preview ────────────────────────────────────────────────

    private def preview_file
      path = @list[@scroll]?
      return unless path && File.file?(path)

      @term.leave_tui

      size = File.size(path)
      mtime = File.info(path).modification_time

      puts "\e[1m#{File.basename(path)}\e[0m  #{human_size(size)}  #{mtime}"
      puts "-" * 60

      if size < 2 * 1024 * 1024
        File.open(path) do |f|
          30.times do
            line = f.gets
            break unless line
            puts line
          end
        end
      else
        puts "(file too large)"
      end

      @term.keypress("\nPress any key to return...")

      @term.enter_tui
    end

    # ── Shell ──────────────────────────────────────────────────

    private def spawn_shell
      @term.leave_tui

      shell = ENV["SHELL"]? || "/bin/sh"
      puts "(fff) spawning #{shell}, type 'exit' to return"
      STDOUT.flush

      Process.run(shell, input: Process::Redirect::Inherit,
                        output: Process::Redirect::Inherit,
                        error: Process::Redirect::Inherit)

      @term.enter_tui
      read_directory
    end

    # ── Quit ───────────────────────────────────────────────────

    private def quit
      @running = false
    end

    private def save_cd_on_exit
      return unless @config.cd_on_exit
      File.write(@config.cd_file, Dir.current)
    end

    # ── Helpers ────────────────────────────────────────────────

    private def marked_or_current : Array(String)
      if @marked.empty?
        path = @list[@scroll]?
        path ? [path] : [] of String
      else
        @marked.to_a
      end
    end

    private def show_error(message : String)
      @error_msg = message
      @error_expires = Time.utc + 2.seconds
    end

    private def human_size(bytes : Int) : String
      case bytes
      when .<(1024)                then "#{bytes}B"
      when .<(1024 * 1024)         then "#{(bytes / 1024.0).round(1)}K"
      when .<(1024 * 1024 * 1024)  then "#{(bytes / (1024.0 * 1024.0)).round(1)}M"
      else "#{(bytes / (1024.0 * 1024.0 * 1024.0)).round(1)}G"
      end
    end
  end
end

app = FFF::Application.new(ARGV)
app.run
