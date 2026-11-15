# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

MY_PN="AdGuardHome"

DESCRIPTION="Official prebuilt AdGuard Home network-wide DNS blocker"
HOMEPAGE="https://github.com/AdguardTeam/AdGuardHome"
SRC_URI="https://github.com/AdguardTeam/AdGuardHome/releases/download/v${PV}/${MY_PN}_linux_amd64.tar.gz -> ${P}-linux-amd64.tar.gz"
S="${WORKDIR}/${MY_PN}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="strip"

QA_PREBUILT="opt/adguardhome/AdGuardHome"

src_install() {
	exeinto /opt/adguardhome
	doexe AdGuardHome
	systemd_dounit "${FILESDIR}/adguardhome.service"
	# Work data is created and preserved by systemd's StateDirectory.
}

pkg_postinst() {
	einfo "The systemd unit is installed but not started."
	einfo "After checking that port 53 is free, enable with:"
	einfo "  systemctl enable --now adguardhome.service"
	einfo "Configuration and state live in /var/lib/adguardhome/."
	einfo "Do not run the bundled binary's self-updater; upgrade via Portage."
}
