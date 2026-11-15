# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Prebuilt OptiScaler upscaling and frame-generation DLL bundle for Wine/Proton"
HOMEPAGE="https://github.com/optiscaler/OptiScaler"
MY_ASSET="Optiscaler_${PV}-final.20260718._MM.7z"
SRC_URI="https://github.com/optiscaler/OptiScaler/releases/download/v${PV}/${MY_ASSET} -> ${P}.7z"
S="${WORKDIR}/${P}"

# Upstream's GPL-3 licensing covers the project, but bundled third-party DLLs
# have separate license terms. Review these before submitting this to GURU.
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="strip bindist"

BDEPEND="app-arch/7zip"

src_unpack() {
	mkdir -p "${S}" || die
	7z x -bd -y "-o${S}" "${DISTDIR}/${P}.7z" > /dev/null || die "7z extraction failed"
}

src_install() {
	insinto /opt/optiscaler
	doins -r "${S}"/*
}

pkg_postinst() {
	einfo "OptiScaler release files are installed in /opt/optiscaler."
	einfo "They are Windows DLLs: they are NOT a native Vulkan layer."
	einfo "Copy selected files to an individual game's executable directory"
	einfo "following upstream's compatibility and Linux/Proton instructions."
	einfo "Never replace game DLLs automatically or install into /usr/lib64."
}
