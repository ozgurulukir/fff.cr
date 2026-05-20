require "file_utils"

module FFF
  class FileService
    def self.copy(sources : Array(String), dest_dir : String)
      raise "Destination not writable: #{dest_dir}" unless writable_dir?(dest_dir)

      sources.each do |src|
        verify_exists!(src)
        name = File.basename(src)
        dest = File.join(dest_dir, name)

        if File.exists?(dest)
          timestamp = Time.utc.to_unix
          dest = File.join(dest_dir, "#{name}.#{timestamp}")
        end

        if File.directory?(src)
          FileUtils.cp_r(src, dest)
        else
          FileUtils.cp(src, dest)
        end
      end
    end

    def self.move(sources : Array(String), dest_dir : String)
      raise "Destination not writable: #{dest_dir}" unless writable_dir?(dest_dir)

      sources.each do |src|
        verify_exists!(src)
        raise "Source parent not writable: #{File.dirname(src)}" unless writable_dir?(File.dirname(src))

        name = File.basename(src)
        dest = File.join(dest_dir, name)

        if File.exists?(dest)
          timestamp = Time.utc.to_unix
          dest = File.join(dest_dir, "#{name}.#{timestamp}")
        end

        FileUtils.mv(src, dest)
      end
    end

    def self.trash(sources : Array(String), trash_dir : String)
      FileUtils.mkdir_p(trash_dir)
      raise "Trash directory not writable: #{trash_dir}" unless writable_dir?(trash_dir)

      sources.each do |src|
        verify_exists!(src)
        raise "Source parent not writable: #{File.dirname(src)}" unless writable_dir?(File.dirname(src))

        name = File.basename(src)
        dest = File.join(trash_dir, name)

        if File.exists?(dest)
          timestamp = Time.utc.to_unix
          dest = File.join(trash_dir, "#{name}.#{timestamp}")
        end

        FileUtils.mv(src, dest)
      end
    end

    def self.create_symlink(sources : Array(String), dest_dir : String)
      raise "Destination not writable: #{dest_dir}" unless writable_dir?(dest_dir)

      sources.each do |src|
        verify_exists!(src)
        name = File.basename(src)
        dest = File.join(dest_dir, "#{name}.lnk")

        i = 1
        while File.exists?(dest)
          dest = File.join(dest_dir, "#{name}.lnk.#{i}")
          i += 1
        end

        File.symlink(src, dest)
      end
    end

    private def self.writable_dir?(path : String) : Bool
      dir = File.directory?(path) ? path : File.dirname(path)
      info = File.info(dir)
      info.permissions.owner_write? || info.permissions.group_write? || info.permissions.other_write?
    rescue
      false
    end

    private def self.verify_exists!(path : String)
      raise "No such file or directory: #{path}" unless File.exists?(path)
    end
  end
end
