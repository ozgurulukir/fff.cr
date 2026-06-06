require "./progress_bar"

module FFF
  module FileOpHandlers
    def enter_item
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]

      if File.directory?(path)
        begin
          @prev_dir = @dir_manager.current_dir
          @prev_child = File.basename(path)
          Dir.cd(path)
          @dir_manager.read!
          @scroll = 0
          @page_offset = 0
        rescue e : Exception
          Dir.cd(@dir_manager.current_dir) rescue nil
          show_error(e.message)
        end
      elsif text_file?(path)
        open_in_editor(path)
      else
        open_with_opener(path)
      end
    end

    def new_file
      name = @term.prompt_inline("New file name:")
      return if name.nil? || name.empty?

      error = @file_ops.new_file(@dir_manager.current_dir, name)
      if error
        show_error(error)
      else
        show_success("Created #{name}")
      end
      @dir_manager.read!
    end

    def new_directory
      name = @term.prompt_inline("New directory name:")
      return if name.nil? || name.empty?

      error = @file_ops.new_directory(@dir_manager.current_dir, name)
      if error
        show_error(error)
      else
        show_success("Created #{name}/")
      end
      @dir_manager.read!
    end

    def rename_item
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      old_path = @dir_manager.list[@scroll]
      old_name = File.basename(old_path)
      new_name = @term.prompt_inline("Rename to:", old_name)

      return if new_name.nil? || new_name == old_name

      dir = File.dirname(old_path)
      new_path = File.join(dir, new_name)

      if File.exists?(new_path)
        show_error("Target exists: #{new_name}")
        return
      end

      begin
        FileUtils.mv(old_path, new_path)
        show_success("Renamed → #{new_name}")
        @dir_manager.read!
      rescue e : Exception
        show_error(e.message)
      end
    end

    def bulk_rename
      sources = marked_or_current
      error = with_tui_restored { @file_ops.bulk_rename(sources, @config.editor) }

      if error
        show_error(error)
      else
        show_success("Bulk rename complete")
      end
      @marked.clear
      @dir_manager.read!
    end

    def create_symlink
      sources = marked_or_current
      error = @file_ops.create_symlink(sources, @dir_manager.current_dir)

      if error
        show_error(error)
      else
        show_success("#{sources.size} symlink(s) created")
      end
      @marked.clear
      @dir_manager.read!
    end

    def toggle_mark
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      if @marked.includes?(path)
        @marked.delete(path)
      else
        @marked.add(path)
      end
      # Auto-advance cursor after marking (ranger behavior)
      cursor_down
    end

    def toggle_mark_all
      if @marked.size == @dir_manager.list.size
        @marked.clear
        show_info("All marks cleared")
      else
        @dir_manager.list.each { |path| @marked.add(path) }
        show_info("#{@marked.size} items marked")
      end
    end

    def yank_files
      @clipboard = marked_or_current
      if @clipboard.size > 0
        @clipboard_mode = :copy
        show_success("📋 #{@clipboard.size} item(s) copied")
      end
    end

    def cut_files
      @clipboard = marked_or_current
      if @clipboard.size > 0
        @clipboard_mode = :cut
        show_warning("✂ #{@clipboard.size} item(s) cut")
      end
    end

    def paste_files
      return if @clipboard.empty?

      if @clipboard_mode == :cut
        confirm = @term.confirm_inline("Move #{@clipboard.size} item(s)? ")
        return unless confirm
      end

      # Use progress bar for multi-file operations
      count = @clipboard.size
      if count > 5
        op_name = @clipboard_mode == :copy ? "Copying" : "Moving"
        bar = ProgressBar.new(op_name, count)
        error = @file_ops.paste_files_with_progress(@clipboard, @dir_manager.current_dir, @clipboard_mode) do |i, name|
          bar.update(i + 1, name)
          bar.draw(@term.width, @term.height, @config.theme)
        end
      else
        error = @file_ops.paste_files(@clipboard, @dir_manager.current_dir, @clipboard_mode)
      end

      if error
        show_error(error)
      else
        op = @clipboard_mode == :copy ? "pasted" : "moved"
        show_success("✓ #{count} item(s) #{op}")
      end

      @marked.clear
      @dir_manager.read!
    end

    def delete_files
      sources = marked_or_current
      return if sources.empty?

      trash_dir = @config.trash_dir

      confirm = @term.confirm_inline("Delete #{sources.size} item(s)? ")
      return unless confirm

      count = sources.size
      if count > 5
        bar = ProgressBar.new("Deleting", count)
        error = @file_ops.delete_files_with_progress(sources, trash_dir) do |i, name|
          bar.update(i + 1, name)
          bar.draw(@term.width, @term.height, @config.theme)
        end
      else
        error = @file_ops.delete_files(sources, trash_dir)
      end

      if error
        show_error(error)
      else
        show_success("✓ #{count} item(s) deleted")
      end

      @marked.clear
      @dir_manager.read!
    end

    def toggle_executable
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      name = File.basename(path)

      info = File.info?(path)
      return show_error("Cannot check permissions") if info.nil?

      has_exec = info.permissions.includes?(::File::Permissions::OwnerExecute) ||
                 info.permissions.includes?(::File::Permissions::GroupExecute) ||
                 info.permissions.includes?(::File::Permissions::OtherExecute)
      action = has_exec ? "Remove execute" : "Add execute"

      confirm = @term.confirm_inline("#{action} from '#{name}'? ")
      return unless confirm

      result = @file_ops.toggle_executable(path)
      if result && result.includes?("bit")
        show_success(result)
      elsif result
        show_error(result)
      end
    end
  end
end
