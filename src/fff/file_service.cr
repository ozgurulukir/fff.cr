require "file_utils"

module FFF
  class FileService
    def self.copy(sources : Array(String), dest_dir : String)
      sources.each do |src|
        name = File.basename(src)
        dest = File.join(dest_dir, name)
        
        # If dest exists, add timestamp suffix to avoid overwrite
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
      sources.each do |src|
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
      sources.each do |src|
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
      sources.each do |src|
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
  end
end
