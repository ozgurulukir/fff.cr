require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"
require "../../src/fff/file_service.cr"

describe FFF::FileService do
  describe ".copy" do
    it "copies files successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_copy")
      begin
        source_file = SpecHelper.create_temp_file(temp_dir, "source.txt", "source content")
        dest_dir = File.join(temp_dir, "dest")
        Dir.mkdir_p(dest_dir)

        FFF::FileService.copy([source_file], dest_dir)

        File.exists?(File.join(dest_dir, "source.txt")).should be_true
        File.read(File.join(dest_dir, "source.txt")).should eq("source content")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "raises when source doesn't exist" do
      temp_dir = SpecHelper.create_temp_dir("test_copy_missing")
      begin
        expect_raises(Exception, "No such file or directory") do
          FFF::FileService.copy(["/nonexistent/source.txt"], temp_dir)
        end
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "handles file name conflict with timestamp" do
      temp_dir = SpecHelper.create_temp_dir("test_copy_conflict")
      begin
        source_file = SpecHelper.create_temp_file(temp_dir, "source.txt", "content")
        dest_dir = File.join(temp_dir, "dest")
        Dir.mkdir_p(dest_dir)

        existing_file = File.join(dest_dir, "source.txt")
        File.write(existing_file, "existing content")

        FFF::FileService.copy([source_file], dest_dir)

        File.read(existing_file).should eq("existing content")
        Dir.glob(File.join(dest_dir, "source.txt.*").gsub('\\', '/')).size.should eq(1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "copies directories recursively" do
      temp_dir = SpecHelper.create_temp_dir("test_copy_recursive")
      begin
        source_dir = File.join(temp_dir, "source")
        dest_dir = File.join(temp_dir, "dest")
        Dir.mkdir_p(source_dir)
        Dir.mkdir_p(dest_dir)
        SpecHelper.create_temp_file(source_dir, "file1.txt", "content1")
        Dir.mkdir_p(File.join(source_dir, "subdir"))
        SpecHelper.create_temp_file(File.join(source_dir, "subdir"), "file2.txt", "content2")

        FFF::FileService.copy([source_dir], dest_dir)

        File.exists?(File.join(dest_dir, "source", "file1.txt")).should be_true
        File.exists?(File.join(dest_dir, "source", "subdir", "file2.txt")).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe ".move" do
    it "moves files successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_move")
      begin
        source_file = SpecHelper.create_temp_file(temp_dir, "source.txt", "content")
        dest_dir = File.join(temp_dir, "dest")
        Dir.mkdir_p(dest_dir)

        FFF::FileService.move([source_file], dest_dir)

        File.exists?(source_file).should be_false
        File.exists?(File.join(dest_dir, "source.txt")).should be_true
        File.read(File.join(dest_dir, "source.txt")).should eq("content")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "handles file name conflict with timestamp" do
      temp_dir = SpecHelper.create_temp_dir("test_move_conflict")
      begin
        source_file = SpecHelper.create_temp_file(temp_dir, "source.txt", "content")
        dest_dir = File.join(temp_dir, "dest")
        Dir.mkdir_p(dest_dir)

        existing_file = File.join(dest_dir, "source.txt")
        File.write(existing_file, "existing content")

        FFF::FileService.move([source_file], dest_dir)

        File.exists?(source_file).should be_false
        File.read(existing_file).should eq("existing content")
        Dir.glob(File.join(dest_dir, "source.txt.*").gsub('\\', '/')).size.should eq(1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe ".trash" do
    it "moves file to trash directory" do
      temp_dir = SpecHelper.create_temp_dir("test_trash")
      begin
        trash_dir = File.join(temp_dir, "trash")
        Dir.mkdir_p(trash_dir)

        source_file = SpecHelper.create_temp_file(temp_dir, "file.txt", "content")

        FFF::FileService.trash([source_file], trash_dir)

        File.exists?(source_file).should be_false
        File.exists?(File.join(trash_dir, "file.txt")).should be_true
        File.read(File.join(trash_dir, "file.txt")).should eq("content")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "handles trash directory conflict with timestamp" do
      temp_dir = SpecHelper.create_temp_dir("test_trash_conflict")
      begin
        trash_dir = File.join(temp_dir, "trash")
        Dir.mkdir_p(trash_dir)

        existing_file = File.join(trash_dir, "file.txt")
        File.write(existing_file, "existing content")

        source_file = SpecHelper.create_temp_file(temp_dir, "file.txt", "new content")

        FFF::FileService.trash([source_file], trash_dir)

        File.exists?(source_file).should be_false
        File.read(existing_file).should eq("existing content")
        Dir.glob(File.join(trash_dir, "file.txt.*").gsub('\\', '/')).size.should eq(1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "avoids overwriting duplicates in trash within the same second" do
      temp_dir = SpecHelper.create_temp_dir("test_trash_multi_conflict")
      begin
        trash_dir = File.join(temp_dir, "trash")
        Dir.mkdir_p(trash_dir)

        File.write(File.join(trash_dir, "file.txt"), "already in trash")

        source_dir1 = File.join(temp_dir, "dir1")
        source_dir2 = File.join(temp_dir, "dir2")
        Dir.mkdir_p(source_dir1)
        Dir.mkdir_p(source_dir2)

        file1 = SpecHelper.create_temp_file(source_dir1, "file.txt", "first copy")
        file2 = SpecHelper.create_temp_file(source_dir2, "file.txt", "second copy")

        FFF::FileService.trash([file1, file2], trash_dir)

        files_in_trash = Dir.children(trash_dir)
        files_in_trash.size.should eq(3)
        files_in_trash.should contain("file.txt")

        contents = files_in_trash.map { |f| File.read(File.join(trash_dir, f)) }
        contents.should contain("already in trash")
        contents.should contain("first copy")
        contents.should contain("second copy")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe ".create_symlink" do
    it "creates symbolic links successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_symlink")
      begin
        target_file = SpecHelper.create_temp_file(temp_dir, "target.txt", "content")
        dest_dir = File.join(temp_dir, "links")
        Dir.mkdir_p(dest_dir)

        FFF::FileService.create_symlink([target_file], dest_dir)

        link_path = File.join(dest_dir, "target.txt.lnk")
        File.symlink?(link_path).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "returns false when target doesn't exist" do
      temp_dir = SpecHelper.create_temp_dir("test_symlink_missing")
      begin
        dest_dir = File.join(temp_dir, "links")
        Dir.mkdir_p(dest_dir)

        expect_raises(Exception, "No such file or directory") do
          FFF::FileService.create_symlink(["/nonexistent/file.txt"], dest_dir)
        end
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end
end
