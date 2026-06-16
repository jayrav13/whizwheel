<!-- spec:v1 -->
**Category:** Financial
**Source:** https://www.calculator.net/discount-calculator.html
**Complexity:** 2
**Tags:** multi-input, multi-mode
**Card description:** Apply a discount to a price — percent off or a fixed amount off — and see the final sale price and how much you saved.

## Intent
A **discount** calculator: given an original price and a discount, compute the **final (sale) price** and
the **amount saved**. The discount can be expressed two ways — a **percent off** or a **fixed dollar
amount off** — selected by a **mode picker**. It reuses the single-formula multi-input shape proven by
the Percentage calculator (one relationship, a couple of inputs).

### Modes (the `mode` input — how the discount is expressed)
| mode      | given                        | computes                                       |
|-----------|------------------------------|------------------------------------------------|
| `percent` | `original_price`, `percent_off` | `saved = price × percent/100`; `final = price − saved` |
| `fixed`   | `original_price`, `amount_off`  | `saved = amount_off`; `final = price − amount_off`     |

### Formula (authoritative — confirmed against the Source)
```
# percent mode
amount_saved   = original_price × percent_off / 100
final_price    = original_price − amount_saved          # = original_price × (1 − percent_off/100)

# fixed mode
amount_saved   = amount_off
final_price    = original_price − amount_off
```

## Inputs
| name           | type    | rules                                                                        |
|----------------|---------|------------------------------------------------------------------------------|
| mode           | string  | presence, inclusion in `percent`, `fixed`                                    |
| original_price | decimal | presence, numericality (greater than 0)                                      |
| percent_off    | decimal | numericality (greater than or equal to 0, less than or equal to 100); required when `mode` = `percent` |
| amount_off     | decimal | numericality (greater than or equal to 0); required when `mode` = `fixed`; must be ≤ original_price |

_Each mode requires exactly the one discount field it uses; the other is left blank._

## Outputs
| key            | meaning                                          |
|----------------|--------------------------------------------------|
| mode           | echo of the discount mode                        |
| original_price | echo of the original price, money string         |
| final_price    | the discounted/sale price, money string          |
| amount_saved   | how much was saved, money string                 |

## Reference values
_PM-computed deterministically; the backend agent must reproduce them exactly. Money rounds to the cent
half-up._

| mode      | original_price | percent_off | amount_off | amount_saved | final_price |
|-----------|----------------|-------------|------------|--------------|-------------|
| `percent` | 45.00          | 10          | —          | 4.50         | 40.50       |
| `percent` | 199.99         | 25          | —          | 50.00        | 149.99      |
| `fixed`   | 80.00          | —           | 15.00      | 15.00        | 65.00       |
| `percent` | 50.00          | 0           | —          | 0.00         | 50.00       |

_Worked anchor (`percent`, original 45, percent_off 10): saved = 45 × 10/100 = **4.50**; final = 45 −
4.50 = **40.50** (the Source's example). (`percent`, 199.99 @ 25%): saved = 199.99 × 0.25 = 49.9975 →
**50.00**; final = 199.99 − 50.00 = **149.99**.) (`fixed`, 80 − 15): saved = **15.00**; final = 80 − 15 =
**65.00**.)_

### Edge / validation cases
| inputs | expected |
|--------|----------|
| `mode=percent`, original_price = 0 | invalid (greater than 0) |
| `mode=percent`, percent_off = 120 | invalid (≤ 100) |
| `mode=percent`, percent_off blank | invalid (required for percent mode) |
| `mode=fixed`, amount_off = 100, original_price = 80 | invalid (amount off must be ≤ original price) |
| `mode=fixed`, amount_off blank | invalid (required for fixed mode) |
| `mode=zzz` | invalid (mode not in inclusion list) |
| `mode=percent`, original_price = "x" | invalid (Base numeric guard rejects non-numeric) |

## Notes
- **Mode picker (`DESIGN.md §4`):** `mode` is a single-select posted as `inputs[mode]` via a native radio
  `<fieldset>`. Two modes — "Percent off" / "Fixed amount off" — read as **multi-word** (N=2), so per the
  §4 rule the FE renders the **`.mode-option` option list** (each option's helper names how the discount is
  expressed). The form shows only the one discount field for the chosen mode.
- Rounding/display: full-precision `BigDecimal` compute; money → 2 dp half-up (§10).
- Calculator-rewrite task — **regenerate from this spec, not from prior code.**
