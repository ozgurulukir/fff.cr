require "term-color"
require "./config"
require "./format_utils"

module FFF
  class UIRenderer
    @term : Terminal
    @config : Config
    @color_cache : Hash(String, Symbol)
    @prev_path : String

    HELP_LINES = [
      "───── Navigation ─────",
      " j/k  Down/Up          h/l  Parent/Enter",
      " g/G  Top/Bottom       PgUp/PgDn  Page",
      " .    Toggle hidden    -    Previous dir",
      " ~    Home             :    Go to dir",
      " t    Trash            e    Refresh",
      "",
      "───── File Ops ───────",
      " SPACE  Mark           m    Mark all",
      " y  Copy               v    Cut",
      " p  Paste              d    Delete (trash)",
      " r  Rename             b    Bulk rename",
      " n  New dir            f    New file",
      " S  Symlink            x    Attributes",
      " X  Toggle executable",
      "",
      "───── Misc ───────────",
      " /  Search             i  Preview",
      " s  Shell              =  Cycle sort",
      " +  Reverse sort       1-9  Favorites",
      " q  Quit               ?  This help",
    ]

    SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    def initialize(@term : Terminal, @config : Config)
      @color_cache = Hash(String, Symbol).new
      @prev_path = ""
    end

    def redraw(state : DrawState)
      @term.refresh_size

      if state.full
        @term.move_to(0, 0)
        print "\e[2J"
        draw_topbar(state)
        draw_all_lines(state.list, state.scroll, state.page_offset, state.marked, state.search_mode, state.search_term, state.loading)
      else
        draw_topbar(state)
        if state.prev_scroll != state.scroll || state.prev_page_offset != state.page_offset
          old_row = state.prev_scroll - state.prev_page_offset
          if old_row >= 0 && old_row < @term.max_items
            @term.move_to(old_row + 1, 0)
            draw_line(old_row, state.prev_scroll, state.list, state.marked, state.scroll, state.search_mode, state.search_term) if state.prev_scroll < state.list.size
          end
          new_row = state.scroll - state.page_offset
          if new_row >= 0 && new_row < @term.max_items && state.scroll < state.list.size
            draw_line(new_row, state.scroll, state.list, state.marked, state.scroll, state.search_mode, state.search_term)
          end
        end
      end

      if state.show_help
        draw_help_overlay
      else
        draw_status(state)
        draw_error(state.error_msg, @term.width)
        draw_rename_prompt(state.rename_new_name, state.cursor_pos, @term.width) if state.rename_mode
        place_cursor(state)
      end

      STDOUT.flush
    end

    def clear_cache
      @color_cache.clear
    end

    def human_size(bytes : Int) : String
      FormatUtils.human_size(bytes)
    end

    private def draw_topbar(state : DrawState)
      @term.move_to(0, 0)
      print "\e[K"

      dir = state.current_dir
      home = ENV["HOME"]
      display_path = home && dir.starts_with?(home) ? "~#{dir[home.size..]}" : dir

      git_branch = state.git_branch
      file_count = state.list.size
      size_str = state.total_size > 0 ? FormatUtils.human_size(state.total_size) : "—"
      file_badge = "#{file_count} files  #{size_str}"

      right = if state.search_mode
                before = state.search_term[0...state.cursor_pos]
                after = state.search_term[state.cursor_pos..]
                "Search: #{before}|#{after}"
              else
                sort_indicator = state.sort_reverse ? " ↑" : " ↓"
                hidden_note = state.hidden_count > 0 ? " (#{state.hidden_count} hidden)" : ""
                "#{state.scroll + 1}/#{state.list.size}#{hidden_note}#{sort_indicator}"
              end

      avail = @term.width

      # Build raw visible text (no ANSI), truncate, then colorize branch — avoids
      # ANSI-escape bytes corrupting the truncation math.
      if git_branch.empty?
        raw_left = String.build { |s| s << display_path << "  " << file_badge }
      else
        raw_left = String.build { |s| s << display_path << "  (#{git_branch})  " << file_badge }
      end

      if raw_left.size + right.size + 1 > avail
        raw_left = raw_left[0...{avail - right.size - 1, 0}.max]
      end

      left = if !git_branch.empty? && raw_left.includes?("(#{git_branch})")
               cb = Term::Color.truecolor_string("(#{git_branch})", fore: Term::Color.color(:magenta))
               raw_left.sub("(#{git_branch})", cb)
             else
               raw_left
             end

      # raw_left for gap math (visible width); left for terminal output (with ANSI)
      gap = avail - raw_left.size - right.size
      gap = 0 if gap < 0
      raw_line = raw_left + " " * gap + right
      raw_line = raw_line[0...avail]
      # Re-apply color to branch in the possibly-truncated raw line
      left = if !git_branch.empty? && raw_line.includes?("(#{git_branch})")
               cb = Term::Color.truecolor_string("(#{git_branch})", fore: Term::Color.color(:magenta))
               raw_line.sub("(#{git_branch})", cb)
              else
                raw_line
              end

      line = left

      print Term::Color.truecolor_string(line, fore: Term::Color.color(:white), back: Term::Color.color(:blue))
    end

    private def draw_status(state : DrawState)
      @term.move_to(@term.height - 1, 0)
      print "\e[K"

      # ── left: file info ────────────────────────────────────────
      if state.list.size > 0 && state.scroll < state.list.size
        path = state.list[state.scroll]
        name = File.basename(path)
        if File.directory?(path)
          name = "#{name}/"
        elsif File.symlink?(path)
          name = "#{name}@"
        end

        info = File.info?(path)
        if info
          size = FormatUtils.human_size(info.size)
          perms = permission_string(info)
          left = String.build { |s| s << name << "  " << size << " " << perms }
        else
          left = name
        end
      else
        left = ""
      end

      # ── right: clipboard · marks · sort · git ──────────────────
      right = String.build { |s|
        if state.clipboard_size > 0
          icon = state.clipboard_mode == :copy ? "📋" : "✂️"
          s << icon << state.clipboard_size.to_s
        end

        if state.marked.size > 0
          s << "●" << state.marked.size.to_s unless state.clipboard_size > 0
        end

        sort_label = case state.sort_mode
                     when :size then "size"
                     when :time then "time"
                     else            "name"
                     end
        arrow = state.sort_reverse ? "↑" : "↓"
        s << " " << sort_label << arrow

        unless state.git_status.empty?
          s << "  " << colorize_git_status(state.git_status)
        end
      }

      # pad right side so git status aligns to terminal right edge
      gap = @term.width - left.size - right.size - 1
      gap = {gap, 0}.max
      line = String.build { |s| s << left << " " * gap << right }
      line = line[0...@term.width]

      print Term::Color.truecolor_string(line, fore: Term::Color.color(:white), back: Term::Color.color(:black))
    end

    private def colorize_git_status(status : String) : String
      String.build do |s|
        status.each_char do |c|
          color = case c
                  when '+' then Term::Color.color(:green)
                  when '~' then Term::Color.color(:yellow)
                  when '?' then Term::Color.color(:cyan)
                  when '-' then Term::Color.color(:red)
                  else          Term::Color.color(:white)
                  end
          s << Term::Color.truecolor_string(String.build { |buf| buf << c }, fore: color)
        end
      end
    end

    private def draw_all_lines(list : Array(String), scroll : Int32, page_offset : Int32, marked : Set(String), search_mode : Bool, search_term : String, loading : Bool)
      if loading
        row = (@term.height / 2).to_i
        col = (@term.width / 2).to_i - 7
        @term.move_to(row, {col, 0}.max)
        spinner = SPINNER_FRAMES[(Time.utc.to_unix * 10 % 10).to_i]
        print Term::Color.truecolor_string(" #{spinner} Loading…", fore: Term::Color.color(:yellow))
        return
      end

      max = @term.max_items
      start_idx = page_offset
      end_idx = {page_offset + max, list.size}.min

      (start_idx...end_idx).each do |i|
        draw_line(i - page_offset, i, list, marked, scroll, search_mode, search_term)
      end

      ((end_idx - start_idx)...max).each do |i|
        @term.move_to(i + 1, 0)
        print "\e[K"
      end
    end

    private def draw_line(row : Int32, idx : Int32, list : Array(String), marked : Set(String), scroll : Int32, search_mode : Bool, search_term : String)
      path = list[idx]
      name = File.basename(path)
      selected = (idx == scroll)
      is_marked = marked.includes?(path)
      color = get_file_color(path)

      # Visual suffix: 📁 dir  ·  * executable  ·  @ symlink
      suffix = if File.symlink?(path)
                 "@"
               elsif File.directory?(path)
                 "/"
               elsif File.info?(path).try(&.permissions.includes?(::File::Permissions::OtherExecute))
                 "*"
               else
                 ""
               end
      display_name = "#{name}#{suffix}"
      prefix = is_marked ? " ● " : "   "

      @term.move_to(row + 1, 0)
      if selected
        line_text = "#{prefix}#{display_name}".ljust(@term.width)
        print Term::Color.truecolor_string(line_text, fore: Term::Color.color(:white), back: Term::Color.color(:blue))
      else
        print Term::Color.truecolor_string(prefix, fore: Term::Color.color(is_marked ? :yellow : :white))
        if search_mode && !search_term.empty? && !search_term.starts_with?('!')
          draw_fuzzy_name(display_name, search_term.downcase, color)
        else
          print Term::Color.truecolor_string(display_name, fore: Term::Color.color(color))
        end
        print "\e[K"
      end
    end

    private def draw_fuzzy_name(name : String, query : String, base_color : Symbol)
      query_idx = 0
      name.each_char do |char|
        if query_idx < query.size && char.downcase == query[query_idx]
          print Term::Color.truecolor_string(String.build { |s| s << char }, fore: Term::Color.color(:yellow), back: Term::Color.color(:black), bold: true, underline: true)
          query_idx += 1
        else
          print Term::Color.truecolor_string(String.build { |s| s << char }, fore: Term::Color.color(base_color))
        end
      end
    end

    private def draw_error(error_msg : String?, width : Int32)
      return if error_msg.nil?
      @term.move_to(@term.height - 2, 0)
      msg = error_msg.to_s.ljust(width)[0...width]
      print Term::Color.truecolor_string(msg, fore: Term::Color.color(:red), back: Term::Color.color(:blue))
    end

    private def draw_rename_prompt(new_name : String, cursor_pos : Int32, width : Int32)
      @term.move_to(@term.height - 2, 0)
      before = new_name[0...cursor_pos]
      after = new_name[cursor_pos..]
      prompt = "Rename to: #{before}|#{after}"
      prompt = prompt.ljust(width)[0...width]
      print Term::Color.truecolor_string(prompt, fore: Term::Color.color(:yellow), back: Term::Color.color(:blue))
    end

    private def draw_help_overlay
      max_w = HELP_LINES.max_of?(&.size) || 50
      box_w = {max_w + 4, @term.width - 4}.min
      box_h = HELP_LINES.size + 2
      start_row = {(@term.height - box_h) // 2, 0}.max
      start_col = {(@term.width - box_w) // 2, 0}.max

      top_border = "╭" + "─" * box_w + "╮"
      bot_border = "╰" + "─" * box_w + "╯"

      (0...box_h).each do |r|
        @term.move_to(start_row + r, start_col)
        print "\e[K"
        if r == 0
          print Term::Color.truecolor_string(top_border, fore: Term::Color.color(:cyan), back: Term::Color.color(:black))
        elsif r == box_h - 1
          print Term::Color.truecolor_string(bot_border, fore: Term::Color.color(:cyan), back: Term::Color.color(:black))
        else
          text = HELP_LINES[r - 1]? || ""
          text = text[0...box_w].ljust(box_w)
          line_body = String.build { |s| s << "│ " << text << " │" }
          print Term::Color.truecolor_string(line_body, fore: Term::Color.color(:white), back: Term::Color.color(:black))
        end
      end

      @term.move_to(start_row + box_h + 1, 0)
    end

    private def permission_string(info : File::Info) : String
      perms = info.permissions
      str = perms.owner_read? ? "r" : "-"
      str += perms.owner_write? ? "w" : "-"
      str += perms.owner_execute? ? "x" : "-"
      str += perms.group_read? ? "r" : "-"
      str += perms.group_write? ? "w" : "-"
      str += perms.group_execute? ? "x" : "-"
      str += perms.other_read? ? "r" : "-"
      str += perms.other_write? ? "w" : "-"
      str += perms.other_execute? ? "x" : "-"
      str
    end

    private def place_cursor(state : DrawState)
      if state.search_mode
        @term.move_to(0, @term.width - 1)
      elsif state.rename_mode
        col = 11 + state.cursor_pos
        col = {@term.width - 1, col}.min
        @term.move_to(@term.height - 2, col)
      end
    end

    private def get_file_color(path : String) : Symbol
      if cached = @color_cache[path]?
        return cached
      end

      color = if File.directory?(path)
                :blue
              elsif (info = File.info?(path)) && info.permissions.includes?(::File::Permissions::OtherExecute)
                :green
              else
                ext = File.extname(path).downcase
                @config.ls_colors[ext]? || :white
              end

      @color_cache[path] = color
      color
    rescue
      :white
    end
  end
end
