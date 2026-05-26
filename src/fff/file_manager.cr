require "file"
require "file_utils"
require "process"
require "signal"
require "time"
require "./terminal"
require "./config"
require "./directory_manager"
require "./draw_state"
require "./ui_renderer"
require "./input_mode"
require "./file_operations"
require "./search_engine"
require "./navigation_handlers"
require "./file_op_handlers"
require "./view_handlers"

module FFF
  # FileManager - Core TUI file manager coordinator
  class FileManager
    include NavigationHandlers
    include FileOpHandlers
    include ViewHandlers

    # ── Public access (used by tests & handler mixins) ────────────────────────
    # read/write
    property scroll : Int32
    property page_offset : Int32
    property marked : Set(String)
    property clipboard : Array(String)
    property clipboard_mode : Symbol
    property dir_manager : DirectoryManager
    property input_mode : InputMode
    property error_msg : String?
    property error_expires : Time?
    property loading : Bool
    property show_help : Bool
    property git_branch : String
    property git_status : String
    property force_full_redraw : Bool
    # read/write
    property renderer : UIRenderer
    getter term
    getter prev_scroll : Int32
    getter prev_page_offset : Int32
    getter config : Config
    getter fff_level : Int32
    getter running : Bool
    getter picker_mode : Bool
    getter git_dir_cache : String
    getter file_ops : FileOperations
    getter prev_dir : String?
    getter prev_child : String?
    getter prev_list_size : Int32

    # ── Private ivar type declarations ─────────────────────────────────────────

    # Key → handler dispatch table.
    # Built in initialize() using instance-method closures:
    #   ->{ cursor_down } captures self at init time, becomes Proc(Nil).
    # KEY_GROUPS (below) is the central registry — adding a binding = add
    # to KEY_GROUPS + one line here.
    @key_handlers : Hash(String, Proc(Nil))

    def initialize(@config : Config, start_dir : String, @picker_mode = false, term : Terminal? = nil)
      @term = term || Terminal.new
      @dir_manager = DirectoryManager.new(start_dir)
      @renderer = UIRenderer.new(@term, @config)
      @input_mode = InputMode.new(@term)
      @file_ops = FileOperations.new(@config, @term)

      @scroll = 0
      @page_offset = 0
      @marked = Set(String).new
      @clipboard = [] of String
      @clipboard_mode = :none
      @running = true
      @prev_dir = nil
      @prev_child = nil
      @error_msg = nil
      @error_expires = nil
      @prev_scroll = -1
      @prev_page_offset = -1
      @fff_level = (ENV["FFF_LEVEL"]?.try(&.to_i?) || 0)
      @loading = false
      @prev_list_size = -1
      @force_full_redraw = false
      @show_help = false
      @git_branch = ""
      @git_status = ""
      @git_dir_cache = ""

      # Build key → handler dispatch table (run once at startup)
      # All keys resolved here use @config values (already set by this point),
      # so every binding including page_up/down can live in the hash.
      @key_handlers = Hash(String, Proc(Nil)).new
      # Navigation
      @key_handlers["j"] = -> { cursor_down }
      @key_handlers["\e[B"] = -> { cursor_down } # ↓-arrow
      @key_handlers["k"] = -> { cursor_up }
      @key_handlers["\e[A"] = -> { cursor_up } # ↑-arrow
      @key_handlers["h"] = -> { go_parent }
      @key_handlers["\e[D"] = -> { go_parent } # ←-arrow
      @key_handlers["l"] = -> { enter_item }
      @key_handlers["\e[C"] = -> { enter_item } # →-arrow
      @key_handlers["G"] = -> { go_bottom }
      @key_handlers["g"] = -> { go_top }
      # File ops
      @key_handlers[" "] = -> { toggle_mark }
      @key_handlers["m"] = -> { toggle_mark_all }
      @key_handlers["y"] = -> { yank_files }
      @key_handlers["v"] = -> { cut_files }
      @key_handlers["p"] = -> { paste_files }
      @key_handlers["d"] = -> { delete_files }
      @key_handlers["n"] = -> { new_directory }
      @key_handlers["f"] = -> { new_file }
      @key_handlers["r"] = -> { start_rename }
      @key_handlers["b"] = -> { bulk_rename }
      @key_handlers["i"] = -> { preview_file }
      @key_handlers["S"] = -> { create_symlink }
      @key_handlers["X"] = -> { toggle_executable }
      # View / system
      @key_handlers["s"] = -> { spawn_shell }
      @key_handlers["/"] = -> { start_search }
      @key_handlers["."] = -> { @dir_manager.toggle_hidden }
      @key_handlers["t"] = -> { go_to_trash }
      @key_handlers["x"] = -> { show_attributes }
      @key_handlers[":"] = -> { go_to_dir }
      @key_handlers["~"] = -> { @dir_manager.go_home }
      @key_handlers["-"] = -> { go_prev }
      @key_handlers["e"] = -> { @dir_manager.refresh! }
      @key_handlers["="] = -> { @dir_manager.cycle_sort_mode }
      @key_handlers["+"] = -> { @dir_manager.toggle_sort_reverse }
      @key_handlers["?"] = -> { toggle_help }
      @key_handlers["q"] = -> { quit }
      # Dynamic page keys (resolved from @config at init time)
      @key_handlers[@config.key_page_up] = -> { page_up }
      @key_handlers[@config.key_page_down] = -> { page_down }
      # Bookmarks (digit → jump_to_bookmark, digit captured by closure)
      (1..9).each do |d|
        @key_handlers[d.to_s] = -> { jump_to_bookmark(d.to_s) }
      end
    end

    # Key groupings (reference only — dispatch is in @key_handlers hash).
    # Adding a new binding: add the key here, then add one closure line in initialize.
    KEY_GROUPS = {
      "Navigation"  => ["j", "k", "h", "l", "G", "g", "\e[A", "\e[B", "\e[C", "\e[D"],
      "File ops"    => [" ", "m", "y", "v", "p", "d", "n", "f", "r", "b", "i", "S", "X"],
      "View/system" => ["s", "/", ".", "t", "x", ":", "~", "-", "e", "=", "+", "?", "q"],
      "Bookmarks"   => ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
    }

    def run
      Signal::INT.trap { quit }
      Signal::TERM.trap { quit }
      Signal::QUIT.trap { quit }
      Signal::WINCH.trap { handle_resize }

      ENV["FFF_LEVEL"] = @fff_level.to_s

      ensure_dirs
      @term.enter_tui
      @dir_manager.read!
      event_loop
    rescue e : Exception
      STDERR.puts "fff error: #{e.message}"
      if ENV["FFF_DEBUG"]? == "1"
        STDERR.puts e.backtrace.join("\n")
      end
    ensure
      @term.leave_tui
    end

    def ensure_dirs
      FileUtils.mkdir_p(File.join(HOME, ".cache", "fff")) if @config.cd_on_exit
    end

    def handle_resize
      @term.refresh_size
      max = @term.max_items
      @scroll = {@scroll, @dir_manager.list.size - 1}.min if @dir_manager.list.size > 0
      @page_offset = {@page_offset, {@scroll - max + 1, 0}.max}.min if @scroll >= @page_offset + max
      @show_help = false if @show_help
      redraw(true)
    end

    def redraw(full = false)
      check_error_expiry

      list_changed = @dir_manager.list.size != @prev_list_size
      @prev_list_size = @dir_manager.list.size

      update_git_branch

      full_draw = full || @force_full_redraw || @input_mode.active || list_changed || !@error_msg.nil? || @loading || @show_help || @prev_page_offset != @page_offset
      @force_full_redraw = false

      state = DrawState.new(
        scroll: @scroll,
        page_offset: @page_offset,
        list: @dir_manager.list,
        marked: @marked,
        search_mode: @input_mode.active,
        search_term: @input_mode.text,
        rename_mode: @input_mode.mode == :rename,
        rename_new_name: @input_mode.text,
        cursor_pos: @input_mode.cursor_pos,
        prev_scroll: @prev_scroll,
        prev_page_offset: @prev_page_offset,
        current_dir: @dir_manager.current_dir,
        clipboard_mode: @clipboard_mode,
        clipboard_size: @clipboard.size,
        error_msg: @error_msg,
        loading: @loading,
        full: full_draw,
        sort_mode: @dir_manager.sort_mode,
        sort_reverse: @dir_manager.sort_reverse,
        show_help: @show_help,
        git_branch: @git_branch,
        git_status: @git_status,
        total_size: @dir_manager.total_size,
        hidden_count: @dir_manager.hidden_count,
      )
      @renderer.redraw(state)

      @prev_scroll = @scroll
      @prev_page_offset = @page_offset
    end

    def update_git_branch
      dir = @dir_manager.current_dir
      @git_dir_cache ||= ""
      if @git_dir_cache == dir
        return
      end
      @git_dir_cache = dir

      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run("git", ["rev-parse", "--abbrev-ref", "HEAD"], output: output, error: error, chdir: dir)
      if status.success?
        @git_branch = output.to_s.strip
        update_git_status(dir)
      else
        @git_branch = ""
        @git_status = ""
      end
    rescue e : Exception
      @git_branch = ""
      @git_status = ""
    end

    def update_git_status(dir : String)
      out_io = IO::Memory.new
      err_io = IO::Memory.new
      status = Process.run("git", ["status", "--porcelain"], output: out_io, error: err_io, chdir: dir)
      unless status.success?
        @git_status = ""
        return
      end

      staged = 0
      modified = 0
      untracked = 0
      deleted = 0

      out_io.to_s.each_line do |line|
        next if line.empty?
        if line.starts_with?("??")
          untracked += 1
        elsif line.starts_with?("M ") || line.starts_with?("A ") || line.starts_with?("R ")
          staged += 1
        elsif line.starts_with?(" M") || line.starts_with?(" D")
          modified += 1
        elsif line.starts_with?("D ")
          deleted += 1
        elsif line.starts_with?(" D")
          deleted += 1
        end
      end

      @git_status = String.build { |s|
        s << "+#{staged}" if staged > 0
        s << " ~#{modified}" if modified > 0
        s << " ?#{untracked}" if untracked > 0
        s << " -#{deleted}" if deleted > 0
      }
    end

    def check_error_expiry
      if expires = @error_expires
        if Time.utc > expires
          @error_msg = nil
          @error_expires = nil
        end
      end
    end

    def event_loop
      while @running
        redraw

        key = @term.read_keypress
        break if key.nil?

        route_keypress(key)
      end

      perform_shutdown
    end

    def route_keypress(key : String)
      if @input_mode.active
        handle_input_mode(key)
      else
        handle_key(key)
      end
    end

    def perform_shutdown
      save_cd_on_exit if @config.cd_on_exit && !@picker_mode
      write_picker_file if @picker_mode
    end

    def handle_input_mode(key : String)
      if @show_help
        @show_help = false
        @force_full_redraw = true
        return
      end

      # ESC/Ctrl+C: cancel current mode
      if key == "\e" || key == "escape" || key == "\u0003" || (key.bytesize == 1 && key.char_at(0).ord == 27)
        @dir_manager.list = @input_mode.original_list.dup
        @input_mode.end
        @force_full_redraw = true
        return
      end

      complete = @input_mode.handle_key(key)

      if @input_mode.navigating
        cursor_up if key == "\e[A" || key == "up"
        cursor_down if key == "\e[B" || key == "down"
        return
      end

      if complete
        if @input_mode.mode == :search
          handle_search_complete
        elsif @input_mode.mode == :rename
          handle_rename_complete
        end
        @force_full_redraw = true
      else
        live_search if @input_mode.mode == :search && !@input_mode.text.starts_with?('!')
      end
    end

    def handle_search_complete
      @dir_manager.list = @input_mode.apply_search(@input_mode.original_list)
      clamp_scroll
      @input_mode.end(false)
    end

    def handle_rename_complete
      if @scroll < @dir_manager.list.size
        old_path = @dir_manager.list[@scroll]
        error = @input_mode.apply_rename(old_path)
        show_error(error) if error
        @dir_manager.read!
      end
      @input_mode.end
    end

    def live_search
      @dir_manager.list = @input_mode.apply_search(@input_mode.original_list)
    end

    def handle_key(key : String)
      if @show_help
        @show_help = false
        @force_full_redraw = true
        return
      end

      key = @config.key_bindings[key]? || key

      # All keys: single hash lookup → Proc(Nil) closure (or nil → no-op)
      @key_handlers[key]?.try(&.call)
    end

    def start_search
      @dir_manager.list = @dir_manager.full_list.dup
      @input_mode.start_search(@dir_manager.list)
      @force_full_redraw = true
    end

    def start_rename
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      old_path = @dir_manager.list[@scroll]
      old_name = File.basename(old_path)
      @input_mode.start_rename(old_name)
      @force_full_redraw = true
    end

    def with_tui_restored(&)
      @term.leave_tui
      yield
    ensure
      @term.enter_tui
      @force_full_redraw = true
    end

    TEXT_EXTS = {
      ".txt", ".cr", ".sh", ".py", ".js", ".ts", ".json", ".yaml", ".yml",
      ".md", ".html", ".css", ".xml", ".rb", ".go", ".rs", ".c", ".h",
      ".cpp", ".hpp", ".java", ".php", ".swift", ".kt",
    }

    EMPTY_STRING_ARRAY = [] of String

    def text_file?(path : String) : Bool
      return false if File.directory?(path)

      target = File.symlink?(path) ? File.realpath(path) : path
      ext = File.extname(target).downcase

      TEXT_EXTS.includes?(ext) || mime_is_text?(path)
    end

    def mime_is_text?(path : String) : Bool
      output = IO::Memory.new
      status = Process.run("file", ["--mime-type", path], output: output, error: STDERR)
      status.success? && output.to_s.includes?("text/")
    rescue e : Exception
      false
    end

    def open_in_editor(path : String)
      with_tui_restored { Process.run(@config.editor, [path], input: STDIN, output: STDOUT, error: STDERR) }
    end

    def open_with_opener(path : String)
      with_tui_restored { Process.run(@config.opener, [path], input: STDIN, output: STDOUT, error: STDERR) }
    end

    def marked_or_current : Array(String)
      return @marked.to_a if @marked.size > 0
      return EMPTY_STRING_ARRAY if @dir_manager.list.empty?
      return EMPTY_STRING_ARRAY if @scroll >= @dir_manager.list.size
      [@dir_manager.list[@scroll]]
    end

    def quit
      @running = false
    end

    def save_cd_on_exit
      last_file = File.join(HOME, ".cache", "fff", "opened_file")
    end

    def write_picker_file
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      last_file = File.join(HOME, ".cache", "fff", "opened_file")
      File.write(last_file, @dir_manager.list[@scroll])
    end

    def toggle_help
      @show_help = !@show_help
      @force_full_redraw = true
    end

    def clamp_scroll
      if @dir_manager.list.size > 0 && @scroll >= @dir_manager.list.size
        @scroll = @dir_manager.list.size - 1
      end
    end

    def show_error(message : String?)
      return if message.nil? || message.empty?
      @error_msg = message
      @error_expires = Time.utc + Time::Span.new(seconds: 2)
    end
  end
end
