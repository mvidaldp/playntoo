# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake xdg

DESCRIPTION="A graphical grub2 settings manager"
HOMEPAGE="https://launchpad.net/grub-customizer"
SRC_URI="https://launchpad.net/grub-customizer/$(ver_cut 1-2)/${PV}/+download/grub-customizer_${PV}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
	app-arch/libarchive:=
	dev-cpp/atkmm
	dev-cpp/cairomm
	dev-cpp/glibmm:2
	dev-cpp/gtkmm:3.0
	dev-cpp/pangomm:1.4
	dev-libs/glib:2
	dev-libs/libsigc++:2
	dev-libs/openssl:=
	x11-libs/gtk+:3
"
RDEPEND="
	${DEPEND}
	sys-apps/hwinfo
"
BDEPEND="virtual/pkgconfig"

src_prepare() {
	cmake_src_prepare

	# The old 5.2.4 patch no longer applies cleanly to 5.2.8.
	# Retain its purpose, but only remove the CMake setting if present.
	sed -i -E \
		'/^[[:space:]]*set[[:space:]]*\([[:space:]]*CMAKE_POSITION_INDEPENDENT_CODE[[:space:]]+ON[[:space:]]*\)/d' \
		CMakeLists.txt || die "Failed to adjust CMake PIC setting"

	# Some upstream archives ship the manpage gzip-compressed.
	if [[ -f misc/manpage.gz ]]; then
		gunzip misc/manpage.gz || die "Failed to unpack manpage"
		sed -i \
			-e 's/manpage.gz/manpage/g' \
			-e 's/\(grub-customizer.1\).gz/\1/g' \
			CMakeLists.txt || die "Failed to adjust manpage installation"
	fi
}
