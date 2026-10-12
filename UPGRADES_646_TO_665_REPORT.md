# Batch 646–665 — Progress and verification

Source: Upgrade 645 complete ZIP. These are 20 targeted source changes, not 20 validated production milestones.

| Upgrade | Section | Change | Verified progress delta |
|---|---|---|---|
| 646 | 07 | Prevent unauthenticated inventory overview requests | Not measurable without runtime tests |
| 647 | 07 | Validate inventory overview response type | Not measurable without runtime tests |
| 648 | 07 | Guard inventory history against employee switch | Not measurable without runtime tests |
| 649 | 07 | Hide inventory history if current employee changed | Not measurable without runtime tests |
| 650 | 07 | Reject invalid inventory history payload | Not measurable without runtime tests |
| 651 | 07 | Show unknown inventory history deltas explicitly | Not measurable without runtime tests |
| 652 | 07 | Distinguish unknown stock movement from zero movement | Not measurable without runtime tests |
| 653 | 07 | Disable inventory refresh while a mutation is pending | Not measurable without runtime tests |
| 654 | 07 | Validate product identifier before inventory edits | Not measurable without runtime tests |
| 655 | 07 | Reject inventory history requests with missing product identifiers | Not measurable without runtime tests |
| 656 | 06 | Trim menu preview search input | Not measurable without runtime tests |
| 657 | 06 | Reject negative preview menu prices explicitly | Not measurable without runtime tests |
| 658 | 06 | Reject blank preview product names | Not measurable without runtime tests |
| 659 | 06 | Reject blank preview barcodes | Not measurable without runtime tests |
| 660 | 06 | Cap unusually large preview prices to avoid misleading amounts | Not measurable without runtime tests |
| 661 | 06 | Add explicit preview-only price validation guidance | Not measurable without runtime tests |
| 662 | 06 | Normalize menu preview search consistently | Not measurable without runtime tests |
| 663 | 06 | Avoid retaining whitespace-only preview names | Not measurable without runtime tests |
| 664 | 06 | Normalize preview barcode whitespace | Not measurable without runtime tests |
| 665 | 06 | Explain that local preview products do not change live inventory | Not measurable without runtime tests |

## Seven section progress

| Section | Previously established progress | Current verified completion |
|---|---|---|
| 01 Dashboard | Unknown | Not verified |
| 02 Tables | Unknown | Not verified |
| 03 Table Orders | 76% estimated | Not verified |
| 04 Motel Orders | Unknown | Not verified |
| 05 Kitchen | Unknown | Not verified |
| 06 Menu | Unknown | Not verified |
| 07 Products & Inventory | Unknown | Not verified |

20 source changes were made: 10 in Menu and 10 in Products & Inventory. This does not establish a percentage increase.
