//go:build linux

package cfg

import (
	"os"
	"path/filepath"
)

func DefaultConfigDir() string {
	dir, _ := os.UserConfigDir()
	return filepath.Join(dir, RootPath())
}
