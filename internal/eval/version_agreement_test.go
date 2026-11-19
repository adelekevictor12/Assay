package eval_test

import (
	"testing"

	"github.com/use-assay/assay/internal/attest"
	"github.com/use-assay/assay/internal/eval"
	"github.com/use-assay/assay/internal/mechanics"
	"github.com/use-assay/assay/internal/version"
)

// One binary names one scanner version (#279): the eval record, the
// confusion matrix and the v4 preimage's scanner identity must all read the
// same value. This fails if either side starts computing its own.
func TestScannerVersionAgreement(t *testing.T) {
	want := version.Current()
	if attest.ScannerIdentity != want {
		t.Fatalf("attest.ScannerIdentity = %q, version.Current() = %q", attest.ScannerIdentity, want)
	}
	engine := mechanics.NewEngine()
	rec, err := eval.Run(engine, "../mechanics/testdata")
	if err != nil {
		t.Fatalf("eval.Run: %v", err)
	}
	if rec.Version != want {
		t.Errorf("eval record version = %q, want %q", rec.Version, want)
	}
	m, err := eval.BuildConfusionMatrix(engine, "../mechanics/testdata")
	if err != nil {
		t.Fatalf("BuildConfusionMatrix: %v", err)
	}
	if m.Version != want {
		t.Errorf("confusion matrix version = %q, want %q", m.Version, want)
	}
}
