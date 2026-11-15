# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_COMMIT="7d0bfc1"

DESCRIPTION="macOS Mojave-inspired Xcursor theme"
HOMEPAGE="https://github.com/vinceliuice/McMojave-cursors"
SRC_URI="https://github.com/vinceliuice/McMojave-cursors/archive/${MY_COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/McMojave-cursors-7d0bfc1f91028191cdc220b87fd335a235ee4439"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

src_install() {
	# Upstream includes precompiled cursor images under dist/.
	# Avoid its install.sh: it writes to the real host filesystem.
	[[ -d dist/cursors ]] || die "Expected precompiled cursors in dist/cursors"
	insinto /usr/share/icons/McMojave-cursors
	doins -r dist/.
}
