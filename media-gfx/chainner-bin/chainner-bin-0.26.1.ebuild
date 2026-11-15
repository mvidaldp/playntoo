# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop

DESCRIPTION="Node-based image processing and AI upscaling application"
HOMEPAGE="https://chainner.app/ https://github.com/chaiNNer-org/chaiNNer"

MY_ARCHIVE="chaiNNer-linux-x64-${PV}-portable.zip"

SRC_URI="
	https://github.com/chaiNNer-org/chaiNNer/releases/download/v${PV}/${MY_ARCHIVE}
		-> ${P}.zip
"

S="${WORKDIR}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="strip"

BDEPEND="app-arch/unzip"

RDEPEND="
	!media-gfx/chainner
	dev-libs/nss
	media-libs/alsa-lib
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libxcb
"

QA_PREBUILT="opt/chainner/*"

src_unpack() {
	mkdir -p "${WORKDIR}/unpacked" || die

	unzip -q "${DISTDIR}/${P}.zip" \
		-d "${WORKDIR}/unpacked" \
		|| die "Failed to unpack chaiNNer"
}

src_install() {
	local binary appdir

	binary=$(find "${WORKDIR}/unpacked" \
		-type f -name chainner -print -quit)

	[[ -n ${binary} ]] || die "chaiNNer executable not found"

	appdir=${binary%/*}

	dodir /opt/chainner

	cp -a "${appdir}/." "${ED}/opt/chainner/" \
		|| die "Failed to install chaiNNer"

	fperms 0755 /opt/chainner/chainner

	if [[ -f ${ED}/opt/chainner/chrome-sandbox ]]; then
		fperms 4755 /opt/chainner/chrome-sandbox
	fi

	dosym -r /opt/chainner/chainner /usr/bin/chainner

	make_desktop_entry chainner "chaiNNer" "" "Graphics"
}

pkg_postinst() {
	elog "chaiNNer is installed under /opt/chainner."
	elog "Python dependencies may be downloaded on first launch."
}
