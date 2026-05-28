require "file_utils"
require "./file_service"
require "./config"

module FFF
  # FileOperations - High-level file operations with UI feedback
  class FileOperations
    @config : Config
    @term : Terminal

    def initialize(@config : Config, @term : Terminal)
    end

    def paste_files(sources : Array(String), dest_dir : String, mode : Symbol) : String?
      return nil if sources.empty? || mode == :none

      sources.each do |src|
        return "No such file or directory: #{src}" unless File.exists?(src)
      end

      begin
        case mode
        when :copy
          FileService.copy(sources, dest_dir)
        when :cut
          FileService.move(sources, dest_dir)
        end
        nil
      rescue e : IO::Error | File::Error
        e.message
      end
    end

    def delete_files(sources : Array(String), trash_dir : String) : String?
      return nil if sources.empty?

      sources.each do |src|
        return "No such file or directory: #{src}" unless File.exists?(src)
      end

      begin
        FileService.trash(sources, trash_dir)
        nil
      rescue e : IO::Error | File::Error
        e.message
      end
    end

    def new_file(dir : String, name : String) : String?
      return "Empty filename" if name.empty?

      path = File.join(dir, name)
      return "File exists: #{name}" if File.exists?(path)

      begin
        File.write(path, "")
        nil
      rescue e : IO::Error | File::Error
        e.message
      end
    end

    def new_directory(dir : String, name : String) : String?
      return "Empty directory name" if name.empty?

      path = File.join(dir, name)
      return "Directory exists: #{name}" if File.exists?(path)

      begin
        Dir.mkdir(path)
        nil
      rescue e : IO::Error | File::Error
        e.message
      end
    end

    def create_symlink(sources : Array(String), dest_dir : String) : String?
      return nil if sources.empty?

      sources.each do |src|
        return "No such file or directory: #{src}" unless File.exists?(src)
      end

      begin
        FileService.create_symlink(sources, dest_dir)
        nil
      rescue e : IO::Error | File::Error
        e.message
      end
    end

    def show_attributes(path : String) : String?
      return "No such file: #{path}" unless File.exists?(path)

      info = File.info(path)
      type = File.directory?(path) ? "directory" : File.symlink?(path) ? "symlink" : "file"
      size = info.size
      perms = info.permissions.to_s

      "Type: #{type}\nSize: #{human_size(size)}\nPermissions: #{perms}\nModified: #{info.modification_time}"
    rescue e : Exception
      e.message
    end

    def toggle_executable(path : String) : String?
      return "No such file: #{path}" unless File.exists?(path)
      return "Cannot change executable bit for directories" if File.directory?(path)

      begin
        info = File.info(path)
        has_exec = info.permissions.includes?(::File::Permissions::OwnerExecute) ||
                   info.permissions.includes?(::File::Permissions::GroupExecute) ||
                   info.permissions.includes?(::File::Permissions::OtherExecute)
        if has_exec
          Process.run("chmod", ["-x", path])
          "Removed executable bit"
        else
          Process.run("chmod", ["+x", path])
          "Added executable bit"
        end
      rescue e : IO::Error | File::Error
        e.message
      end
    end

    def bulk_rename(sources : Array(String), editor : String) : String?
      return "No files marked" if sources.empty?

      temp_path = File.join(Dir.tempdir, "fff_bulk_rename_#{Process.pid}_#{Random.rand(999999)}.txt")
      begin
        # Write original names to temp file
        File.write(temp_path, sources.map { |s| File.basename(s) }.join("\n"))

        # Open editor
        editor_parts = editor.split
        Process.run(editor_parts[0], editor_parts[1...] + [temp_path], input: STDIN, output: STDOUT, error: STDERR)

        # Read new names
        new_names = File.read(temp_path).lines.map(&.strip).reject(&.empty?)

        return "Number of names changed" if new_names.size != sources.size

        # Rename each file
        sources.each_with_index do |src, i|
          new_name = new_names[i]
          next if new_name == File.basename(src)

          new_path = File.join(File.dirname(src), new_name)
          return "Target exists: #{new_name}" if File.exists?(new_path)

          FileUtils.mv(src, new_path)
        end

        nil
      rescue e : IO::Error | File::Error
        e.message
      ensure
        File.delete(temp_path) if File.exists?(temp_path)
      end
    end

    private def human_size(bytes : Int) : String
      FormatUtils.human_size(bytes)
    end
  end
end
