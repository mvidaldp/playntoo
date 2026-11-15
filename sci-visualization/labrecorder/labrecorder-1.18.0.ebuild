# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Record Lab Streaming Layer streams into synchronized XDF files"
HOMEPAGE="https://github.com/labstreaminglayer/App-LabRecorder"
SRC_URI="https://github.com/labstreaminglayer/App-LabRecorder/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/App-LabRecorder-${PV}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=sci-libs/liblsl-1.18.0_beta3
	dev-qt/qtbase:6[gui,widgets]
"
DEPEND="${RDEPEND}"

src_prepare() {
	# Do not install another copy of system liblsl into /usr/lib.
	# Upstream otherwise invokes LSL_install_liblsl on Linux.
	sed -i '/^[[:space:]]*LSL_install_liblsl(DESTINATION.*INSTALL_LIBDIR.*)/d' CMakeLists.txt || die
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DLABRECORDER_BUILD_GUI=ON
		-DLABRECORDER_VERSION_OVERRIDE=${PV}
		-DLSL_FETCH_IF_MISSING=OFF
	)
	cmake_src_configure
}
