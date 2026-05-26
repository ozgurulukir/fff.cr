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
    property scroll           : Int32
    property page_offset      : Int32
    property marked           : Set(String)
    property clipboard        : Array(String)
    property clipboard_mode   : Symbol
    property dir_manager      : DirectoryManager
    property input_mode       : InputMode
    property error_msg        : String?
    property error_expires    : Time?
    property loading          : Bool
    property show_help        : Bool
    property git_branch       : String
    property git_status       : String
    property force_full_redraw : Bool
     # read/write
     property renderer         : UIRenderer
     getter term
     getter prev_scroll        : Int32
    getter prev_page_offset   : Int32
    getter config             : Config
    getter fff_level          : Int32
    getter running            : Bool
    getter picker_mode        : Bool
    getter git_dir_cache      : String
    getter file_ops           : FileOperations
    getter prev_dir           : String?
    getter prev_child         : String?
    getter prev_list_size     : Int32

    # ── Private state not exposed publicly ────────────────────────────────────

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
      @fff_level = (ENV["FFF_LEVEL"]?.try(&.to_i) || 0)
      @loading = false
      @prev_list_size = -1
      @force_full_redraw = false
      @show_help = false
      @git_branch = ""
      @git_status = ""
      @git_dir_cache = ""
    end

    # Key groupings (reference only — dispatch is in handle_key case/when).
    # Adding a new binding: add the key to the relevant group, then add a `when`
    # clause in handle_key — same single dispatch location as before, better docs.
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

      at_exit { @term.leave_tui if @running }
      ENV["FFF_LEVEL"] = @fff_level.to_s

      ensure_dirs
      @term.enter_tui
      @dir_manager.read!
      event_loop
    rescue e : Exception
      @term.leave_tui
      STDERR.puts "fff error: #{e.message}"
      if ENV["FFF_DEBUG"]? == "1"
        STDERR.puts e.backtrace.join("\n")
      end
    end

    def ensure_dirs
      FileUtils.mkdir_p(File.join(ENV["HOME"], ".cache", "fff")) if @config.cd_on_exit
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
        @git_dir_cache = ""
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
      @term.leave_tui
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

      case key
      # ── Navigation ───────────────────────────────────────────────────────
      when "j", "\e[B"           then cursor_down
      when "k", "\e[A"           then cursor_up
      when @config.key_page_up   then page_up
      when @config.key_page_down then page_down
      when "h", "\e[D"           then go_parent
      when "l", "\e[C"           then enter_item
      when "G"                   then go_bottom
      when "g"                   then go_top
      # ── File ops ──────────────────────────────────────────────────────────
      when " "                   then toggle_mark
      when "m"                   then toggle_mark_all
      when "y"                   then yank_files
      when "v"                   then cut_files
      when "p"                   then paste_files
      when "d"                   then delete_files
      when "n"                   then new_directory
      when "f"                   then new_file
      when "r"                   then start_rename
      when "b"                   then bulk_rename
      when "i"                   then preview_file
      when "S"                   then create_symlink
      when "X"                   then toggle_executable
      # ── View / system ─────────────────────────────────────────────────────
      when "s"                   then spawn_shell
      when "/"                   then start_search
      when "."                   then @dir_manager.toggle_hidden
      when "t"                   then go_to_trash
      when "x"                   then show_attributes
      when ":"                   then go_to_dir
      when "~"                   then @dir_manager.go_home
      when "-"                   then go_prev
      when "e"                   then @dir_manager.refresh!
      when "="                   then @dir_manager.cycle_sort_mode
      when "+"                   then @dir_manager.toggle_sort_reverse
      when "?"                   then toggle_help
      when "q"                   then quit
      # ── Bookmarks ─────────────────────────────────────────────────────────
      when "1", "2", "3", "4", "5", "6", "7", "8", "9"
        jump_to_bookmark(key)
      end
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
      last_file = File.join(ENV["HOME"], ".cache", "fff", "opened_file")
      File.write(last_file, @dir_manager.current_dir)
    end

    def write_picker_file
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      last_file = File.join(ENV["HOME"], ".cache", "fff", "opened_file")
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
