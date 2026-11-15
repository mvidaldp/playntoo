# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

MY_TAG="v${PV/_beta/.b}"

DESCRIPTION="Library for synchronized lab data streaming"
HOMEPAGE="https://github.com/sccn/liblsl"
SRC_URI="https://github.com/sccn/liblsl/archive/refs/tags/${MY_TAG}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/liblsl-${MY_TAG#v}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-libs/boost
	dev-libs/pugixml
"
DEPEND="${RDEPEND}"

src_configure() {
	local mycmakeargs=(
		-DLSL_BUNDLED_BOOST=OFF
		-DLSL_FETCH_PUGIXML=OFF
		-DLSL_BUILD_STATIC=OFF
		-DLSL_UNITTESTS=OFF
		-DLSL_TOOLS=OFF
	)
	cmake_src_configure
}
