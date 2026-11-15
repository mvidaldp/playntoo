# Playntoo

A community-oriented Gentoo overlay focused on Linux gaming,
native game ports, performance tooling and a console-like experience.

## Vision

Playntoo aims to simplify building and maintaining a Gentoo gaming
system with Steam, Gamescope, Vulkan, GameMode, MangoHud, Decky and
other gaming tools.

The long-term goal is a customizable, controller-friendly
Gentoo gaming experience.

## Installing the overlay

Install the repository management tool:

```bash
sudo emerge -av app-eselect/eselect-repository
```

Add Playntoo:

```bash
sudo eselect repository add playntoo git \
  https://github.com/mvidaldp/playntoo.git

sudo emaint sync -r playntoo
```

## Packages

See the package directories for available ebuilds.

Packages are maintained independently from the official Gentoo
repository and GURU.

## Development

The overlay follows Gentoo ebuild conventions.

Package validation:

```bash
pkgcheck scan --net
```

Pull requests and contributions are welcome.

## Disclaimer

Playntoo is an unofficial community project, not an official
Gentoo distribution.

Commercial game files, copyrighted ROMs and game dumps are
not distributed by this repository.
