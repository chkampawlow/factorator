# TCL, TFP, and FOPROLOS preparation

These schedules deliberately contain no hard-coded statutory rate. Each company records an effective-dated configuration for `TCL`, `TFP`, or `FOPROLOS`, chooses `TURNOVER`, `GROSS_PAYROLL`, or `MANUAL` as its basis kind, and records the legal basis used.

For each month, the company supplies the reviewed basis amount. The backend snapshots the effective configuration and calculates `round(basis × rate / 100, 3)`. Saved schedules are available in reports and through the `contributions` CSV export.

The app does not currently derive payroll bases because it is not a payroll system. TCL turnover scope can also require fiscal adjustments that should be entered in the reviewed basis. All applicability, bases, rates, and filing results require validation by a Tunisian accountant.
