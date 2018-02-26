require "formula"

class Catch1 < Formula
  homepage "https://github.com/catchorg/Catch2"
  url "https://github.com/catchorg/Catch2/archive/v1.5.4.tar.gz"
  sha256 "1b3e3127e0caa14489f6e34081821dfb29743a3073449f9d20c67bf7edf200d7"

  conflicts_with "catch2", :because => "catch2 installs includes to same directory"

  def install
    include.install Dir['single_include/*']
  end
end
