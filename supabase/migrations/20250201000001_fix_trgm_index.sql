-- =============================================================================
-- Migration: 20250201000001_fix_trgm_index
-- Description: Fix the trigram index that failed in previous migration
-- =============================================================================

-- Enable trigram extension (may already exist)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create the index that failed
CREATE INDEX IF NOT EXISTS idx_commanders_name_trgm 
  ON public.commanders USING gin(name gin_trgm_ops);
