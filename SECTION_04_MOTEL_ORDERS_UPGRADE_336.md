# Upgrade 336 — Two-interface architecture and staff scheduled meals

Staff: new Scheduled Meals tab in Motel Orders; permission-gated Supabase RPCs for creating and listing requests. Dates stored as timestamptz (Flutter local picker converted to UTC). Existing room QR registry reused. No live guest QR order submission: a public QR identifies a room but does not authenticate an occupant. No kitchen dispatch, pricing approval, status transitions or payment capture are claimed. Customer interface requirements: View Menu, Order Food, Check Status, Schedule Special Meal, Check Room Bill, Call Employee; Request Cleaning excluded. Guest authorization and separate public customer screen remain future work.

Not Flutter-compiled or live Supabase-tested.
