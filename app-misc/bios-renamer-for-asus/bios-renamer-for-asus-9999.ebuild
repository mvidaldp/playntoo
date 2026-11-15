# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cargo git-r3

DESCRIPTION="Cross-platform Rust implementation of ASUS' BIOS renamer utility"
HOMEPAGE="https://github.com/iAmSomeone2/bios_renamer_for_asus"
EGIT_REPO_URI="https://github.com/iAmSomeone2/bios_renamer_for_asus.git"
EGIT_BRANCH="main"

LICENSE="MIT"
SLOT="0"
KEYWORDS=""
PROPERTIES="live"

DOCS=( README.md )

src_unpack() {
	git-r3_src_unpack

	# Run Cargo from the checked-out Rust project.
	pushd "${S}" >/dev/null || die "Cannot enter source directory"
	cargo_live_src_unpack
	popd >/dev/null || die "Cannot return from source directory"
}

src_install() {
	cargo_src_install
	einstalldocs
}
