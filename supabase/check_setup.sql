-- =====================================================================
-- CHECK SETUP: يفحص مشروع Supabase الخاص بك ويعرض ما هو ناقص فقط.
-- الصقه في SQL Editor واضغط Run. للقراءة فقط (لا يغيّر شيئًا).
--   * إن ظهر صف واحد (ok) فكل الدوال والجداول والـ bucket موجودة.
--   * إن ظهرت صفوف MISSING فشغّل setup_all.sql كاملًا (آمن لإعادة التشغيل) ثم أعد هذا الفحص.
-- Expected: 51 functions, 24 tables, 1 storage bucket.
-- =====================================================================
with expected(kind, name) as (
  values
    ('function','admin_add_term'),
    ('function','admin_grant_coins'),
    ('function','admin_list_reports'),
    ('function','admin_list_terms'),
    ('function','admin_remove_term'),
    ('function','admin_resolve_report'),
    ('function','admin_set_ban'),
    ('function','admin_set_setting'),
    ('function','admin_stats'),
    ('function','am_i_admin'),
    ('function','block_user'),
    ('function','blocked_users'),
    ('function','chat_image_can_read'),
    ('function','chat_image_can_upload'),
    ('function','chat_image_path_ok'),
    ('function','claim_daily_coins'),
    ('function','delete_my_account'),
    ('function','disable_push'),
    ('function','feature_similarity'),
    ('function','find_similar'),
    ('function','handle_new_user'),
    ('function','is_admin'),
    ('function','is_blocked'),
    ('function','ledger_immutable'),
    ('function','mark_delivered'),
    ('function','mark_read'),
    ('function','message_allowed'),
    ('function','messages_chat_guard'),
    ('function','messages_content_guard'),
    ('function','my_conversations'),
    ('function','my_profile'),
    ('function','my_push_enabled'),
    ('function','my_wallet'),
    ('function','pair_similarity'),
    ('function','publish_features'),
    ('function','publish_scores_batch'),
    ('function','purge_similarity'),
    ('function','refresh_similarity_for'),
    ('function','register_push_token'),
    ('function','report_user'),
    ('function','save_my_profile'),
    ('function','send_gift'),
    ('function','send_image_message'),
    ('function','send_message'),
    ('function','set_updated_at'),
    ('function','setting_int'),
    ('function','social_eligible'),
    ('function','start_conversation'),
    ('function','touch_presence'),
    ('function','unblock_user'),
    ('function','unregister_push_token'),
    ('table','abuse_reports'),
    ('table','admin_users'),
    ('table','answers'),
    ('table','app_settings'),
    ('table','assessment_catalog'),
    ('table','assessment_results'),
    ('table','assessment_sessions'),
    ('table','blocked_terms'),
    ('table','blocks'),
    ('table','coin_ledger'),
    ('table','conversations'),
    ('table','development_plans'),
    ('table','gift_sends'),
    ('table','gifts'),
    ('table','messages'),
    ('table','profiles'),
    ('table','progress_logs'),
    ('table','push_tokens'),
    ('table','questions'),
    ('table','reports'),
    ('table','shared_features'),
    ('table','shared_scores'),
    ('table','similarity_cache'),
    ('table','wallets'),
    ('bucket','chat-images')
),
found as (
  select 'function' as kind, p.proname::text as name
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
  union all
  select 'table', c.relname::text
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'v', 'p')
  union all
  select 'bucket', id::text from storage.buckets
),
missing as (
  select e.kind, e.name, 'MISSING'::text as status
    from expected e
    left join found f on f.kind = e.kind and f.name = e.name
   where f.name is null
)
select * from missing
union all
select 'ok', 'all expected objects exist', 'OK'
 where not exists (select 1 from missing)
order by 1, 2;
