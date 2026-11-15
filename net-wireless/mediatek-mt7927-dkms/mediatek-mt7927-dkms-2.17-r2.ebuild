# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod-r1

UPSTREAM_REL="${PR#r}"
UPSTREAM_TAG="v${PV}-${UPSTREAM_REL}"
UPSTREAM_P="${PN}-${PV}-${UPSTREAM_REL}"
UPSTREAM_ARCHIVE="${UPSTREAM_P}.tar.gz"

MT76_KVER="7.3"
LINUX_TARBALL="linux-${MT76_KVER}.tar.xz"

# Upstream v2.17-2 still obtains the Bluetooth firmware from the ASUS
# V5603998 driver package. Reuse the already pre-extracted firmware archive
# used by the previous Gentoo package.
#
# WiFi firmware is intentionally NOT installed from this archive. Current
# linux-firmware provides the newer MediaTek-submitted MT7927 WiFi firmware.
FW_P="mt7927-firmware-2.11"

R2_BASE="https://distfiles.obentoo.org/DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R"

DESCRIPTION="MediaTek MT7927 Wi-Fi and Bluetooth DKMS driver"
HOMEPAGE="https://github.com/jetm/mediatek-mt7927-dkms"

SRC_URI="
	https://github.com/jetm/${PN}/archive/refs/tags/${UPSTREAM_TAG}.tar.gz -> ${UPSTREAM_ARCHIVE}
	https://cdn.kernel.org/pub/linux/kernel/v${MT76_KVER%%.*}.x/${LINUX_TARBALL}
	${R2_BASE}/${FW_P}.tar.xz
"

S="${WORKDIR}/${UPSTREAM_P}"

LICENSE="GPL-2 all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64"
IUSE="bt-dkms modules-compress modules-sign +strip"
RESTRICT="mirror"

# bt-dkms forces the package-provided btusb/btmtk modules even on >=7.1.
#
# Normal MT7927/MT6639 devices such as 0489:e13a do NOT need this.
# It is mainly useful for hardware such as 0489:e156 whose USB ID
# is not yet available in the native driver.

RDEPEND="
	>=sys-kernel/linux-firmware-20260519
"

CONFIG_CHECK="
	~MAC80211
	~CFG80211
	~BT
	~BT_HCIBTUSB
	~BT_HCIBTUSB_MTK
"

MODULES_KERNEL_MIN="6.17"

want_external_bt() {
	use bt-dkms || ! kernel_is -ge 7 1
}

src_unpack() {
	# Do not unpack the complete Linux source tarball here.
	# Only the required driver subtrees are extracted in src_prepare().
	unpack "${UPSTREAM_ARCHIVE}"
	unpack "${FW_P}.tar.xz"
}

src_prepare() {
	default

	local build="${WORKDIR}/_build"
	local wifi_dir="${build}/mt76"
	local bt_dir="${build}/bluetooth"

	mkdir -p "${wifi_dir}" || die

	#
	# WiFi
	#
	# Upstream v2.17 is based on Linux 7.3. MT7927 WiFi support is
	# already present in this source. The package now adds only its
	# remaining AP-mode changes and compatibility shims.
	#
	tar -xf "${DISTDIR}/${LINUX_TARBALL}" \
		--strip-components=6 \
		-C "${wifi_dir}" \
		"linux-${MT76_KVER}/drivers/net/wireless/mediatek/mt76" || die

	pushd "${wifi_dir}" >/dev/null || die

	# Apply the exact upstream v2.17-2 WiFi patch set:
	#
	#   mt7927-wifi-01...04     remaining AP-mode patches
	#   compat action-frame    pre-7.1 host compatibility
	#   compat EML macros      pre-7.2 host compatibility
	#   compat kzalloc_flex    older host compatibility
	#
	eapply "${S}"/mt7927-wifi-*.patch

	popd >/dev/null || die

	#
	# Bluetooth
	#
	# MT6639 Bluetooth is upstream/native starting with Linux 7.1.
	#
	# Follow upstream v2.17-2 and do not replace btusb/btmtk on >=7.1,
	# unless USE=bt-dkms has explicitly been enabled.
	#
	if want_external_bt; then
		einfo "Building package-provided btusb/btmtk Bluetooth modules."

		mkdir -p "${bt_dir}" || die

		tar -xf "${DISTDIR}/${LINUX_TARBALL}" \
			--strip-components=3 \
			-C "${bt_dir}" \
			"linux-${MT76_KVER}/drivers/bluetooth" || die

		pushd "${bt_dir}" >/dev/null || die

		local p

		for p in \
			"${S}"/mt6639-bt-[0-9]*.patch \
			"${S}"/mt6639-bt-compat-*.patch
		do
			[[ -f "${p}" ]] || continue
			eapply "${p}"
		done

		popd >/dev/null || die

		cp "${S}/bluetooth.Makefile" \
			"${bt_dir}/Makefile" || die
	else
		einfo "Kernel >= 7.1 detected; using kernel-native btusb/btmtk."
	fi

	#
	# Kbuild
	#
	# Use the upstream v2.17-2 Kbuild files rather than carrying our own
	# object lists. These include, among other things, the v2.14-2
	# CONFIG_NL80211_TESTMODE build fix.
	#
	cp "${S}/mt76.Kbuild" \
		"${wifi_dir}/Kbuild" || die

	cp "${S}/mt7921.Kbuild" \
		"${wifi_dir}/mt7921/Kbuild" || die

	cp "${S}/mt7925.Kbuild" \
		"${wifi_dir}/mt7925/Kbuild" || die

	#
	# Compatibility header
	#
	mkdir -p \
		"${wifi_dir}/compat/include/linux/soc/airoha" || die

	cp "${S}/compat-airoha-offload.h" \
		"${wifi_dir}/compat/include/linux/soc/airoha/airoha_offload.h" || die
}

src_compile() {
	local build="${WORKDIR}/_build"
	local wifi_dir="${build}/mt76"
	local bt_dir="${build}/bluetooth"

	local -a modargs=()
	local -a modlist=()

	#
	# Bluetooth
	#
	# Normally skipped on a native-Bluetooth-capable >=7.1 kernel.
	#
	if want_external_bt; then
		modargs=(
			-C "${KV_OUT_DIR}"
			M="${bt_dir}"
		)

		modlist=(
			btusb=updates:"${bt_dir}":"${bt_dir}":modules
			btmtk=updates:"${bt_dir}":"${bt_dir}":modules
		)

		linux-mod-r1_src_compile
	fi

	#
	# WiFi
	#
	modargs=(
		-C "${KV_OUT_DIR}"
		M="${wifi_dir}"
	)

	modlist=(
		mt76=updates:"${wifi_dir}":"${wifi_dir}":modules
		mt76-connac-lib=updates:"${wifi_dir}":"${wifi_dir}":modules
		mt792x-lib=updates:"${wifi_dir}":"${wifi_dir}":modules

		mt7921-common=updates:"${wifi_dir}":"${wifi_dir}/mt7921":modules
		mt7921e=updates:"${wifi_dir}":"${wifi_dir}/mt7921":modules

		mt7925-common=updates:"${wifi_dir}":"${wifi_dir}/mt7925":modules
		mt7925e=updates:"${wifi_dir}":"${wifi_dir}/mt7925":modules
	)

	linux-mod-r1_src_compile
}

src_install() {
	local build="${WORKDIR}/_build"
	local wifi_dir="${build}/mt76"
	local bt_dir="${build}/bluetooth"

	local -a modargs=()
	local -a modlist=()

	#
	# Bluetooth modules
	#
	# Installed only for pre-7.1 kernels or USE=bt-dkms.
	#
	if want_external_bt; then
		modargs=(
			-C "${KV_OUT_DIR}"
			M="${bt_dir}"
		)

		modlist=(
			btusb=updates:"${bt_dir}":"${bt_dir}":modules
			btmtk=updates:"${bt_dir}":"${bt_dir}":modules
		)

		linux-mod-r1_src_install
	fi

	#
	# WiFi modules
	#
	modargs=(
		-C "${KV_OUT_DIR}"
		M="${wifi_dir}"
	)

	modlist=(
		mt76=updates:"${wifi_dir}":"${wifi_dir}":modules
		mt76-connac-lib=updates:"${wifi_dir}":"${wifi_dir}":modules
		mt792x-lib=updates:"${wifi_dir}":"${wifi_dir}":modules

		mt7921-common=updates:"${wifi_dir}":"${wifi_dir}/mt7921":modules
		mt7921e=updates:"${wifi_dir}":"${wifi_dir}/mt7921":modules

		mt7925-common=updates:"${wifi_dir}":"${wifi_dir}/mt7925":modules
		mt7925e=updates:"${wifi_dir}":"${wifi_dir}/mt7925":modules
	)

	linux-mod-r1_src_install

	#
	# Bluetooth firmware
	#
	# This firmware is still not in linux-firmware. Upstream v2.17-2
	# continues to install it from the ASUS package.
	#
	if [[ -f \
		"${WORKDIR}/${FW_P}/BT_RAM_CODE_MT6639_2_1_hdr.bin" ]]; then

		insinto /lib/firmware/mediatek/mt7927

		doins \
			"${WORKDIR}/${FW_P}/BT_RAM_CODE_MT6639_2_1_hdr.bin"
	else
		die "BT_RAM_CODE_MT6639_2_1_hdr.bin was not found in ${FW_P}"
	fi

	#
	# WiFi firmware
	#
	# Deliberately NOT installed here.
	#
	# Starting with upstream v2.17-2, MT7927 WiFi firmware should come
	# from sys-kernel/linux-firmware. Installing the ASUS copy here would
	# shadow the newer MediaTek-provided firmware.
	#

	#
	# Module precedence
	#
	local mod
	local depmod_conf="${T}/${PN}.conf"

	{
		echo "# Generated by ${CATEGORY}/${PF}"
		echo "# Prefer package-provided MT7927/mt76 WiFi modules."

		#
		# Only override Bluetooth when we actually installed external
		# Bluetooth modules.
		#
		if want_external_bt; then
			echo "override btusb * updates"
			echo "override btmtk * updates"
		fi

		for mod in \
			mt76 \
			mt76-connac-lib \
			mt792x-lib \
			mt7921-common \
			mt7921e \
			mt7925-common \
			mt7925e
		do
			echo "override ${mod} * updates"
		done
	} > "${depmod_conf}" || die

	insinto /lib/depmod.d
	doins "${depmod_conf}"

	#
	# Optional upstream firmware extraction utility.
	#
	if [[ -f "${S}/extract_firmware.py" ]]; then
		exeinto "/usr/libexec/${PN}"

		doexe "${S}/extract_firmware.py"

		dosym \
			"/usr/libexec/${PN}/extract_firmware.py" \
			"/usr/bin/mt7927-extract-firmware"
	fi
}

pkg_postinst() {
	linux-mod-r1_pkg_postinst

	elog ""
	elog "MediaTek MT7927 / MT6639 support installed (${PV}-${UPSTREAM_REL})."
	elog ""

	elog "WiFi:"
	elog "    Linux ${MT76_KVER} mt76 base + upstream v${PV}-${UPSTREAM_REL} patch set"
	elog "    package-provided mt76/mt7925e modules override the in-tree copies"
	elog ""

	elog "WiFi firmware:"
	elog "    provided by sys-kernel/linux-firmware"
	elog "    bundled ASUS WiFi blobs are deliberately NOT installed"
	elog ""

	elog "Expected WiFi firmware:"
	elog "    /lib/firmware/mediatek/mt7927/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin[.zst]"
	elog "    /lib/firmware/mediatek/mt7927/WIFI_RAM_CODE_MT6639_2_1.bin[.zst]"
	elog ""

	if want_external_bt; then
		elog "Bluetooth:"
		elog "    using package-provided btusb/btmtk (USE=bt-dkms)"
	else
		elog "Bluetooth:"
		elog "    using kernel-native btusb/btmtk (recommended on kernel >=7.1)"
	fi

	elog ""
	elog "Bluetooth firmware:"
	elog "    /lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin"
	elog ""

	elog "Module validation:"
	elog "    modinfo -n mt7925e"
	elog "    modinfo -n btusb"
	elog ""

	elog "Device validation:"
	elog "    lspci -nnk | grep -A3 -i '14c3:7927'"
	elog "    lsusb | grep -iE '0489:e13a|13d3:3588|mediatek|foxconn'"
	elog "    bluetoothctl show"
	elog ""

	elog "If the MT6639 USB device disappears after a module reload, a normal"
	elog "reboot may not recover it. Fully power off and remove PSU power for"
	elog "at least 10 seconds, or enable ErP S4+S5 in firmware setup."
	elog ""

	elog "After a kernel upgrade:"
	elog "    emerge @module-rebuild"
}
