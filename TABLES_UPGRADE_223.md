# Upgrade 223 — Print Job Submission UI

Added printer picker, document-kind dropdown, 1–20 copy control, refresh, and submission to the Tables Printer Center. Added authenticated `gs_submit_cafe_print_job` with server-side printer, permission, document type and copy validation. Jobs remain queued metadata: **no document payload or physical printing** is implemented. Printer statuses are last-reported, not live. Remote gateway, document rendering, device drivers, duplicate-submit protection and real-world tests are pending. Section 02 estimated 94%; Customers paused at 45%.
