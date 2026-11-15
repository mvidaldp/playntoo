# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit meson

DESCRIPTION="ReShade-compatible Vulkan post-processing layer for Linux"
HOMEPAGE="https://github.com/ralgar/vkShade"

MY_WRAPDB="https://github.com/mesonbuild/wrapdb/releases/download"
MY_VMA="https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator"
MY_SPIRV="https://github.com/KhronosGroup/SPIRV-Headers"

SRC_URI="
	https://github.com/ralgar/vkShade/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/g-truc/glm/archive/refs/tags/1.0.1.tar.gz -> ${P}-glm.tar.gz
	https://github.com/mesonbuild/wrapdb/releases/download/glm_1.0.1-1/glm_1.0.1-1_patch.zip -> ${P}-glm-patch.zip
	https://github.com/ocornut/imgui/archive/refs/tags/v1.91.6-docking.tar.gz -> ${P}-imgui-docking.tar.gz
	https://github.com/aiekick/ImGuiFileDialog/archive/refs/tags/v0.6.8.tar.gz -> ${P}-imguifiledialog.tar.gz
	https://github.com/benhoyt/inih/archive/r62.tar.gz -> ${P}-inih.tar.gz
	https://github.com/Neargye/magic_enum/archive/refs/tags/v0.9.7.tar.gz -> ${P}-magic_enum.tar.gz
	https://github.com/crosire/reshade/archive/refs/tags/v6.7.3.tar.gz -> ${P}-reshadefx.tar.gz
	https://github.com/gabime/spdlog/archive/refs/tags/v1.17.0.tar.gz -> ${P}-spdlog.tar.gz
	${MY_WRAPDB}/spdlog_1.17.0-1/spdlog_1.17.0-1_patch.zip -> ${P}-spdlog-patch.zip
	https://github.com/nothings/stb/archive/f1c79c02822848a9bed4315b12c8c8f3761e1296.tar.gz -> ${P}-stb.tar.gz
	${MY_VMA}/archive/refs/tags/v3.1.0.tar.gz -> ${P}-vulkan-memory-allocator.tar.gz
	${MY_SPIRV}/archive/refs/tags/vulkan-sdk-1.4.341.0.tar.gz -> ${P}-spirv-headers.tar.gz
"

S="${WORKDIR}/vkShade-${PV}"
LICENSE="BSD-2 BSD MIT Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-libs/wayland
	x11-libs/libX11
	x11-libs/libXi
	x11-libs/libxcb
	x11-libs/libxkbcommon
	media-libs/vulkan-loader
"

DEPEND="
	${RDEPEND}
	dev-util/vulkan-headers
	dev-util/spirv-headers
"

BDEPEND="
	dev-build/meson
	dev-util/pkgconf
	dev-util/glslang
	dev-util/wayland-scanner
	app-arch/unzip
"

src_unpack() {
	# Main project.
	unpack "${P}.tar.gz"

	# Stage vendored dependencies from Portage distfiles.
	# Meson will not download anything during compilation.

	local spec name directory

	for spec in \
		glm:glm-1.0.1 \
		imgui-docking:imgui-1.91.6-docking \
		imguifiledialog:imguifiledialog \
		inih:inih-r62 \
		magic_enum:magic_enum-0.9.7 \
		reshadefx:reshadefx \
		spdlog:spdlog-1.17.0 \
		stb:stb \
		vulkan-memory-allocator:VulkanMemoryAllocator-3.1.0 \
		spirv-headers:spirv-headers
	do
		name=${spec%%:*}
		directory=${spec#*:}

		mkdir -p "${S}/subprojects/${directory}" || die

		tar -xf "${DISTDIR}/${P}-${name}.tar.gz" \
			--strip-components=1 \
			-C "${S}/subprojects/${directory}" \
			|| die "Unpacking ${name} failed"
	done

	# Apply upstream vkShade Meson definitions.

	local patchdir

	for spec in \
		imgui:imgui-1.91.6-docking \
		imguifiledialog:imguifiledialog \
		magic_enum:magic_enum-0.9.7 \
		reshadefx:reshadefx \
		stb:stb \
		vulkan-memory-allocator:VulkanMemoryAllocator-3.1.0 \
		spirv-headers:spirv-headers
	do
		patchdir=${spec%%:*}
		directory=${spec#*:}

		if [[ -d ${S}/subprojects/packagefiles/${patchdir} ]]; then
			cp -a \
				"${S}/subprojects/packagefiles/${patchdir}/." \
				"${S}/subprojects/${directory}/" \
				|| die "Staging ${patchdir} Meson files failed"
		fi
	done

	# Apply the GLM and spdlog WrapDB patches.
	#
	# Some archives contain nested meson.build files.
	# Identify the actual project root by checking for
	# the project() statement instead of selecting the
	# first file returned by find.

	local patchname patchtree candidate
	local project_root target first_line

	for spec in \
		glm:glm-1.0.1 \
		spdlog:spdlog-1.17.0
	do
		patchname=${spec%%:*}
		directory=${spec#*:}

		target="${S}/subprojects/${directory}"
		patchtree="${WORKDIR}/wrapdb-${patchname}"

		mkdir -p "${patchtree}" || die

		unzip -q -o \
			"${DISTDIR}/${P}-${patchname}-patch.zip" \
			-d "${patchtree}" \
			|| die "Unpacking ${patchname} patch failed"

		project_root=

		while IFS= read -r -d '' candidate; do
			first_line=$(
				sed -n \
					'/^[[:space:]]*[^[:space:]#]/ {p;q;}' \
					"${candidate}"
			)

			if [[ ${first_line} =~ ^[[:space:]]*project[[:space:]]*\( ]]; then
				project_root=${candidate%/meson.build}
				break
			fi
		done < <(
			find "${patchtree}" \
				-type f \
				-name meson.build \
				-print0 | LC_ALL=C sort -z
		)

		[[ -n ${project_root} ]] \
			|| die "No Meson project root in ${patchname} patch"

		einfo "Staging ${patchname} Meson files from ${project_root}"

		cp -a "${project_root}/." "${target}/" \
			|| die "Applying ${patchname} patch failed"

		first_line=$(
			sed -n \
				'/^[[:space:]]*[^[:space:]#]/ {p;q;}' \
				"${target}/meson.build"
		)

		[[ ${first_line} =~ ^[[:space:]]*project[[:space:]]*\( ]] \
			|| die "${patchname}: invalid project meson.build"
	done

	# Ensure all Meson fallback subprojects are available.

	for spec in \
		glm:glm-1.0.1 \
		imgui:imgui-1.91.6-docking \
		imguifiledialog:imguifiledialog \
		inih:inih-r62 \
		magic_enum:magic_enum-0.9.7 \
		reshadefx:reshadefx \
		spdlog:spdlog-1.17.0 \
		stb:stb \
		vulkan-memory-allocator:VulkanMemoryAllocator-3.1.0 \
		spirv-headers:spirv-headers
	do
		name=${spec%%:*}
		directory=${spec#*:}

		[[ -f ${S}/subprojects/${directory}/meson.build ]] \
			|| die "Missing meson.build for ${name}"
	done
}

src_configure() {
	local emesonargs=(
		-Dtests=false
		-Ddefault_library=static
		--wrap-mode=nodownload
		--force-fallback-for=glm,imgui-docking,imguifiledialog,inih,magic_enum,reshadefx,spdlog,stb,vulkan-memory-allocator
	)

	meson_src_configure
}

src_install() {
	# Install the vkShade library, Vulkan layer manifest,
	# and upstream default config/preset files.
	#
	# Keep defaults in /usr/share/vkShade.
	# User-specific configurations are resolved by vkShade
	# itself and must not be written into $HOME by Portage.

	DESTDIR="${D}" meson install \
		-C "${BUILD_DIR}" \
		--no-rebuild \
		--skip-subprojects \
		|| die "Meson install failed"
}

pkg_postinst() {
	einfo "vkShade ${PV} installed successfully."
	einfo ""
	einfo "Vulkan layer:"
	einfo "  ENABLE_VKSHADE=1"
	einfo ""
	einfo "System defaults (Portage-managed):"
	einfo "  /usr/share/vkShade/vkShade.ini"
	einfo "  /usr/share/vkShade/ReShade.ini"
	einfo ""
	einfo "Optional user configuration:"
	einfo '  ${XDG_CONFIG_HOME:-~/.config}/vkShade/vkShade.ini'
	einfo '  ${XDG_CONFIG_HOME:-~/.config}/vkShade/ReShade.ini'
	einfo ""
	einfo "Explicit per-game overrides:"
	einfo "  VKSHADE_CONFIG_FILE=/path/to/vkShade.ini"
	einfo "  VKSHADE_PRESET_FILE=/path/to/ReShade.ini"
	einfo ""
	einfo "User configuration takes precedence over packaged defaults."
	einfo "Portage does not create or modify files in user home directories."
	einfo ""
	einfo "Default layer activation: disabled."
	einfo "Avoid enabling vkShade and vkBasalt together initially."
}
