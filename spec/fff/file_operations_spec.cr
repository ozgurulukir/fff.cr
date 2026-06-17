require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"
require "../../src/fff/file_operations.cr"
require "../../src/fff/config.cr"
require "../../src/fff/terminal.cr"

describe FFF::FileOperations do
  describe ".new" do
    it "creates with config and terminal" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.should be_a(FFF::FileOperations)
    end
  end

  describe "#paste_files" do
    it "returns nil for empty sources" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.paste_files([] of String, "/tmp", :copy).should be_nil
    end

    it "returns nil for :none mode" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.paste_files(["/tmp/foo"], "/tmp", :none).should be_nil
    end

    it "returns error when source does not exist" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      result = ops.paste_files(["/nonexistent/path/file.txt"], "/tmp", :copy)
      result.should eq("No such file or directory: /nonexistent/path/file.txt")
    end

    it "returns error for first missing source in array" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      result = ops.paste_files(["/tmp", "/nonexistent/path/file.txt"], "/tmp", :copy)
      result.should eq("No such file or directory: /nonexistent/path/file.txt")
    end

    it "copies files successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_paste_copy")
      begin
        src_file = SpecHelper.create_temp_file(temp_dir, "source.txt", "hello")
        dest_dir = File.join(temp_dir, "dest")
        Dir.mkdir_p(dest_dir)

        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.paste_files([src_file], dest_dir, :copy)
        result.should be_nil
        File.exists?(File.join(dest_dir, "source.txt")).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "moves files successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_paste_move")
      begin
        src_file = SpecHelper.create_temp_file(temp_dir, "source.txt", "hello")
        dest_dir = File.join(temp_dir, "dest")
        Dir.mkdir_p(dest_dir)

        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.paste_files([src_file], dest_dir, :cut)
        result.should be_nil
        File.exists?(src_file).should be_false
        File.exists?(File.join(dest_dir, "source.txt")).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#paste_files_with_progress" do
    it "returns nil for empty sources" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.paste_files_with_progress([] of String, "/tmp", :copy) { |i, n| }.should be_nil
    end

    it "returns error when source does not exist" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      result = ops.paste_files_with_progress(["/nonexistent/file.txt"], "/tmp", :copy) { |i, n| }
      result.should eq("No such file or directory: /nonexistent/file.txt")
    end
  end

  describe "#delete_files" do
    it "returns nil for empty sources" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.delete_files([] of String, "/tmp/trash").should be_nil
    end

    it "returns error when source does not exist" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      result = ops.delete_files(["/nonexistent/file.txt"], "/tmp/trash")
      result.should eq("No such file or directory: /nonexistent/file.txt")
    end

    it "moves files to trash successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_delete")
      begin
        src_file = SpecHelper.create_temp_file(temp_dir, "file.txt", "content")
        trash_dir = File.join(temp_dir, "trash")
        Dir.mkdir_p(trash_dir)

        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.delete_files([src_file], trash_dir)
        result.should be_nil
        File.exists?(src_file).should be_false
        File.exists?(File.join(trash_dir, "file.txt")).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#delete_files_with_progress" do
    it "returns nil for empty sources" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.delete_files_with_progress([] of String, "/tmp/trash") { |i, n| }.should be_nil
    end

    it "returns error when source does not exist" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      result = ops.delete_files_with_progress(["/nonexistent/file.txt"], "/tmp/trash") { |i, n| }
      result.should eq("No such file or directory: /nonexistent/file.txt")
    end
  end

  describe "#new_file" do
    it "returns error for empty name" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.new_file("/tmp", "").should eq("Empty filename")
    end

    it "returns error when file already exists" do
      temp_dir = SpecHelper.create_temp_dir("test_new_file_exists")
      begin
        SpecHelper.create_temp_file(temp_dir, "existing.txt", "content")

        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        ops.new_file(temp_dir, "existing.txt").should eq("File exists: existing.txt")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "creates file successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_new_file_ok")
      begin
        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.new_file(temp_dir, "new_file.txt")
        result.should be_nil
        File.exists?(File.join(temp_dir, "new_file.txt")).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#new_directory" do
    it "returns error for empty name" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.new_directory("/tmp", "").should eq("Empty directory name")
    end

    it "returns error when directory already exists" do
      temp_dir = SpecHelper.create_temp_dir("test_new_dir_exists")
      begin
        Dir.mkdir_p(File.join(temp_dir, "existing"))

        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        ops.new_directory(temp_dir, "existing").should eq("Directory exists: existing")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "creates directory successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_new_dir_ok")
      begin
        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.new_directory(temp_dir, "new_dir")
        result.should be_nil
        File.directory?(File.join(temp_dir, "new_dir")).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#create_symlink" do
    it "returns nil for empty sources" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.create_symlink([] of String, "/tmp").should be_nil
    end

    it "returns error when source does not exist" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      result = ops.create_symlink(["/nonexistent/file.txt"], "/tmp")
      result.should eq("No such file or directory: /nonexistent/file.txt")
    end

    it "creates symlink successfully" do
      temp_dir = SpecHelper.create_temp_dir("test_symlink")
      begin
        target = SpecHelper.create_temp_file(temp_dir, "target.txt", "content")

        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.create_symlink([target], temp_dir)
        result.should be_nil
        link_path = File.join(temp_dir, "target.txt.lnk")
        File.symlink?(link_path).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#show_attributes" do
    it "returns error when path does not exist" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      result = ops.show_attributes("/nonexistent/path.txt")
      result.should eq("No such file: /nonexistent/path.txt")
    end

    it "returns file info for existing file" do
      temp_dir = SpecHelper.create_temp_dir("test_attrs")
      begin
        file_path = SpecHelper.create_temp_file(temp_dir, "test.txt", "content")

        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.show_attributes(file_path)
        result.should_not be_nil
        result.as(String).should contain("Type: file")
        result.as(String).should contain("Size: ")
        result.as(String).should contain("Permissions: ")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "returns directory info for existing directory" do
      temp_dir = SpecHelper.create_temp_dir("test_attrs_dir")
      begin
        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.show_attributes(temp_dir)
        result.should_not be_nil
        result.as(String).should contain("Type: directory")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#toggle_executable" do
    it "returns error when path does not exist" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      result = ops.toggle_executable("/nonexistent/path.txt")
      result.should eq("No such file: /nonexistent/path.txt")
    end

    it "returns error for directories" do
      temp_dir = SpecHelper.create_temp_dir("test_toggle_exec_dir")
      begin
        config = FFF::Config.new
        term = FFF::Terminal.new
        ops = FFF::FileOperations.new(config, term)

        result = ops.toggle_executable(temp_dir)
        result.should eq("Cannot change executable bit for directories")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#bulk_rename" do
    it "returns error for empty sources" do
      config = FFF::Config.new
      term = FFF::Terminal.new
      ops = FFF::FileOperations.new(config, term)
      ops.bulk_rename([] of String, "cat").should eq("No files marked")
    end
  end
end
