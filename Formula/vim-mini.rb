class VimMini < Formula
  desc "Minimalistic Vim formula with optional dependencies"
  homepage "https://www.vim.org/"
  url "https://github.com/vim/vim/archive/v8.1.0600.tar.gz"
  sha256 "d956af8cc04a9ab965e54b26e5938d266df9f128ad7e983ea6da94dd4b4eda9b"
  head "https://github.com/vim/vim.git"

  option "with-override-system-vi", "Override system vi"
  option "with-gettext", "Build vim with National Language Support (translated messages, keymaps)"
  option "with-client-server", "Enable client/server mode"

  LANGUAGES = %w[lua luajit perl python python@2 ruby].freeze
  CUSTOM_MESSAGES = {
    "python@2" => "Build vim with python@2 instead of python[3] support",
  }.freeze

  LANGUAGES.each do |language, msg|
    option "with-#{language}", CUSTOM_MESSAGES[language] || "Build vim with #{language} support"
  end

  depends_on "lua" => :optional
  depends_on "luajit" => :optional
  depends_on "perl" => :optional
  depends_on "python" => :optional
  depends_on "python@2" => :optional
  depends_on "ruby" => :optional
  depends_on "gettext" => :optional
  depends_on :x11 if build.with? "client-server"

  conflicts_with "ex-vi",
    :because => "vim and ex-vi both install bin/ex and bin/view"

  conflicts_with "vim",
    :because => "vim-mini and vim install the same executables"

  def install
    # https://github.com/Homebrew/homebrew-core/pull/1046
    ENV.delete("SDKROOT")

    opts = []

    if build.with?("lua") || build.with?("luajit")
      opts << "--enable-luainterp"

      if build.with?("luajit")
        opts << "--with-luajit"
        opts << "--with-lua-prefix=#{Formula["luajit"].opt_prefix}"
      else
        opts << "--with-lua-prefix=#{Formula["lua"].opt_prefix}"
      end

      if build.with?("lua") && build.with?("luajit")
        onoe <<~EOS
          Vim will not link against both Luajit & Lua simultaneously.
          Proceeding with Lua.
        EOS
        opts -= %w[--with-luajit]
      end
    end

    if build.with?("python") || build.with?("python@2")
      # python 3 takes precedence if both options have been set
      python = build.with?("python") ? "python3" : "python"
      opts << "--enable-#{python}interp"

      ENV.prepend_path "PATH", Formula[python].opt_libexec/"bin"

      # vim doesn't require any Python package, unset PYTHONPATH.
      ENV.delete("PYTHONPATH")
    end

    %w["perl ruby"].each do |language|
      opts << "--enable-#{language}interp" if build.with? language
    end

    opts << "--disable-nls" if build.without? "gettext"
    opts << "--enable-gui=no"

    if build.with? "client-server"
      opts << "--with-x"
    else
      opts << "--without-x"
    end

    # We specify HOMEBREW_PREFIX as the prefix to make vim look in the
    # the right place (HOMEBREW_PREFIX/share/vim/{vimrc,vimfiles}) for
    # system vimscript files. We specify the normal installation prefix
    # when calling "make install".
    # Homebrew will use the first suitable Perl & Ruby in your PATH if you
    # build from source. Please don't attempt to hardcode either.
    system "./configure", "--prefix=#{HOMEBREW_PREFIX}",
                          "--mandir=#{man}",
                          "--enable-multibyte",
                          "--with-tlib=ncurses",
                          "--enable-cscope",
                          "--enable-terminal",
                          "--with-compiledby=Homebrew",
                          *opts
    system "make"
    # Parallel install could miss some symlinks
    # https://github.com/vim/vim/issues/1031
    ENV.deparallelize
    # If stripping the binaries is enabled, vim will segfault with
    # statically-linked interpreters like ruby
    # https://github.com/vim/vim/issues/114
    system "make", "install", "prefix=#{prefix}", "STRIP=#{which "true"}"
    bin.install_symlink "vim" => "vi" if build.with? "override-system-vi"
  end

  test do
    if build.with? "python"
      (testpath/"commands.vim").write <<~EOS
        :python3 import vim; vim.current.buffer[0] = 'hello python3'
        :wq
      EOS
      system bin/"vim", "-T", "dumb", "-s", "commands.vim", "test.txt"
      assert_equal "hello python3", File.read("test.txt").chomp
    elsif build.with? "python@2"
      (testpath/"commands.vim").write <<~EOS
        :python import vim; vim.current.buffer[0] = 'hello world'
        :wq
      EOS
      system bin/"vim", "-T", "dumb", "-s", "commands.vim", "test.txt"
      assert_equal "hello world", File.read("test.txt").chomp
    end
    if build.with? "gettext"
      assert_match "+gettext", shell_output("#{bin}/vim --version")
    end
  end
end
