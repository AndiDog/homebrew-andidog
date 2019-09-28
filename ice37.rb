class Ice37 < Formula
  desc "Comprehensive RPC framework"
  homepage "https://zeroc.com"
  url "https://github.com/zeroc-ice/ice/archive/v3.7.2.tar.gz"
  sha256 "e329a24abf94a4772a58a0fe61af4e707743a272c854552eef3d7833099f40f9"

  option "with-additional-compilers", "Build additional Slice compilers (slice2py, slice2js, slice2rb)"
  option "with-java", "Build Ice for Java and the IceGrid GUI app"
  option "without-python", "Build without Ice for Python"

  depends_on "lmdb"
  depends_on :macos => :mavericks
  depends_on "mcpp"
  depends_on :java => ["1.8+", :optional]
  depends_on "python@2"

  def install
    ENV.O2 # Os causes performance issues
    # Ensure Gradle uses a writable directory even in sandbox mode
    ENV["GRADLE_USER_HOME"] = "#{buildpath}/.gradle"

    # `include/generated/Ice/Endpoint.h:901:47: error: parameter 'underlying' shadows member inherited from type 'EndpointInfo' [-Werror,-Wshadow-field]`
    ENV["CPPFLAGS"] = " -Wno-shadow-field"

    args = [
      "prefix=#{prefix}",
      "V=1",
      "MCPP_HOME=#{Formula["mcpp"].opt_prefix}",
      "LMDB_HOME=#{Formula["lmdb"].opt_prefix}",
      "CONFIGS=shared cpp11-shared xcodesdk cpp11-xcodesdk",
      "PLATFORMS=all",
      # We don't build slice2py, slice2js, slice2rb by default to prevent clashes with
      # the translators installed by the PyPI/GEM/npm packages.
      "SKIP=slice2confluence #{build.without?("python") && build.without?("additional-compilers") ? "slice2py" : ""} #{build.without?("additional-compilers") ? "slice2rb slice2js" : ""}",
      "LANGUAGES=cpp objective-c #{build.with?("java") ? "java java-compat" : ""} #{build.with?("python") ? "python" : ""}",
    ]

    if build.with? "python"
      args << "PYTHON_LIB_NAME=-Wl,-undefined,dynamic_lookup"
      cd "python" do
        inreplace "config/install_dir", "print(e.install_dir)", "print('#{lib}/python2.7/site-packages')"
      end

      # If building Python support, slice2py is required to generate Python code from slices. However if additional
      # compilers should not be installed, we must skip installation of slice2py
      # => patch Makefile macro `define create-translator-project`
      if build.without?("additional-compilers")
        inreplace "config/Make.project.rules",
                  /(define create-translator-project.*?\$1_install_platforms\s*:=.*?)endef/m,
                  "\\1\n" \
                  "ifeq ($(notdir $1),slice2py)\n" \
                  "$1_install_platforms := \n" \
                  "endif\n" \
                  "endef"
      end
    end

    system "make", "install", *args

    (libexec/"bin").mkpath
    if build.with?("additional-compilers")
      if build.with?("python")
        mv bin/"slice2py", libexec/"bin"
      end

      %w[slice2rb slice2js].each do |r|
        mv bin/r, libexec/"bin"
      end
    end
  end

  def caveats
    if build.with?("additional-compilers")
      return <<~EOS
        slice compilers were installed in:

          #{opt_libexec}/bin

        You may wish to add this directory to your PATH.
      EOS
    end
  end

  test do
    (testpath / "Hello.ice").write <<~EOS
      module Test
      {
          interface Hello
          {
              void sayHello();
          }
      }
    EOS
    (testpath / "Test.cpp").write <<~EOS
      #include <Ice/Ice.h>
      #include <Hello.h>

      class HelloI : public Test::Hello
      {
      public:
        virtual void sayHello(const Ice::Current&) override {}
      };

      int main(int argc, char* argv[])
      {
        Ice::CommunicatorHolder ich(argc, argv);
        auto adapter = ich->createObjectAdapterWithEndpoints("Hello", "default -h localhost -p 10000");
        adapter->add(std::make_shared<HelloI>(), Ice::stringToIdentity("hello"));
        adapter->activate();
        return 0;
      }
    EOS
    system "#{bin}/slice2cpp", "Hello.ice"
    system ENV.cxx, "-DICE_CPP11_MAPPING", "-std=c++11", "-c", "-I#{include}", "-I.", "Hello.cpp"
    system ENV.cxx, "-DICE_CPP11_MAPPING", "-std=c++11", "-c", "-I#{include}", "-I.", "Test.cpp"
    system ENV.cxx, "-L#{lib}", "-o", "test", "Test.o", "Hello.o", "-lIce++11"
    system "./test"
  end
end
