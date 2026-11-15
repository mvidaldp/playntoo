# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Official ReShade Windows installer for use with Wine/Proton games"
HOMEPAGE="https://github.com/crosire/reshade https://github.com/crosire/reshade"
SRC_URI="https://reshade.me/downloads/ReShade_Setup_${PV}.exe -> ${P}.exe"
S="${WORKDIR}"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
# The upstream download page asks users not to redistribute binaries.
RESTRICT="mirror bindist strip"

src_unpack() { :; }

src_install() {
	insinto /opt/reshade
	newins "${DISTDIR}/${P}.exe" ReShade_Setup.exe
	newbin "${FILESDIR}/playntoo-reshade-setup" playntoo-reshade-setup
}

pkg_postinst() {
	einfo "Installer: /opt/reshade/ReShade_Setup.exe"
	einfo "You may try: playntoo-reshade-setup (requires Wine installed)."
	einfo "This package stages the Windows installer; it does not install"
	einfo "a native Linux Vulkan layer or automatically inject into games."
	einfo "ReShade is a per-game setup. Check Proton compatibility before use."
}
