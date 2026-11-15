# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="Vulkan implicit layer for real-time color grading on Linux"
HOMEPAGE="https://github.com/reakjra/vkSumi"
SRC_URI="https://github.com/reakjra/vkSumi/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/vkSumi-${PV}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	media-libs/vulkan-loader
	x11-libs/libX11
"
DEPEND="
	${RDEPEND}
	dev-util/vulkan-headers
"
BDEPEND="
	dev-util/glslang
	virtual/pkgconfig
"

src_configure() {
	local emesonargs=(
		-Drelocatable_layer=false
	)
	meson_src_configure
}

pkg_postinst() {
	einfo "The Vulkan implicit layer is installed but disabled by default."
	einfo "Steam launch options: ENABLE_VKSUMI=1 %command%"
	einfo "Global config: ~/.config/vkSumi/vkSumi.conf"
	einfo "Verify registration with: ls /usr/share/vulkan/implicit_layer.d/vksumi.json"
}
