-- Upgrade 293: venue scope foundation, not yet an approvable booking mode.
ALTER TABLE public.gs_event_reservations ADD COLUMN IF NOT EXISTS venue_scope text NOT NULL DEFAULT 'selected_tables' CHECK (venue_scope IN ('selected_tables','whole_venue'));
CREATE TABLE IF NOT EXISTS public.gs_event_requested_tables (
 event_id uuid NOT NULL REFERENCES public.gs_event_reservations(id) ON DELETE CASCADE,
 table_id uuid NOT NULL REFERENCES public.gs_reservable_tables(id),
 PRIMARY KEY(event_id,table_id)
);
ALTER TABLE public.gs_event_requested_tables ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.gs_event_requested_tables FROM anon,authenticated;
CREATE INDEX IF NOT EXISTS gs_event_requested_tables_table_idx ON public.gs_event_requested_tables(table_id,event_id);
-- Approval and availability RPCs still need whole-venue/multi-table conflict checks.
