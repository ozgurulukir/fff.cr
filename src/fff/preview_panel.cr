require "./theme"
require "./format_utils"

module FFF
  # PreviewPanel — Side panel showing directory contents or file preview.
  # Activated via FFF_PREVIEW=1 env or config.json "preview": true.
  # Minimum terminal width: 80 columns. Below that, preview is hidden.
  class PreviewPanel
    MIN_WIDTH            =  80
    MAX_PANEL_W          =  50
    PANEL_RATIO          = 0.4
    TEXT_FILE_EXTENSIONS = {".txt", ".cr", ".sh", ".py", ".js", ".ts", ".json", ".yaml", ".yml",
                            ".md", ".html", ".css", ".xml", ".rb", ".go", ".rs", ".c", ".h",
                            ".cpp", ".hpp", ".java", ".php", ".swift", ".kt", ".toml", ".env",
                            ".log", ".csv", ".sql", ".lua", ".ex", ".exs"}

    @cached_path : String
    @cached_entries : Array(String)
    @cached_is_dir : Hash(String, Bool)
    @cached_file_lines : Hash(String, Array(String))

    def initialize
      @cached_path = ""
      @cached_entries = [] of String
      @cached_is_dir = Hash(String, Bool).new
      @cached_file_lines = Hash(String, Array(String)).new
    end

    # Calculate panel width. Returns 0 if terminal is too narrow.
    def panel_width(term_width : Int32) : Int32
      return 0 if term_width < MIN_WIDTH
      w = (term_width * PANEL_RATIO).to_i
      {w, MAX_PANEL_W}.min
    end

    # Calculate left panel (file list) width
    def list_width(term_width : Int32) : Int32
      pw = panel_width(term_width)
      return term_width if pw == 0
      term_width - pw - 1 # -1 for divider
    end

    # Check if preview should be active
    def active?(term_width : Int32) : Bool
      panel_width(term_width) > 0
    end

    # Get preview entries for a path (cached)
    def entries_for(path : String) : Array(String)
      return @cached_entries if path == @cached_path

      @cached_path = path
      @cached_entries = load_entries(path)
      @cached_is_dir[path] = File.directory?(path)
      @cached_entries
    end

    # Draw the preview panel
    def draw(term_width : Int32, term_height : Int32, path : String?, theme : Theme,
             start_row : Int32, end_row : Int32)
      pw = panel_width(term_width)
      return if pw == 0 || path.nil?

      if path != @cached_path
        @cached_file_lines.clear
        @cached_path = ""
      end

      start_col = term_width - pw
      divider_col = start_col - 1

      # Draw vertical divider
      (start_row..end_row).each do |row|
        print "\e[#{row + 1};#{divider_col + 1}H"
        print Theme.fg("│", theme.preview_border)
      end

      # Draw header
      name = File.basename(path)
      header = name.size > pw - 2 ? name[0...pw - 2] : name
      print "\e[#{start_row + 1};#{start_col + 1}H"
      print Theme.fg_bold(" #{header}", theme.preview_header)
      remaining = pw - header.size - 1
      print " " * remaining if remaining > 0

      # Draw entries
      if File.directory?(path)
        draw_directory_preview(path, theme, start_row + 1, end_row, start_col, pw)
      else
        draw_file_preview(path, theme, start_row + 1, end_row, start_col, pw)
      end
    end

    private def draw_directory_preview(path : String, theme : Theme,
                                       start_row : Int32, end_row : Int32,
                                       start_col : Int32, width : Int32)
      entries = entries_for(path)
      max_lines = end_row - start_row

      entries.each_with_index do |entry, i|
        break if i >= max_lines
        row = start_row + i + 1
        print "\e[#{row};#{start_col + 1}H"

        name = File.basename(entry)
        info = File.info?(entry)
        is_dir = info.try(&.directory?) || false

        icon = ""
        suffix = ""
        if is_dir
          icon = " "
          suffix = "/"
          color = theme.dir_color
        else
          color = theme.dim
        end

        display = " #{icon}#{name}#{suffix}"
        display = display[0...width] if display.size > width
        padding = width - display.size
        padding = 0 if padding < 0

        print Theme.fg(display, color)
        print " " * padding if padding > 0
      end

      # Clear remaining lines
      lines_used = {entries.size, max_lines}.min
      ((lines_used + 1)..max_lines).each do |i|
        row = start_row + i
        print "\e[#{row + 1};#{start_col + 1}H"
        print " " * width
      end
    end

    private def draw_file_preview(path : String, theme : Theme,
                                  start_row : Int32, end_row : Int32,
                                  start_col : Int32, width : Int32)
      max_lines = end_row - start_row

      begin
        info = File.info(path)
        size_str = FormatUtils.human_size(info.size)

        info_line = " #{size_str}  #{format_time(info.modification_time)}"
        info_line = info_line[0...width] if info_line.size > width
        print "\e[#{start_row + 1};#{start_col + 1}H"
        print Theme.fg(info_line, theme.dim)

        print "\e[#{start_row + 2};#{start_col + 1}H"
        sep = " " + "─" * (width - 2) + " "
        sep = sep[0...width]
        print Theme.fg(sep, theme.border)

        ext = File.extname(path).downcase

        if TEXT_FILE_EXTENSIONS.includes?(ext)
          render_text_content(path, theme, start_row, end_row, start_col, width, max_lines)
        else
          render_binary_message(theme, start_row, end_row, start_col, width)
        end
      rescue
        render_error(theme, start_row, start_col, width)
      end
    end

    private def render_text_content(path : String, theme : Theme,
                                    start_row : Int32, end_row : Int32,
                                    start_col : Int32, width : Int32,
                                    max_lines : Int32)
      lines = @cached_file_lines[path] ||= read_file_lines(path, max_lines - 2)
      line_idx = 0

      lines.each do |line|
        break if line_idx >= max_lines - 2
        row = start_row + line_idx + 3
        print "\e[#{row};#{start_col + 1}H"
        truncated = line.size > width - 1 ? " #{line[0...width - 2]}" : " #{line}"
        truncated = truncated[0...width]
        padding = width - truncated.size
        padding = 0 if padding < 0
        print Theme.fg(truncated, theme.dim)
        print " " * padding
        line_idx += 1
      end
      clear_remaining_lines(start_row, end_row, start_col, width, line_idx + 3)
    end

    private def render_binary_message(theme : Theme,
                                      start_row : Int32, end_row : Int32,
                                      start_col : Int32, width : Int32)
      print "\e[#{start_row + 3};#{start_col + 1}H"
      bin_msg = " [binary file]"
      bin_msg = bin_msg[0...width]
      print Theme.fg(bin_msg, theme.dim)
      clear_remaining_lines(start_row, end_row, start_col, width, 4)
    end

    private def render_error(theme : Theme,
                             start_row : Int32, start_col : Int32,
                             width : Int32)
      print "\e[#{start_row + 1};#{start_col + 1}H"
      err_msg = " [cannot read]"
      print Theme.fg(err_msg, theme.error)
    end

    private def clear_remaining_lines(start_row : Int32, end_row : Int32,
                                      start_col : Int32, width : Int32,
                                      from_line : Int32)
      max_lines = end_row - start_row
      (from_line..max_lines).each do |i|
        row = start_row + i
        print "\e[#{row};#{start_col + 1}H"
        print " " * width
      end
    end

    private def load_entries(path : String) : Array(String)
      return [] of String unless File.directory?(path)

      entries = Dir.entries(path)
        .reject { |e| e == "." || e == ".." }
        .sort_by { |e| {File.directory?(File.join(path, e)) ? 0 : 1, e.downcase} }
        .first(50) # Cap preview entries
        .map { |e| File.join(path, e) }
      entries
    rescue
      [] of String
    end

    private def read_file_lines(path : String, max_lines : Int32) : Array(String)
      lines = [] of String
      File.each_line(path) do |line|
        break if lines.size >= max_lines
        lines << line
      end
      lines
    rescue
      [] of String
    end

    private def format_time(time : Time) : String
      time.to_local.to_s("%b %d %H:%M")
    rescue
      ""
    end
  end
end
