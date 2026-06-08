require "../../src/fff/format_utils.cr"
require "../../src/fff/icon_provider.cr"
require "spec"
require "../spec_helper.cr"

describe FFF::IconProvider do
  describe ".icon_for" do
    it "returns dir icon for directories" do
      dir = SpecHelper.create_temp_dir("icon_test_dir")
      info = File.info(dir)
      FFF::IconProvider.icon_for(dir, info).should eq(FFF::IconProvider::DIR_ICON)
    end

    it "returns symlink icon for symlinks" do
      dir = SpecHelper.create_temp_dir("icon_symlink_test")
      file_path = SpecHelper.create_temp_file(dir, "target.txt")
      link_path = File.join(dir, "link_to_file")
      File.delete(link_path) rescue nil
      File.symlink(File.basename(file_path), link_path)
      linfo = File.info?(link_path, follow_symlinks: false)
      FFF::IconProvider.icon_for(link_path, linfo).should eq(FFF::IconProvider::SYMLINK_ICON)
    end

    it "returns exec icon for executable files" do
      {% unless flag?(:windows) %}
        dir = SpecHelper.create_temp_dir("icon_exec_test")
        file_path = File.join(dir, "script.sh")
        File.write(file_path, "#!/bin/bash\necho hello")
        File.chmod(file_path, File.info(file_path).permissions | File::Permissions::OwnerExecute)
        info = File.info(file_path)
        FFF::IconProvider.icon_for(file_path, info).should eq(FFF::IconProvider::EXEC_ICON)
      {% end %}
    end

    it "returns extension icon for known extensions" do
      FFF::IconProvider::EXTENSION_ICONS[".cr"]?.should_not be_nil
      FFF::IconProvider::EXTENSION_ICONS[".py"]?.should_not be_nil
      FFF::IconProvider::EXTENSION_ICONS[".json"]?.should_not be_nil
    end

    it "returns special name icon for known filenames" do
      FFF::IconProvider::SPECIAL_NAMES["Makefile"]?.should_not be_nil
      FFF::IconProvider::SPECIAL_NAMES["README.md"]?.should_not be_nil
      FFF::IconProvider::SPECIAL_NAMES["Cargo.toml"]?.should_not be_nil
    end

    it "returns file icon for unknown extensions" do
      dir = SpecHelper.create_temp_dir("icon_unknown_test")
      file_path = SpecHelper.create_temp_file(dir, "unknown.xyzzy", "test")
      info = File.info(file_path)
      FFF::IconProvider.icon_for(file_path, info).should eq(FFF::IconProvider::FILE_ICON)
    end

    it "returns file icon when no info provided" do
      FFF::IconProvider.icon_for("somefile.unknown", nil).should eq(FFF::IconProvider::FILE_ICON)
    end

    it "matches special names before extension lookup" do
      FFF::IconProvider.icon_for("README.md", nil).should eq(FFF::IconProvider::SPECIAL_NAMES["README.md"]?)
    end
  end
end
