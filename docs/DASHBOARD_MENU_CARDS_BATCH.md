# Dashboard Menu and Menu Availability

Two additional Dashboard cards now use the existing staff product catalog read
(list_cafe_menu_routed via SupabaseCafeMenuStore.load). No mutation calls, schema
changes, permission changes or production release are part of this draft.

Read-only features: category and availability filters; name/category/description/
station search; clear filters; full loaded availability counts distinct from matching
product count; product descriptions and Normal/Tourism/Owner IQD prices; station
names; refresh timestamp; stale-data clearing; retry and late-response protection.
Owner zero prices remain zero. Missing optional prices say Not recorded instead
of inventing a configured price. Editing/availability changes remain in Menu Management.
Product image editing and display are not added in this Dashboard batch.

Dashboard visibility and existing server catalog authorization remain enforced.
Entry-card labels now say Open products and Current menu snapshot. Other routing,
permissions, mutation code and financial forms are byte-identical after inverse edit checks.

Five focused tests cover phone RTL, read-only controls, zero/missing prices, compound
filters/search, full-count scope, refresh failure/retry, late reads, and both actual
Dashboard entry routes. Full analysis/test/release-build checks required.

Previous review coverage after PR20 release: 44/96 improved cards. This draft would
increase it to 46/96, with 50 outside the review batches. These counts do not measure
complete workflows. Standing Cash billing, discounts, credit, split bills and remaining
sections/integration verification are still pending.
