# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg-utils

DESCRIPTION="Flowchart-based image processing GUI for AI upscaling and related tasks"
HOMEPAGE="https://chainner.app/ https://github.com/chaiNNer-org/chaiNNer"
SRC_URI="https://github.com/chaiNNer-org/chaiNNer/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

S="${WORKDIR}/chaiNNer-${PV}"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="wayland"

# Local-overlay pragmatic build:
# - npm downloads dependencies during src_compile
# - electron bundle is installed under /opt
RESTRICT="network-sandbox strip"

# Upstream requires npm >= 7.
BDEPEND="
	>=net-libs/nodejs-20[npm]
"

RDEPEND="
	wayland? ( gui-apps/wl-clipboard )
	!wayland? ( x11-misc/xclip )
"

# The Electron package built by upstream contains many prebuilt ELF objects.
QA_PREBUILT="
	opt/${PN}/chainner
	opt/${PN}/chrome-sandbox
	opt/${PN}/chrome_crashpad_handler
	opt/${PN}/libEGL.so
	opt/${PN}/libGLESv2.so
	opt/${PN}/libffmpeg.so
	opt/${PN}/libvk_swiftshader.so
	opt/${PN}/libvulkan.so.1
	opt/${PN}/vk_swiftshader_icd.json
"

src_compile() {
	# Electron Forge 7 uses yauzl 2.x, which can hang
	# during packaging under Node.js 26.
	# Override the transitive dependency with yauzl 3.3.1.
	npm pkg set 'overrides.yauzl=3.3.1' ||
		die "Failed to set yauzl override"

	# Regenerate the lockfile so npm ci accepts the override.
	npm install --package-lock-only --ignore-scripts \
		--no-audit --no-fund ||
		die "Failed to refresh npm lockfile"

	npm ci --include=dev --no-audit --no-fund ||
		die "npm ci failed"

	npm run package ||
		die "npm run package failed"
}

src_install() {
	local pkgdir="${S}/out/chaiNNer-linux-x64"

	[[ -d ${pkgdir} ]] || die "Expected packaged app directory not found: ${pkgdir}"

	insinto /opt/${PN}
	doins -r "${pkgdir}"/*

	fperms 4755 /opt/${PN}/chrome-sandbox
	fperms +x \
		/opt/${PN}/chainner \
		/opt/${PN}/chrome_crashpad_handler

	dosym ../../opt/${PN}/chainner /usr/bin/${PN}

	newicon "${S}/src/public/icons/cross_platform/icon.png" ${PN}.png
	make_desktop_entry "${PN}" "chaiNNer" "${PN}" "Graphics"
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update

	elog "chaiNNer ships as an Electron bundle under /opt/${PN}."
	elog "On first run, upstream expects to download/use its integrated Python"
	elog "environment unless you switch it to system Python in the app settings."
	elog
	elog "Clipboard nodes on Linux require:"
	elog "  - x11-misc/xclip on X11"
	elog "  - gui-apps/wl-clipboard on Wayland"
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}
