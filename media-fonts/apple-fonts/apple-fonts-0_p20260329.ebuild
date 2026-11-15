# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit font

DESCRIPTION="Fonts for Apple platforms, including San Francisco and New York"
HOMEPAGE="https://developer.apple.com/fonts/"

SRC_URI="
	https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg -> ${P}-SF-Pro-20261029.dmg
	https://devimages-cdn.apple.com/design/resources/download/SF-Compact.dmg -> ${P}-SF-Compact-20261115.dmg
	https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg -> ${P}-SF-Mono-20261115.dmg
	https://devimages-cdn.apple.com/design/resources/download/NY.dmg -> ${P}-NY-20261115.dmg
"

S="${WORKDIR}"
LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"
RESTRICT="bindist mirror"

BDEPEND="
	|| (
		app-arch/7zip[symlink]
		app-arch/7zip
	)
	app-arch/cpio
	app-arch/gzip
"

FONT_S="${WORKDIR}/fonts"

src_unpack() {
	local archive licname dmgdir pkgroot pkgfile license_file
	local payload payload_root fontsdir
	local -a pkgfiles payloads

	mkdir -p "${FONT_S}" "${WORKDIR}/licenses" || die

	for archive in \
		"${DISTDIR}/${P}-SF-Pro-20261029.dmg" \
		"${DISTDIR}/${P}-SF-Compact-20261115.dmg" \
		"${DISTDIR}/${P}-SF-Mono-20261115.dmg" \
		"${DISTDIR}/${P}-NY-20261115.dmg"
	do
		licname=${archive##*/}
		licname=${licname%.dmg}

		dmgdir="${WORKDIR}/dmg-${licname}"
		pkgroot="${WORKDIR}/pkg-${licname}"

		rm -rf "${dmgdir}" "${pkgroot}" || die
		mkdir -p "${dmgdir}" "${pkgroot}" || die

		einfo "Extracting $(basename "${archive}")"
		7z x -y -o"${dmgdir}" "${archive}" \
			|| die "Failed to extract ${archive}"

		mapfile -t pkgfiles < <(find "${dmgdir}" -type f -name '*.pkg' | sort)
		[[ ${#pkgfiles[@]} -gt 0 ]] || die "No .pkg found in ${archive}"

		local n=0
		for pkgfile in "${pkgfiles[@]}"; do
			((n++))
			einfo "Extracting $(basename "${pkgfile}")"
			7z x -y -o"${pkgroot}/pkg${n}" -txar "${pkgfile}" \
				|| die "Failed to unpack ${pkgfile}"
		done

		license_file=$(find "${pkgroot}" -type f \( -name 'License.rtf' -o -name 'LICENSE.rtf' \) -print -quit)
		if [[ -n ${license_file} ]]; then
			cp "${license_file}" "${WORKDIR}/licenses/LICENSE.${licname}.rtf" || die
		else
			ewarn "No License.rtf found in ${archive}"
		fi

		mapfile -t payloads < <(find "${pkgroot}" -type f \( -name 'Payload' -o -name 'Payload~' \) | sort)
		[[ ${#payloads[@]} -gt 0 ]] || die "No Payload found in ${archive}"

		local p=0
		for payload in "${payloads[@]}"; do
			((p++))
			payload_root="${pkgroot}/payload${p}"
			mkdir -p "${payload_root}" || die

			einfo "Extracting $(basename "${payload}") from ${licname}"

			if gzip -t "${payload}" >/dev/null 2>&1; then
				(
					cd "${payload_root}" || die
					gzip -dc "${payload}" | cpio -idm --quiet --no-absolute-filenames
				) || die "Failed to unpack gzip+cpio payload ${payload}"
			else
				(
					cd "${payload_root}" || die
					cpio -idm --quiet --no-absolute-filenames < "${payload}"
				) || die "Failed to unpack cpio payload ${payload}"
			fi
		done

		fontsdir=$(find "${pkgroot}" -type d -path '*/Library/Fonts' -print -quit)
		[[ -n ${fontsdir} ]] || die "Library/Fonts missing in ${archive}"

		cp -a "${fontsdir}/." "${FONT_S}/" || die
	done
}

src_install() {
	local -a suffixes=()
	local s

	for s in otf otc ttf ttc; do
		compgen -G "${FONT_S}/*.${s}" > /dev/null && suffixes+=( "${s}" )
	done

	[[ ${#suffixes[@]} -gt 0 ]] || die "No font files found in ${FONT_S}"

	FONT_SUFFIX="${suffixes[*]}"
	font_src_install

	if compgen -G "${WORKDIR}/licenses/*" > /dev/null; then
		dodoc "${WORKDIR}"/licenses/* || die
	fi
}
