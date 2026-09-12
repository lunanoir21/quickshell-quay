//@ pragma UseQApplication

import Quickshell

// Standalone entry point. Vendored into another shell, import the directory
// and instantiate QuayHost directly instead.
ShellRoot {
    QuayHost {}
}
