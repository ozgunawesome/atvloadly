package cfg

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDefaultConfigDirUsesEnvironmentRootPath(t *testing.T) {
	configHome, err := os.UserConfigDir()
	if err != nil {
		t.Fatalf("os.UserConfigDir() error: %v", err)
	}
	t.Setenv("ATVLOADLY_ROOT_PATH", "custom-root")

	got := DefaultConfigDir()
	want := filepath.Join(configHome, "custom-root")
	if got != want {
		t.Fatalf("DefaultConfigDir() = %q, want %q", got, want)
	}
}

func TestDefaultConfigDirUsesOnlySafeEnvironmentRootPath(t *testing.T) {
	configHome, err := os.UserConfigDir()
	if err != nil {
		t.Fatalf("os.UserConfigDir() error: %v", err)
	}
	t.Setenv("ATVLOADLY_ROOT_PATH", "custom/root")

	got := DefaultConfigDir()
	want := filepath.Join(configHome, "atvloadly")
	if got != want {
		t.Fatalf("DefaultConfigDir() = %q, want %q", got, want)
	}
}

func TestDefaultConfigDirDefaultsToAtvloadly(t *testing.T) {
	configHome, err := os.UserConfigDir()
	if err != nil {
		t.Fatalf("os.UserConfigDir() error: %v", err)
	}
	t.Setenv("ATVLOADLY_ROOT_PATH", "")

	got := DefaultConfigDir()
	want := filepath.Join(configHome, "atvloadly")
	if got != want {
		t.Fatalf("DefaultConfigDir() = %q, want %q", got, want)
	}
}
