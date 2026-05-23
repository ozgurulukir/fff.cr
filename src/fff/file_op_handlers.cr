module FFF
  module FileOpHandlers
    def enter_item
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]

      if File.directory?(path)
        @prev_dir = @dir_manager.current_dir
        @prev_child = File.basename(path)
        Dir.cd(path)
        @dir_manager.read!
        @scroll = 0
        @page_offset = 0
      elsif text_file?(path)
        open_in_editor(path)
      else
        open_with_opener(path)
      end
    end

    def new_file
      name = with_tui_restored { @term.ask("New file name: ") }

      return if name.nil? || name.empty?

      error = @file_ops.new_file(@dir_manager.current_dir, name)
      show_error(error) if error
      @dir_manager.read!
    end

    def new_directory
      name = with_tui_restored { @term.ask("New directory name: ") }

      return if name.nil? || name.empty?

      error = @file_ops.new_directory(@dir_manager.current_dir, name)
      show_error(error) if error
      @dir_manager.read!
    end

    def rename_item
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      old_path = @dir_manager.list[@scroll]
      old_name = File.basename(old_path)
      new_name = with_tui_restored { @term.ask("Rename to: ", old_name) }

      return if new_name.nil? || new_name == old_name

      dir = File.dirname(old_path)
      new_path = File.join(dir, new_name)

      if File.exists?(new_path)
        show_error("Target exists: #{new_name}")
        return
      end

      begin
        FileUtils.mv(old_path, new_path)
        @dir_manager.read!
      rescue e : Exception
        show_error(e.message)
      end
    end

    def bulk_rename
      sources = marked_or_current
      error = with_tui_restored { @file_ops.bulk_rename(sources, @config.editor) }

      show_error(error) if error
      @marked.clear
      @dir_manager.read!
    end

    def create_symlink
      sources = marked_or_current
      error = @file_ops.create_symlink(sources, @dir_manager.current_dir)

      show_error(error) if error
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
    end

    def toggle_mark_all
      if @marked.size == @dir_manager.list.size
        @marked.clear
      else
        @dir_manager.list.each { |path| @marked.add(path) }
      end
    end

    def yank_files
      @clipboard = marked_or_current
      @clipboard_mode = :copy if @clipboard.size > 0
    end

    def cut_files
      @clipboard = marked_or_current
      @clipboard_mode = :cut if @clipboard.size > 0
    end

    def paste_files
      return if @clipboard.empty?

      error = @file_ops.paste_files(@clipboard, @dir_manager.current_dir, @clipboard_mode)
      show_error(error) if error

      @marked.clear
      @dir_manager.read!
    end

    def delete_files
      sources = marked_or_current
      return if sources.empty?

      trash_dir = File.join(ENV["HOME"], ".local", "share", "fff", "trash")

      confirm = with_tui_restored { @term.confirm?("Delete #{sources.size} item(s)? ") }
      return unless confirm

      error = @file_ops.delete_files(sources, trash_dir)
      show_error(error) if error

      @marked.clear
      @dir_manager.read!
    end

    def toggle_executable
      return if @dir_manager.list.empty?
      return if @scroll >= @dir_manager.list.size

      path = @dir_manager.list[@scroll]
      error = @file_ops.toggle_executable(path)
      show_error(error) if error
    end
  end
end
