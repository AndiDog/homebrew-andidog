class Ice36 < Formula
  desc "Comprehensive RPC framework"
  homepage "https://zeroc.com"
  url "https://github.com/zeroc-ice/ice/archive/v3.6.4.tar.gz"
  sha256 "4f5cc5e09586eab7de7745bbdc5fbf383c59f8fdc561264d4010bba19afdde2a"

  option "with-java", "Build Ice for Java and the IceGrid Admin app"
  option "with-php", "Build Ice for PHP"
  option "without-python", "Build without Ice for Python"

  depends_on "mcpp"
  depends_on :java => ["1.7+", :optional]
  depends_on :macos => :mavericks
  depends_on "python"

  resource "berkeley-db" do
    url "https://zeroc.com/download/homebrew/db-5.3.28.NC.brew.tar.gz"
    sha256 "8ac3014578ff9c80a823a7a8464a377281db0e12f7831f72cef1fd36cd506b94"
  end

  def install
    resource("berkeley-db").stage do
      # BerkeleyDB dislikes parallel builds
      ENV.deparallelize
      args = %W[
        --disable-debug
        --prefix=#{libexec}
        --mandir=#{libexec}/man
        --enable-cxx
      ]

      if build.with? "java"
        args << "--enable-java"

        # @externl from ZeroC submitted this patch to Oracle through an internal ticket system
        inreplace "dist/Makefile.in", "@JAVACFLAGS@", "@JAVACFLAGS@ -source 1.7 -target 1.7"
      end

      # BerkeleyDB requires you to build everything from the build_unix subdirectory
      cd "build_unix" do
        system "../dist/configure", *args
        system "make", "install"
      end
    end

    inreplace "cpp/src/slice2js/Makefile", /install:/, "dontinstall:"

    # Unset ICE_HOME as it interferes with the build
    ENV.delete("ICE_HOME")
    ENV.delete("USE_BIN_DIST")
    ENV.delete("CPPFLAGS")
    ENV.O2

    # Ensure Gradle uses a writable directory even in sandbox mode
    ENV["GRADLE_USER_HOME"] = buildpath/".gradle"

    args = %W[
      prefix=#{prefix}
      embedded_runpath_prefix=#{prefix}
      USR_DIR_INSTALL=yes
      SLICE_DIR_SYMLINK=yes
      OPTIMIZE=yes
      DB_HOME=#{libexec}
      MCPP_HOME=#{Formula["mcpp"].opt_prefix}
    ]

    cd "cpp" do
      system "make", "install", *args
    end

    if build.with? "python"
      args << "PYTHON=#{HOMEBREW_PREFIX/"bin/python2"}"
      cd "python" do
        inreplace "config/install_dir", "print(e.install_dir)", "print('#{lib}/python2.7/site-packages')"
        inreplace "config/Make.rules", /^\s*install_libdir\s*=.*/, "install_libdir = #{lib/"python2.7/site-packages"}"
        inreplace "config/Make.rules", /^LDFLAGS\s*=\s*\$\(LDPLATFORMFLAGS\) \$\(CXXFLAGS\) -L\$\(libdir\)$/, "LDFLAGS = -Wl,-undefined,dynamic_lookup $(LDPLATFORMFLAGS) $(CXXFLAGS) -L$(libdir)"
        system "make", "install", *args
      end
    end

    cd "objective-c" do
      system "make", "install", *args
    end

    if build.with? "java"
      cd "java" do
        system "make", "install", *args
      end
    end



    if build.with? "php"
      cd "php" do
        args << "install_phpdir=#{share}/php"
        args << "install_libdir=#{lib}/php/extensions"
        system "make", "install", *args
      end
    end
  end

  test do
    (testpath/"Hello.ice").write <<-EOS.undent
      module Test {
        interface Hello {
          void sayHello();
        };
      };
    EOS
    (testpath/"Test.cpp").write <<-EOS.undent
      #include <Ice/Ice.h>
      #include <Hello.h>

      class HelloI : public Test::Hello {
      public:
        virtual void sayHello(const Ice::Current&) {}
      };

      int main(int argc, char* argv[]) {
        Ice::CommunicatorPtr communicator;
        communicator = Ice::initialize(argc, argv);
        Ice::ObjectAdapterPtr adapter =
            communicator->createObjectAdapterWithEndpoints("Hello", "default -h localhost -p 10000");
        adapter->add(new HelloI, communicator->stringToIdentity("hello"));
        adapter->activate();
        communicator->destroy();
        return 0;
      }
    EOS
    system "#{bin}/slice2cpp", "Hello.ice"
    system "xcrun", "clang++", "-c", "-I#{include}", "-I.", "Hello.cpp"
    system "xcrun", "clang++", "-c", "-I#{include}", "-I.", "Test.cpp"
    system "xcrun", "clang++", "-L#{lib}", "-o", "test", "Test.o", "Hello.o", "-lIce", "-lIceUtil"
    system "./test", "--Ice.InitPlugins=0"
    if build.with? "php"
      system "/usr/bin/php", "-d", "extension_dir=#{lib}/php/extensions",
                            "-d", "extension=IcePHP.dy",
                            "-r", "extension_loaded('ice') ? exit(0) : exit(1);"
    end
  end
end
