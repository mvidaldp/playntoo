# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=uv-build
PYTHON_COMPAT=( python3_{12..14} )

inherit distutils-r1 pypi

DESCRIPTION="Bluetooth Low Energy platform Agnostic Klient (BLEAK) for Python"
HOMEPAGE="
	https://bleak.readthedocs.io/
	https://github.com/hbldh/bleak
	https://pypi.org/project/bleak/
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="
	>=dev-python/dbus-fast-1.83.0[${PYTHON_USEDEP}]
"

# Bleak 3.0.2's release tarball specifies uv_build >=0.10.9,<0.11.0.
#
# Upstream subsequently relaxed this to <0.12.0 while still carrying
# version 3.0.2 in pyproject.toml. Gentoo currently provides uv-build
# 0.11.x, so use that compatible range rather than requiring an obsolete
# 0.10.x release.
BDEPEND="

	test? (
		>=dev-python/pytest-8.2.1[${PYTHON_USEDEP}]

		>=dev-python/pytest-asyncio-1.2.0[${PYTHON_USEDEP}]
		<dev-python/pytest-asyncio-2[${PYTHON_USEDEP}]

		>=dev-python/pytest-cov-7.0.0[${PYTHON_USEDEP}]
		<dev-python/pytest-cov-8[${PYTHON_USEDEP}]
	)
"

distutils_enable_sphinx docs dev-python/sphinx-rtd-theme

python_prepare_all() {
	# The 3.0.2 release tarball pins:
	#
	#   uv_build>=0.10.9,<0.11.0
	#
	# Upstream later relaxed the same 3.0.2 metadata to <0.12.0.
	# Gentoo no longer carries uv-build 0.10.x, but does provide 0.11.x.
	#
	# Backport that metadata-only relaxation so the PEP 517 metadata
	# agrees with the build dependency selected above.
	sed -i \
		's/uv_build>=0\.10\.9,<0\.11\.0/uv_build>=0.10.9,<0.12.0/' \
		pyproject.toml || die

	distutils-r1_python_prepare_all
}

python_install_all() {
	[[ -d examples ]] && dodoc -r examples

	distutils-r1_python_install_all
}
