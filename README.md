# OmaPlugin Manager

A graphical plugin manager for Omarchy.

Manage your installed Omarchy plugins directly from the top bar.

## Features

* View installed plugins
* Enable and disable plugins
* Uninstall third-party plugins
* Confirmation before uninstalling
* Plugin status indicators
* Native Omarchy bar integration
* Omarchy-themed interface
* Automatic plugin list refresh after actions


## Installation

Clone and enable the plugin:

```bash
omarchy plugin install https://github.com/nrm59/omaplugin-manager.git --enable
```

Restart the Omarchy shell:

```bash
omarchy-restart-shell
```

The plugin will then appear in the Omarchy bar.

## Usage

Click the OmaPlugin Manager icon in the Omarchy bar to open the plugin manager.

From the panel you can:

* View installed plugins
* Enable or disable plugins
* Uninstall third-party plugins

First-party Omarchy plugins cannot be uninstalled from the manager.

## Uninstallation

Disable and remove the plugin:

```bash
omarchy plugin disable nrm59.omaplugin-manager
omarchy plugin remove nrm59.omaplugin-manager --yes
```

Then restart the Omarchy shell:

```bash
omarchy-restart-shell
```

## Version

**1.0.0**

## Status

In development

## License

This project is licensed under the MIT License. See [LICENSE.md](LICENSE.md).
