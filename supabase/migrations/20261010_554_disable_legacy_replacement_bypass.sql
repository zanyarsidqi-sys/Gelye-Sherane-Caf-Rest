-- Upgrade 554: close the legacy five-argument replacement RPC bypass.
-- Upgrade 538 introduced a six-argument RPC requiring an explicit confirmed
-- server-quoted replacement price. The old overload remained callable.
-- Revoke rather than DROP to avoid breaking dependent database objects.
REVOKE ALL ON FUNCTION public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text)
  FROM PUBLIC, anon, authenticated;
-- Reassert intended access on the price-confirming overload.
REVOKE ALL ON FUNCTION public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint)
  TO authenticated;
