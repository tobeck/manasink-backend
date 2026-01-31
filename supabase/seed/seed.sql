-- =============================================================================
-- Seed Data for Local Development
-- =============================================================================
-- 
-- This file contains test data for local development.
-- Run with: supabase db reset (applies migrations + seed)
--
-- NOTE: This requires a test user to exist in auth.users
-- Create one via the local Supabase Studio dashboard first.
-- =============================================================================

-- After creating a test user in the dashboard, uncomment and update the user_id:

/*
-- Get your test user's ID from: http://localhost:54323/project/default/auth/users
DO $$
DECLARE
  test_user_id UUID := 'YOUR_TEST_USER_ID_HERE';
BEGIN

  -- Sample liked commanders
  INSERT INTO public.liked_commanders (user_id, commander_id, commander_data)
  VALUES 
    (test_user_id, 'atraxa-sample', '{"name": "Atraxa, Praetors'' Voice", "colorIdentity": ["W", "U", "B", "G"], "typeLine": "Legendary Creature — Phyrexian Angel Horror"}'::jsonb),
    (test_user_id, 'edgar-sample', '{"name": "Edgar Markov", "colorIdentity": ["W", "B", "R"], "typeLine": "Legendary Creature — Vampire Knight"}'::jsonb)
  ON CONFLICT DO NOTHING;

  -- Sample deck
  INSERT INTO public.decks (user_id, name, commander_id, commander_data, cards)
  VALUES (
    test_user_id,
    'Atraxa Superfriends',
    'atraxa-sample',
    '{"name": "Atraxa, Praetors'' Voice", "colorIdentity": ["W", "U", "B", "G"]}'::jsonb,
    '[]'::jsonb
  )
  ON CONFLICT DO NOTHING;

  -- Sample preferences
  INSERT INTO public.user_preferences (user_id, color_filters)
  VALUES (test_user_id, ARRAY['U', 'B', 'G'])
  ON CONFLICT DO NOTHING;

  -- Sample swipe history
  INSERT INTO public.swipe_history (user_id, commander_id, action)
  VALUES 
    (test_user_id, 'atraxa-sample', 'like'),
    (test_user_id, 'edgar-sample', 'like'),
    (test_user_id, 'some-passed-commander', 'pass')
  ON CONFLICT DO NOTHING;

END $$;
*/

-- For now, just log that seed was run
DO $$
BEGIN
  RAISE NOTICE 'Seed file executed. Uncomment test data after creating a test user.';
END $$;
