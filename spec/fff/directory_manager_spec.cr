require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"
require "../../src/fff/directory_manager.cr"

describe FFF::DirectoryManager do
  describe ".new" do
    it "creates directory manager with default state" do
      temp_dir = SpecHelper.create_temp_dir("test_dir_new")
      begin
        dir_manager = FFF::DirectoryManager.new(temp_dir)

        dir_manager.current_dir.should eq(temp_dir)
        dir_manager.list.should be_empty
        dir_manager.full_list.should be_empty
        dir_manager.show_hidden.should be_false
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#read!" do
    it "reads directory contents" do
      temp_dir = SpecHelper.create_temp_dir("test_dir_read")
      begin
        SpecHelper.create_temp_file(temp_dir, "file1.txt", "content")
        SpecHelper.create_temp_file(temp_dir, "file2.txt", "content")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!

        dir_manager.list.should_not be_empty
        dir_manager.list.size.should be > 0
        dir_manager.full_list.should_not be_empty
        dir_manager.full_list.should eq(dir_manager.list)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "filters hidden files when show_hidden is false" do
      temp_dir = SpecHelper.create_temp_dir("test_dir_hidden")
      begin
        SpecHelper.create_temp_file(temp_dir, "normal_file.txt", "content")
        SpecHelper.create_temp_file(temp_dir, ".hidden_file", "hidden content")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!

        dir_manager.list.none? { |f| File.basename(f).starts_with?(".") }.should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#toggle_hidden" do
    it "toggles hidden file visibility" do
      temp_dir = SpecHelper.create_temp_dir("test_dir_toggle")
      begin
        SpecHelper.create_temp_file(temp_dir, "normal_file.txt", "content")
        SpecHelper.create_temp_file(temp_dir, ".hidden_file", "hidden content")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        initial_count = dir_manager.list.size

        dir_manager.toggle_hidden
        count_with_hidden = dir_manager.list.size

        count_with_hidden.should be > initial_count

        dir_manager.toggle_hidden
        final_count = dir_manager.list.size

        final_count.should eq(initial_count)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#go_parent" do
    it "navigates to parent directory" do
      temp_dir = SpecHelper.create_temp_dir("test_parent")
      begin
        sub_dir = File.join(temp_dir, "subdir")
        Dir.mkdir(sub_dir)

        dir_manager = FFF::DirectoryManager.new(sub_dir)
        dir_manager.read!
        dir_manager.go_parent

        dir_manager.current_dir.should eq(temp_dir)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#go_home" do
    it "navigates to home directory" do
      temp_dir = SpecHelper.create_temp_dir("test_home")
      begin
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        home_dir = ENV["HOME"] || Dir.current

        dir_manager.go_home

        dir_manager.current_dir.should eq(home_dir)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#go_to" do
    it "navigates to specified directory" do
      temp_dir = SpecHelper.create_temp_dir("test_go_to")
      begin
        sub_dir = File.join(temp_dir, "subdir")
        Dir.mkdir(sub_dir)

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.go_to(sub_dir)

        dir_manager.current_dir.should eq(sub_dir)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "returns false for invalid path" do
      temp_dir = SpecHelper.create_temp_dir("test_go_to_invalid")
      begin
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.go_to("/nonexistent/path").should be_false
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#refresh!" do
    it "re-reads current directory" do
      temp_dir = SpecHelper.create_temp_dir("test_refresh")
      begin
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!

        SpecHelper.create_temp_file(temp_dir, "new_file.txt", "content")
        dir_manager.refresh!

        dir_manager.list.any? { |f| File.basename(f) == "new_file.txt" }.should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#find_child" do
    it "finds child index by name" do
      temp_dir = SpecHelper.create_temp_dir("test_find_child")
      begin
        SpecHelper.create_temp_file(temp_dir, "target.txt", "content")
        SpecHelper.create_temp_file(temp_dir, "other.txt", "content")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!

        idx = dir_manager.find_child("target.txt")
        idx.should_not be_nil
        File.basename(dir_manager.list[idx.not_nil!]).should eq("target.txt")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "returns nil for non-existent child" do
      temp_dir = SpecHelper.create_temp_dir("test_find_child_nil")
      begin
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!

        dir_manager.find_child("nonexistent.txt").should be_nil
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#sort" do
    it "sorts alphabetically by default" do
      temp_dir = SpecHelper.create_temp_dir("test_sort_alpha")
      begin
        SpecHelper.create_temp_file(temp_dir, "b.txt", "content")
        SpecHelper.create_temp_file(temp_dir, "a.txt", "content")
        SpecHelper.create_temp_file(temp_dir, "c.txt", "content")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!

        names = dir_manager.list.map { |f| File.basename(f) }
        names.should eq(["a.txt", "b.txt", "c.txt"])
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "sorts by size when configured" do
      temp_dir = SpecHelper.create_temp_dir("test_sort_size")
      begin
        SpecHelper.create_temp_file(temp_dir, "small.txt", "s")
        SpecHelper.create_temp_file(temp_dir, "large.txt", "this is a larger file content")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.cycle_sort_mode
        dir_manager.read!

        names = dir_manager.list.map { |f| File.basename(f) }
        names.should eq(["small.txt", "large.txt"])
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "reverses sort order" do
      temp_dir = SpecHelper.create_temp_dir("test_sort_reverse")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "content")
        SpecHelper.create_temp_file(temp_dir, "b.txt", "content")
        SpecHelper.create_temp_file(temp_dir, "c.txt", "content")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.toggle_sort_reverse
        dir_manager.read!

        names = dir_manager.list.map { |f| File.basename(f) }
        names.should eq(["c.txt", "b.txt", "a.txt"])
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end
end
