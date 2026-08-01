pkg_name="lua55"
pkg_version="5.5.0"
pkg_mode="managed"
pkg_type="source"

LUA_TARBALL="lua-${pkg_version}.tar.gz"

stage_acquire() {
  mkdir -p "$WORKDIR/downloads"

  al_fetch_cached_url \
    "https://www.lua.org/ftp/${LUA_TARBALL}" \
    "$WORKDIR/downloads/$LUA_TARBALL"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/downloads/$LUA_TARBALL" \
    "$WORKDIR"

  SRCDIR="$WORKDIR/lua-${pkg_version}"
  PREFIX="/opt/edge"

  export SRCDIR PREFIX
}

stage_build() {
  make -C "$SRCDIR" \
    linux \
    CC="${CC:-gcc}" \
    MYCFLAGS="-fPIC" \
    MYLDFLAGS=""
}

stage_stage() {
  make -C "$SRCDIR" \
    INSTALL_TOP="$STAGE_DIR$PREFIX" \
    INSTALL_INC="$STAGE_DIR$PREFIX/include" \
    INSTALL_LIB="$STAGE_DIR$PREFIX/lib" \
    INSTALL_MAN="$STAGE_DIR$PREFIX/share/man/man1" \
    install

  mv "$STAGE_DIR$PREFIX/bin/lua" \
     "$STAGE_DIR$PREFIX/bin/lua5.5"

  mv "$STAGE_DIR$PREFIX/bin/luac" \
     "$STAGE_DIR$PREFIX/bin/luac5.5"

  mkdir -p "$STAGE_DIR$PREFIX/lib/pkgconfig"

  cat > "$STAGE_DIR$PREFIX/lib/pkgconfig/lua5.5.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
includedir=\${prefix}/include
libdir=\${exec_prefix}/lib

Name: Lua
Description: Lua programming language
Version: $pkg_version
Libs: -L\${libdir} -llua
Libs.private: -lm -ldl
Cflags: -I\${includedir}
EOF
}
