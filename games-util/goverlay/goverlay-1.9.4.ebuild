# Copyright 2020-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit xdg

DESCRIPTION="Graphical configurator for Linux game overlays and launch options"
HOMEPAGE="https://github.com/benjamimgois/goverlay"

if [[ ${PV} == *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/benjamimgois/${PN}.git"
	EGIT3_STORE_DIR="${T}"
else
	SRC_URI="https://github.com/benjamimgois/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.gh.tar.gz"
	KEYWORDS="~amd64"
fi

LICENSE="GPL-3"
SLOT="0"

RDEPEND="
	games-util/mangohud
	dev-libs/libqt6pas
	media-libs/libsdl2
	x11-libs/libX11
"

BDEPEND="
	>=dev-lang/lazarus-3.4[qt6]
"

src_prepare() {
	default
	# Upstream defaults to /usr/local; let Portage own the installed files.
	sed -i -e 's|^prefix = /usr/local$|prefix = /usr|' Makefile || die
}

src_compile() {
	# Pascal/Lazarus builds may share unit paths; avoid parallel writer races.
	emake -j1 LAZBUILDOPTS="--ws=qt6 --lazarusdir=/usr/share/lazarus"
}

src_install() {
	# Upstream 1.9.4 installs the launcher, pascube, bgmod and app data.
	emake -j1 DESTDIR="${D}" install
}
