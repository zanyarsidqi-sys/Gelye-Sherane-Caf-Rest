# Upgrade 1375: Cash Reconciliation UI fidelity

- Added a count of currently visible vs authorized returned orders above the filters.
- Added Clear filters action that appears only while search or any of the three filters is active.
- The search field is remounted when clearing its value so the text and actual filtered results remain consistent.
- Retains the exact Flutter Material Scaffold, AppBar, four input controls, ListTile rows and footer. Do not present a custom dark iPhone mockup as the implemented UI.
- No printing, invoice generation, payment processing or authorization changes.
- ZIP integrity and source assertions passed. Flutter compilation and pixel comparison not performed; 95% visual match unverified.
