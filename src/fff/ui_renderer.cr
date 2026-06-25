require "./config"
require "./format_utils"
require "./theme"
require "./icon_provider"
require "./message_bus"
require "./preview_panel"

module FFF
  class UIRenderer
    @term : Terminal
    @config : Config
    @color_cache : Hash(String, RGB)
    @prev_path : String
    @preview_panel : PreviewPanel

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

    # Map LS_COLORS symbol → theme-compatible RGB
    LS_COLOR_RGB = {
      :red     => {243_u8, 139_u8, 168_u8},
      :green   => {166_u8, 227_u8, 161_u8},
      :yellow  => {249_u8, 226_u8, 175_u8},
      :blue    => {137_u8, 180_u8, 250_u8},
      :magenta => {245_u8, 194_u8, 231_u8},
      :cyan    => {148_u8, 226_u8, 213_u8},
      :white   => {205_u8, 214_u8, 244_u8},
    }

    def initialize(@term : Terminal, @config : Config)
      @color_cache = Hash(String, RGB).new
      @prev_path = ""
      @preview_panel = PreviewPanel.new(@config.preview_width)
    end

    def redraw(state : DrawState)
      @term.refresh_size
      theme = @config.theme

      if state.current_dir != @prev_path
        @color_cache.clear
        @prev_path = state.current_dir
      end

      list_w = effective_list_width

      if state.full
        draw_full(state, theme, list_w)
      else
        draw_incremental(state, theme, list_w)
      end

      if state.show_help
        draw_help_overlay(theme)
      else
        draw_status(state, theme)
        draw_message(state.message, theme)
        draw_rename_prompt(state.rename_new_name, state.cursor_pos, theme) if state.rename_mode
        place_cursor(state)
      end

      STDOUT.flush
    end

    private def draw_full(state : DrawState, theme : Theme, list_w : Int32)
      @term.move_to(0, 0)
      print "\e[2J"
      draw_topbar(state, theme)
      draw_bookmark_bar(state, theme)
      draw_all_lines(state, theme, list_w)
      draw_preview_if_active(state, theme, list_w)
    end

    private def draw_incremental(state : DrawState, theme : Theme, list_w : Int32)
      draw_topbar(state, theme)
      if state.prev_scroll != state.scroll || state.prev_page_offset != state.page_offset
        content_start = bookmark_bar_row + 1
        old_row = state.prev_scroll - state.prev_page_offset
        if old_row >= 0 && old_row < @term.max_items
          if state.prev_scroll < state.list.size
            draw_line(state, theme, old_row, state.prev_scroll, list_w)
          else
            @term.move_to(content_start + old_row, 0)
            print "\e[K"
          end
        end
        new_row = state.scroll - state.page_offset
        if new_row >= 0 && new_row < @term.max_items && state.scroll < state.list.size
          draw_line(state, theme, new_row, state.scroll, list_w)
        end
      end
      draw_preview_if_active(state, theme, list_w)
    end

    private def draw_preview_if_active(state : DrawState, theme : Theme, list_w : Int32)
      return unless @config.preview && @preview_panel.active?(@term.width)
      preview_path = state.preview_path
      start_row = bookmark_bar_row + 1
      end_row = @term.height - 3
      @preview_panel.draw(@term.width, @term.height, preview_path, theme, start_row, end_row)
    end

    # ── Effective dimensions ────────────────────────────────────────

    private def effective_list_width : Int32
      if @config.preview && @preview_panel.active?(@term.width)
        @preview_panel.list_width(@term.width)
      else
        @term.width
      end
    end

    private def bookmark_bar_row : Int32
      # Bookmark bar sits at row 1 (below topbar) if favorites exist
      @config.favorites.empty? ? 0 : 1
    end

    # ── Topbar (Breadcrumb) ─────────────────────────────────────────

    private def draw_topbar(state : DrawState, theme : Theme)
      @term.move_to(0, 0)
      print "\e[K"

      dir = state.current_dir
      home = HOME
      display_path = home && dir.starts_with?(home) ? "~#{dir[home.size..]}" : dir

      sep = File::SEPARATOR.to_s
      segments = display_path.split(sep).reject(&.empty?)

      right, right_width = build_right_side(state)
      folder_count, file_count = count_folders_and_files(state.list, state.stat_cache)
      git_branch = state.git_branch
      size_str = state.total_size > 0 ? FormatUtils.human_size(state.total_size) : "—"

      git_icon = @config.icons ? " " : "git:"
      folder_icon = @config.icons ? "  " : "dirs:"
      file_icon = @config.icons ? "  " : "files:"
      size_icon = @config.icons ? "󰋊 " : "size:"

      breadcrumb, breadcrumb_width = build_breadcrumb(segments, theme)
      git_badge, git_badge_width = if git_branch.empty?
                                     {nil, 0}
                                   else
                                     build_badge(" #{git_icon}#{git_branch} ", theme.symlink_color, theme.selection_bg, theme)
                                   end
      folder_badge, folder_w = build_badge(" #{folder_icon}#{folder_count} ", theme.dir_color, theme.selection_bg, theme)
      file_badge, file_w = build_badge(" #{file_icon}#{file_count} ", theme.topbar_fg, theme.selection_bg, theme)
      size_badge, size_w = build_badge(" #{size_icon}#{size_str} ", theme.accent, theme.selection_bg, theme)

      raw_left_len = 1 + breadcrumb_width
      raw_left_len += git_badge_width
      raw_left_len += folder_w + file_w + size_w

      gap = @term.width - raw_left_len - right_width
      gap = 0 if gap < 0

      print Theme.set_fg_bg(theme.topbar_fg, theme.topbar_bg)
      print breadcrumb
      if git_badge
        print "  " + git_badge.not_nil!
      end
      print "  " + folder_badge
      print "  " + file_badge
      print "  " + size_badge
      print " " * gap
      print Theme.fg(right, theme.topbar_fg)
      print Theme.reset
    end

    private def build_right_side(state : DrawState) : {String, Int32}
      if state.search_mode
        match_info = state.match_count >= 0 ? "  (#{state.match_count} matches)" : ""
        before = state.search_term[0...state.cursor_pos]
        after = state.search_term[state.cursor_pos..]
        right = " / #{before}█#{after}#{match_info} "
      else
        sort_indicator = state.sort_reverse ? " ↑" : " ↓"
        hidden_note = state.hidden_count > 0 ? " (#{state.hidden_count} hidden)" : ""
        right = " #{state.scroll + 1}/#{state.list.size}#{hidden_note}#{sort_indicator} "
      end
      {right, right.size}
    end

    private def count_folders_and_files(list : Array(String), cache : Hash(String, File::Info)) : {Int32, Int32}
      folders = 0
      files = 0
      list.each do |path|
        if info = cache[path]?
          if info.directory?
            folders += 1
          else
            files += 1
          end
        else
          files += 1
        end
      end
      {folders, files}
    end

    private def build_breadcrumb(segments : Array(String), theme : Theme) : {String, Int32}
      breadcrumb = String.build do |s|
        s << " "
        segments.each_with_index do |seg, i|
          if i > 0
            s << Theme.fg(" ❯ ", theme.dim)
          end
          if i == segments.size - 1
            s << Theme.fg_bold(seg, theme.accent)
          else
            s << Theme.fg(seg, theme.topbar_fg)
          end
        end
      end
      width = segments.size > 0 ? segments.join(" ❯ ").size : 0
      {breadcrumb, width}
    end

    private def build_badge(text : String, fore : RGB, back : RGB, theme : Theme) : {String?, Int32}
      badge = Theme.fg_bg(text, fore, back)
      {badge, 2 + text.size}
    end

    # ── Bookmark Bar ────────────────────────────────────────────────

    private def draw_bookmark_bar(state : DrawState, theme : Theme)
      return if state.favorites.empty?

      @term.move_to(1, 0)
      print "\e[K"
      print Theme.set_fg_bg(theme.bookmark_fg, theme.bookmark_bg)

      line = String.build do |s|
        s << " "
        (1..9).each do |i|
          key = i.to_s
          if path = state.favorites[key]?
            name = File.basename(path)
            name = "~" if path == HOME
            # Check if current dir matches this favorite
            is_active = state.current_dir == path ||
                        state.current_dir.starts_with?(path + File::SEPARATOR)
            if is_active
              s << Theme.fg_bold("[#{key}:#{name}]", theme.bookmark_active)
            else
              s << Theme.fg("[#{key}:#{name}]", theme.bookmark_fg)
            end
            s << " "
          end
        end
      end

      # Pad to full width
      # Calculate visible length approximately
      print line
      # Fill remaining with spaces
      print " " * {@term.width - 1, 0}.max
      print Theme.reset
    end

    # ── Status Bar ──────────────────────────────────────────────────

    private def draw_status(state : DrawState, theme : Theme)
      @term.move_to(@term.height - 1, 0)
      print "\e[K"

      # ── left: file info ────────────────────────────────────────
      if state.list.size > 0 && state.scroll < state.list.size
        path = state.list[state.scroll]
        name = File.basename(path)
        info = state.stat_cache[path]?
        linfo = state.lstat_cache[path]?
        if info && info.directory?
          name = "#{name}/"
        elsif linfo && linfo.symlink?
          name = "#{name}@"
        end

        if info
          size = FormatUtils.human_size(info.size)
          perms = permission_string(info)
          left = String.build { |s| s << " " << name << "  " << size << " " << perms }
        else
          left = " #{name}"
        end
      else
        left = ""
      end

      # ── right: clipboard · marks · sort · git ──────────────────
      right_visible_len = 0
      right = String.build { |s|
        if state.clipboard_size > 0
          icon = state.clipboard_mode == :copy ? "📋" : "✂️"
          badge_text = " #{icon} #{state.clipboard_size} "
          badge_color = state.clipboard_mode == :copy ? theme.success : theme.warning
          s << Theme.fg_bg(badge_text, badge_color, theme.selection_bg)
          s << " "
          right_visible_len += badge_text.size + 1
        end

        if state.marked.size > 0
          badge_text = " ● #{state.marked.size} "
          s << Theme.fg_bg(badge_text, theme.marked, theme.selection_bg)
          s << " "
          right_visible_len += badge_text.size + 1
        end

        sort_label = case state.sort_mode
                     when :size then "size"
                     when :time then "time"
                     else            "name"
                     end
        arrow = state.sort_reverse ? "↑" : "↓"
        badge_text = " ↕ #{sort_label}#{arrow} "
        s << Theme.fg_bg(badge_text, theme.accent, theme.selection_bg)
        right_visible_len += badge_text.size

        unless state.git_status.empty?
          s << "  " << colorize_git_status(state.git_status, theme)
          right_visible_len += 2 + state.git_status.size
        end
        s << " "
        right_visible_len += 1
      }

      gap = @term.width - left.size - right_visible_len
      gap = {gap, 0}.max

      print Theme.set_fg_bg(theme.status_fg, theme.status_bg)
      print left
      print " " * gap
      print right
      print Theme.reset
    end

    private def colorize_git_status(status : String, theme : Theme) : String
      String.build do |s|
        status.each_char do |c|
          color = case c
                  when '+' then theme.git_added
                  when '~' then theme.git_modified
                  when '?' then theme.git_untracked
                  when '-' then theme.git_deleted
                  else          theme.status_fg
                  end
          s << Theme.fg(String.build { |buf| buf << c }, color)
        end
      end
    end

    # ── File Lines ──────────────────────────────────────────────────

    private def draw_all_lines(state : DrawState, theme : Theme, list_w : Int32)
      if state.loading
        row = (@term.height / 2).to_i
        col = (@term.width / 2).to_i - 7
        @term.move_to(row, {col, 0}.max)
        spinner = SPINNER_FRAMES[(Time.utc.to_unix * 10 % 10).to_i]
        print Theme.fg(" #{spinner} Loading…", theme.warning)
        return
      end

      content_start = bookmark_bar_row + 1
      max = @term.max_items

      if state.list.empty?
        # Clear all lines in the list area
        (0...max).each do |i|
          @term.move_to(content_start + i, 0)
          print "\e[K"
        end

        # Draw centered empty directory message
        msg = @config.icons ? "  Empty Directory / Dizin Boş" : "Empty Directory / Dizin Boş"
        center_row = content_start + (max // 2)
        center_col = {(list_w - msg.size) // 2, 0}.max

        @term.move_to(center_row, center_col)
        print Theme.fg(msg, theme.dim)
        return
      end

      start_idx = state.page_offset
      end_idx = {state.page_offset + max, state.list.size}.min

      (start_idx...end_idx).each do |i|
        draw_line(state, theme, i - state.page_offset, i, list_w)
      end

      ((end_idx - start_idx)...max).each do |i|
        @term.move_to(content_start + i, 0)
        print "\e[K"
      end
    end

    private def build_display_name(path : String, info : File::Info?, linfo : File::Info?) : String
      icon = @config.icons ? IconProvider.icon_for(path, info, linfo) : ""
      name = File.basename(path)
      suffix = if linfo && linfo.symlink?
                 "@"
               elsif info && info.directory?
                 "/"
               elsif info && info.permissions.includes?(::File::Permissions::OtherExecute)
                 "*"
               else
                 ""
               end
      "#{icon}#{name}#{suffix}"
    end

    private def resolve_effective_color(in_clipboard : Bool, color : RGB, theme : Theme) : RGB
      in_clipboard ? theme.dim : color
    end

    private def draw_line(state : DrawState, theme : Theme, row : Int32, idx : Int32, list_w : Int32)
      return if idx >= state.list.size
      path = state.list[idx]
      selected = (idx == state.scroll)
      is_marked = state.marked.includes?(path)
      linfo = state.lstat_cache[path]?
      info = state.stat_cache[path]?
      color = get_file_color(path, linfo, info, theme)

      display_name = build_display_name(path, info, linfo)

      # Cut items shown dimmed
      in_clipboard = state.clipboard_mode == :cut && state.clipboard_items.includes?(path)
      effective_color = resolve_effective_color(in_clipboard, color, theme)

      # Background color for this line
      bg_color = selected ? theme.selection_bg : nil

      # Right-side column (size/date)
      col_text = ""
      col_raw_len = 0
      if @config.show_columns
        col_text, col_raw_len = format_column(info, theme, bg_color)
      end

      content_start = bookmark_bar_row + 1
      @term.move_to(content_start + row, 0)
      print "\e[K"

      # Prefix length is 3:
      # Selected: "▌" (accent) + (marked ? "▪" : " ") + " "
      # Normal:   " " + (marked ? "▪" : " ") + " "
      prefix_len = 3
      name_area = list_w - prefix_len - col_raw_len
      name_area = 1 if name_area < 1

      # Print prefix
      if selected
        print bg_color ? Theme.fg_bg("▌", theme.accent, bg_color) : Theme.fg("▌", theme.accent)
        if is_marked
          print bg_color ? Theme.fg_bg("▪ ", theme.marked, bg_color) : Theme.fg("▪ ", theme.marked)
        else
          print bg_color ? Theme.fg_bg("  ", theme.fg, bg_color) : "  "
        end
      else
        if is_marked
          print Theme.fg(" ▪ ", theme.marked)
        else
          print "   "
        end
      end

      # Print name (with fuzzy highlighting if searching)
      truncated_name = display_name.size > name_area ? display_name[0...name_area] : display_name
      if state.search_mode && !state.search_term.empty? && !state.search_term.starts_with?('!')
        draw_fuzzy_name(truncated_name, state.search_term.downcase, effective_color, theme, bg_color)
      else
        if selected
          print bg_color ? Theme.fg_bg_bold(truncated_name, effective_color, bg_color) : Theme.fg_bold(truncated_name, effective_color)
        else
          print Theme.fg(truncated_name, effective_color)
        end
      end

      # Pad between name and column
      padding = name_area - truncated_name.size
      if padding > 0
        if bg_color
          print Theme.fg_bg(" " * padding, theme.fg, bg_color)
        else
          print " " * padding
        end
      end

      # Print column
      print col_text unless col_text.empty?

      print Theme.reset
      print "\e[K"
    end

    private def format_column(info : File::Info?, theme : Theme, bg_color : RGB? = nil) : {String, Int32}
      return {"", 0} unless info

      case @config.column_mode
      when :size
        size_str = info.directory? ? "    —" : FormatUtils.human_size(info.size).rjust(5)
        str = " #{size_str} "
        {bg_color ? Theme.fg_bg(str, theme.dim, bg_color) : Theme.fg(str, theme.dim), 7}
      when :date
        date_str = FormatUtils.format_time(info.modification_time)
        str = " #{date_str} "
        {bg_color ? Theme.fg_bg(str, theme.dim, bg_color) : Theme.fg(str, theme.dim), 8}
      when :both
        size_str = info.directory? ? "   —" : FormatUtils.human_size(info.size).rjust(4)
        date_str = FormatUtils.format_time(info.modification_time)
        str = " #{size_str}  #{date_str} "
        {bg_color ? Theme.fg_bg(str, theme.dim, bg_color) : Theme.fg(str, theme.dim), 14}
      else
        size_str = info.directory? ? "    —" : FormatUtils.human_size(info.size).rjust(5)
        str = " #{size_str} "
        {bg_color ? Theme.fg_bg(str, theme.dim, bg_color) : Theme.fg(str, theme.dim), 7}
      end
    end

    private def draw_fuzzy_name(name : String, query : String, base_color : RGB, theme : Theme, bg_color : RGB? = nil)
      query_idx = 0
      match_esc = bg_color ? Theme.set_fg_bg_bold_underline(theme.search_match, bg_color) : Theme.fg_bg_bold_underline("", theme.search_match, theme.bg)
      normal_esc = bg_color ? Theme.set_fg_bg(base_color, bg_color) : Theme.set_fg(base_color)

      result = String.build do |s|
        name.each_char do |char|
          if query_idx < query.size && char.downcase == query[query_idx]
            s << match_esc
            query_idx += 1
          else
            s << normal_esc
          end
          s << char
        end
        s << Theme.reset
      end
      print result
    end

    # ── Message (Toast) ─────────────────────────────────────────────

    private def draw_message(message : Message?, theme : Theme)
      return if message.nil?
      @term.move_to(@term.height - 2, 0)

      color = case message.type
              when .error?   then theme.error
              when .success? then theme.success
              when .warning? then theme.warning
              when .info?    then theme.info
              else                theme.fg
              end

      bg = case message.type
           when .error?   then theme.status_bg
           when .success? then theme.status_bg
           when .warning? then theme.status_bg
           when .info?    then theme.status_bg
           else                theme.status_bg
           end

      msg_text = "#{message.icon}#{message.text}"
      msg_text = msg_text[0...@term.width] if msg_text.size > @term.width
      padded = msg_text + " " * {@term.width - msg_text.size, 0}.max
      print Theme.fg_bg(padded, color, bg)
    end

    # ── Rename Prompt ───────────────────────────────────────────────

    private def draw_rename_prompt(new_name : String, cursor_pos : Int32, theme : Theme)
      @term.move_to(@term.height - 2, 0)
      before = new_name[0...cursor_pos]
      after = new_name[cursor_pos..]
      prompt = " Rename to: #{before}│#{after}"
      prompt = prompt[0...@term.width] if prompt.size > @term.width
      padded = prompt + " " * {@term.width - prompt.size, 0}.max
      print Theme.fg_bg(padded, theme.warning, theme.status_bg)
    end

    # ── Help Overlay ────────────────────────────────────────────────

    private def draw_help_overlay(theme : Theme)
      max_w = HELP_LINES.max_of?(&.size) || 50
      box_w = {max_w + 4, @term.width - 4}.min
      box_h = HELP_LINES.size + 2
      start_row = {(@term.height - box_h) // 2, 0}.max

      # The total box width is box_w + 4 (including the left/right "│ " and " │" paddings)
      total_box_w = box_w + 4
      start_col = {(@term.width - total_box_w) // 2, 0}.max

      top_border = "╭" + "─" * (box_w + 2) + "╮"
      bot_border = "╰" + "─" * (box_w + 2) + "╯"

      (0...box_h).each do |r|
        @term.move_to(start_row + r, start_col)
        print "\e[K"
        if r == 0
          print Theme.fg_bg(top_border, theme.accent, theme.bg)
        elsif r == box_h - 1
          print Theme.fg_bg(bot_border, theme.accent, theme.bg)
        else
          text = HELP_LINES[r - 1]? || ""
          text = text[0...box_w].ljust(box_w)
          print Theme.fg_bg("│ ", theme.accent, theme.bg)
          print colorize_help_line(text, theme)
          print Theme.fg_bg(" │", theme.accent, theme.bg)
        end
      end

      @term.move_to(start_row + box_h + 1, 0)
    end

    private def colorize_help_line(line : String, theme : Theme) : String
      if line.starts_with?("───")
        title = line.gsub("─", "").strip
        dash_left = (line.size - title.size - 2) // 2
        dash_right = line.size - title.size - 2 - dash_left
        String.build do |s|
          s << Theme.fg_bg("─" * dash_left, theme.accent, theme.bg)
          s << Theme.fg_bg(" ", theme.fg, theme.bg)
          s << Theme.fg_bg_bold(title, theme.accent, theme.bg)
          s << Theme.fg_bg(" ", theme.fg, theme.bg)
          s << Theme.fg_bg("─" * dash_right, theme.accent, theme.bg)
        end
      elsif line.strip.empty?
        Theme.fg_bg(line, theme.fg, theme.bg)
      else
        if line.size >= 24
          col1 = line[0...24]
          col2 = line[24..]
          colorize_column(col1, theme) + colorize_column(col2, theme)
        else
          colorize_column(line, theme)
        end
      end
    end

    private def colorize_column(col : String, theme : Theme) : String
      return Theme.fg_bg(col, theme.fg, theme.bg) if col.strip.empty?

      leading_spaces_count = col.size - col.lstrip.size
      leading = col[0...leading_spaces_count]
      rest = col[leading_spaces_count..]

      key_part = rest.split(' ')[0]? || ""
      desc_part = rest[key_part.size..]

      String.build do |s|
        s << Theme.fg_bg(leading, theme.fg, theme.bg)
        s << Theme.fg_bg_bold(key_part, theme.success, theme.bg)
        s << Theme.fg_bg(desc_part, theme.fg, theme.bg)
      end
    end

    # ── Utilities ───────────────────────────────────────────────────

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
        col = 12 + state.cursor_pos
        col = {@term.width - 1, col}.min
        @term.move_to(@term.height - 2, col)
      end
    end

    private def get_file_color(path : String, linfo : File::Info?, info : File::Info?, theme : Theme) : RGB
      if cached = @color_cache[path]?
        return cached
      end

      color = if linfo && linfo.symlink?
                theme.symlink_color
              elsif info && info.directory?
                theme.dir_color
              elsif info && info.permissions.includes?(::File::Permissions::OtherExecute)
                theme.exec_color
              else
                ext = File.extname(path).downcase
                if ls_sym = @config.ls_colors[ext]?
                  LS_COLOR_RGB[ls_sym]? || theme.fg
                else
                  theme.fg
                end
              end

      @color_cache[path] = color
      color
    rescue
      theme.fg
    end
  end
end
