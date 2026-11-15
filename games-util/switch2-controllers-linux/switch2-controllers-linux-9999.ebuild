# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Upstream's installer deliberately uses Python 3.12 with bleak 0.22.2
# as its known-good configuration.
PYTHON_COMPAT=( python3_14 )

inherit git-r3 python-single-r1 systemd

DESCRIPTION="Wireless Nintendo Switch 2 controller bridge for Linux"
HOMEPAGE="https://github.com/trevlars/switch2-controllers-linux"
EGIT_REPO_URI="https://github.com/trevlars/switch2-controllers-linux.git"
EGIT_BRANCH="main"

LICENSE="MIT"
SLOT="0"
KEYWORDS=""

PROPERTIES="live"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="
	${PYTHON_DEPS}

	net-wireless/bluez

	$(python_gen_cond_dep '
		>=dev-python/bleak-3.0.2[${PYTHON_USEDEP}]
		>=dev-python/evdev-1.6[${PYTHON_USEDEP}]
	')
"

pkg_setup() {
	python-single-r1_pkg_setup
}

src_prepare() {
	default

	[[ -d ngc ]] ||
		die "ngc Python package not found"

	[[ -f ngc/__init__.py ]] ||
		die "ngc/__init__.py not found"

	[[ -f ngc/__main__.py ]] ||
		die "ngc/__main__.py not found"

	[[ -f ngc/bridge.py ]] ||
		die "ngc/bridge.py not found"

	[[ -f scripts/disable-steam-bluetooth.py ]] ||
		die "scripts/disable-steam-bluetooth.py not found"

	einfo "Applying multi-controller direct wake-probe compatibility patch"

	"${EPYTHON}" \
		"${FILESDIR}/patch-multicontroller-wake.py" \
		"${S}/ngc/bridge.py" || die
}

src_install() {
	#
	# Core Python package.
	#
	# Upstream does not currently provide pyproject.toml/setup.py;
	# ngc/ is a regular Python package designed to be invoked with:
	#
	#     python -m ngc
	#
	python_domodule ngc

	#
	# Install a normal command-line entry point.
	#
	# Upstream's argparse program name is already "ngc", so expose that
	# name rather than requiring users to run "python -m ngc".
	#
	cat > "${T}/ngc" <<-'EOF' || die
	#!/usr/bin/python
	from ngc.__main__ import main

	if __name__ == "__main__":
	    raise SystemExit(main())
	EOF

	python_newscript "${T}/ngc" ngc

	#
	# Steam has its own Bluetooth scanning setting which can leave LE
	# discovery permanently active. That prevents raw L2CAP connection
	# initiation even though normal system BlueZ remains usable.
	#
	# Do NOT run this automatically from the ebuild: it modifies the
	# user's Steam configuration. Install it as an explicit helper instead.
	#
	python_newscript \
		scripts/disable-steam-bluetooth.py \
		ngc-disable-steam-bluetooth

	#
	# User-level systemd service.
	#
	# The upstream service assumes:
	#
	#   %h/nso-gc-bazzite/.venv312/bin/python -m ngc run
	#
	# which is appropriate for the upstream Bazzite installer but not for
	# a distribution package. Use our Portage-managed /usr/bin/ngc instead.
	#
	cat > "${T}/nso-gc.service" <<-'EOF' || die
	[Unit]
	Description=Switch 2 controller wireless bridge
	Documentation=https://github.com/trevlars/switch2-controllers-linux
	After=bluetooth.target
	Wants=bluetooth.target

	[Service]
	Type=simple
	ExecStart=/usr/bin/ngc run
	Restart=always
	RestartSec=3
	StartLimitIntervalSec=0

	# Disable Bazzite-specific emulator reordering hooks. They are irrelevant
	# on a normal Gentoo installation and the core bridge does not need them.
	Environment=NGC_AUTO_REORDER=0

	[Install]
	WantedBy=default.target
	EOF

	systemd_douserunit "${T}/nso-gc.service"

	#
	# Documentation.
	#
	dodoc README.md
	newdoc requirements.txt upstream-requirements.txt
}

pkg_postinst() {
	elog ""
	elog "switch2-controllers-linux has been installed."
	elog ""

	elog "This package uses system BlueZ normally."
	elog "Do NOT disable bluetooth.service."
	elog ""

	elog "If nsogcd is still installed/running, disable it first:"
	elog "    sudo systemctl disable --now nsogcd"
	elog ""
	elog "Then make sure normal Bluetooth is enabled:"
	elog "    sudo systemctl enable --now bluetooth"
	elog ""

	elog "Kernel requirement:"
	elog "    CONFIG_INPUT_UINPUT=y or CONFIG_INPUT_UINPUT=m"
	elog ""
	elog "Check with:"
	elog "    zgrep CONFIG_INPUT_UINPUT /proc/config.gz"
	elog ""

	elog "Also verify your user can write to /dev/uinput:"
	elog "    test -w /dev/uinput && echo OK || echo NO"
	elog ""

	elog "IMPORTANT FOR STEAM:"
	elog ""
	elog "Steam can keep its own Bluetooth LE discovery session running,"
	elog "which interferes with the raw L2CAP connection used by this bridge."
	elog ""
	elog "With Steam completely closed, run once:"
	elog "    ngc-disable-steam-bluetooth"
	elog ""
	elog "This disables Steam's own Bluetooth scanner only."
	elog "System BlueZ and normal Bluetooth devices remain available."
	elog ""

	elog "Pair controller #1:"
	elog "    ngc pair --player 1"
	elog ""
	elog "Pair controller #2:"
	elog "    ngc pair --player 2"
	elog ""
	elog "Hold SYNC on each controller until its player LEDs sweep/chase"
	elog "before running the corresponding pair command."
	elog ""

	elog "Show configured controllers:"
	elog "    ngc list"
	elog ""

	elog "Test the bridge in the foreground:"
	elog "    ngc run"
	elog ""

	elog "Once confirmed working, enable the user service:"
	elog "    systemctl --user enable --now nso-gc.service"
	elog ""

	elog "Service status:"
	elog "    systemctl --user status nso-gc.service"
	elog ""

	elog "Live logs:"
	elog "    journalctl --user -u nso-gc.service -f"
	elog ""
}
